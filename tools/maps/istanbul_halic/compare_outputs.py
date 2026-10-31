"""Compare a generated İstanbul • Haliç map with a reference, reading only.
GLB: hash, JSON header, node names, and per mesh the vertex/triangle counts and
the bytes of every attribute (largest position and normal difference if not equal).
JSON: each record file of the reference folder against the same file in --out.
Run: python compare_outputs.py [--out DIR] [--reference-glb FILE] [--reference-json DIR]
Exit code 0 when the GLBs are byte-identical, 1 otherwise.
"""
from pathlib import Path
import argparse, collections, hashlib, json, struct
import numpy as np

REPO = Path(__file__).resolve().parents[3]
COMPONENTS = {5126: np.float32, 5125: np.uint32, 5121: np.uint8}
WIDTHS = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}
ATTRIBUTES = ['POSITION', 'NORMAL', 'COLOR_0']


class Glb:
    def __init__(self, path):
        self.path = Path(path)
        with open(path, 'rb') as f:
            magic, version, length = struct.unpack('<4sII', f.read(12))
            json_length, _ = struct.unpack('<I4s', f.read(8))
            self.json = json.loads(f.read(json_length))
            bin_length, _ = struct.unpack('<I4s', f.read(8))
        self.bin = np.memmap(path, dtype=np.uint8, mode='r', offset=12 + 8 + json_length + 8, shape=(bin_length,))
        self.meshes = {m['name']: m['primitives'][0] for m in self.json['meshes']}

    def accessor(self, index):
        a = self.json['accessors'][index]
        view = self.json['bufferViews'][a['bufferView']]
        raw = self.bin[view['byteOffset']:view['byteOffset'] + view['byteLength']]
        return np.asarray(raw).view(COMPONENTS[a['componentType']]).reshape(a['count'], WIDTHS[a['type']])

    def counts(self, name):
        p = self.meshes[name]
        acc = self.json['accessors']
        return acc[p['attributes']['POSITION']]['count'], acc[p['indices']]['count'] // 3

    def area(self, name):
        p = self.meshes[name]
        v = self.accessor(p['attributes']['POSITION']).astype(np.float64)
        i = self.accessor(p['indices']).reshape(-1, 3)
        return float(np.linalg.norm(np.cross(v[i[:, 1]] - v[i[:, 0]], v[i[:, 2]] - v[i[:, 0]]), axis=1).sum() / 2)


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 24), b''):
            h.update(block)
    return h.hexdigest()


def prefix(name):
    return name.split('_')[0].split('-')[0]


def compare_glb(a, b):
    print(f'GLB out:       {a.path}  sha256 {sha256(a.path)}  {a.path.stat().st_size} bytes')
    print(f'GLB reference: {b.path}  sha256 {sha256(b.path)}  {b.path.stat().st_size} bytes')
    for key in ['asset', 'extras', 'materials', 'scenes']:
        if key == 'scenes':
            same = len(a.json['scenes'][0]['nodes']) == len(b.json['scenes'][0]['nodes'])
        else:
            same = a.json.get(key) == b.json.get(key)
        print(f'header {key}: {"same" if same else "DIFFERENT"}')
    names_a = [n['name'] for n in a.json['nodes']]
    names_b = [n['name'] for n in b.json['nodes']]
    print(f'node names: {len(names_a)} vs {len(names_b)}, same order: {names_a == names_b}, '
          f'only in out: {sorted(set(names_a) - set(names_b))[:10]}, only in reference: {sorted(set(names_b) - set(names_a))[:10]}')
    for label, glb in [('out', a), ('reference', b)]:
        vertices = sum(glb.counts(n)[0] for n in glb.meshes)
        triangles = sum(glb.counts(n)[1] for n in glb.meshes)
        colliders = sum(1 for n in glb.meshes if n.endswith('-col'))
        print(f'totals {label}: triangles {triangles}, vertices {vertices}, mesh nodes {len(glb.meshes)}, -col nodes {colliders}')
    identical = 0
    same_area = 0
    compared = 0
    differing = collections.defaultdict(list)
    for name in names_a:
        if name not in b.meshes:
            continue
        (va, ta), (vb, tb) = a.counts(name), b.counts(name)
        pa, pb = a.meshes[name], b.meshes[name]
        compared += 1
        same_bytes = all(np.array_equal(a.accessor(pa['attributes'][k]), b.accessor(pb['attributes'][k])) for k in ATTRIBUTES) \
            and np.array_equal(a.accessor(pa['indices']), b.accessor(pb['indices']))
        if same_bytes:
            identical += 1
            continue
        aa, ab = a.area(name), b.area(name)
        same_area += abs(aa - ab) <= 1e-4 * max(ab, 1e-9)
        area = f'area {aa:.2f} vs {ab:.2f} m2'
        if (va, ta) != (vb, tb):
            differing[prefix(name)].append(f'{name}: vertices {va} vs {vb}, triangles {ta} vs {tb}, {area}')
        else:
            dp = float(np.abs(a.accessor(pa['attributes']['POSITION']) - b.accessor(pb['attributes']['POSITION'])).max())
            dn = float(np.abs(a.accessor(pa['attributes']['NORMAL']) - b.accessor(pb['attributes']['NORMAL'])).max())
            dc = int(np.count_nonzero(a.accessor(pa['attributes']['COLOR_0']) != b.accessor(pb['attributes']['COLOR_0'])))
            di = bool(np.array_equal(a.accessor(pa['indices']), b.accessor(pb['indices'])))
            differing[prefix(name)].append(f'{name}: same counts, max position diff {dp:.6g} m, max normal diff {dn:.6g}, '
                                           f'colour components differing {dc}, same indices {di}, {area}')
    print(f'meshes byte-identical: {identical} of {len(names_a)}; '
          f'of the other {compared - identical} meshes with the same name, {same_area} have the same surface area (within 0.01 %)')
    for group, lines in sorted(differing.items()):
        print(f'differing {group}: {len(lines)} meshes')
        for line in lines:
            print(f'  {line}')


def compare_json(out_dir, reference_dir, reference_metadata):
    pairs = [(out_dir / f.name, f) for f in sorted(reference_dir.glob('*.json')) if f.name != 'map_metadata.json']
    pairs.append((out_dir / 'map_metadata.json', reference_metadata))
    for mine, ref in pairs:
        if not mine.exists():
            print(f'json {mine.name}: not produced (reference only: {ref.name})')
            continue
        if mine.read_bytes() == ref.read_bytes():
            print(f'json {mine.name}: byte-identical')
            continue
        a, b = json.loads(mine.read_text()), json.loads(ref.read_text())
        if isinstance(a, dict) and isinstance(b, dict):
            keys = [k for k in sorted(set(a) | set(b)) if a.get(k) != b.get(k)]
            print(f'json {mine.name}: DIFFERENT in keys {keys}')
            for k in keys:
                if not isinstance(a.get(k), (dict, list)):
                    print(f'  {k}: {a.get(k)} vs reference {b.get(k)}')
        else:
            print(f'json {mine.name}: DIFFERENT')


def main():
    cli = argparse.ArgumentParser(description='Compare a generated map with a reference (read only).')
    cli.add_argument('--out', type=Path, default=REPO/'build/maps/istanbul_halic', help='generated folder (default: %(default)s)')
    cli.add_argument('--reference-glb', type=Path, default=REPO/'assets/istanbul_halic.glb', help='default: %(default)s')
    cli.add_argument('--reference-json', type=Path, default=REPO/'maps/istanbul_halic/reference', help='default: %(default)s')
    cli.add_argument('--reference-metadata', type=Path, default=REPO/'assets/map_metadata.json', help='default: %(default)s')
    opts = cli.parse_args()
    a, b = Glb(opts.out/'istanbul_halic.glb'), Glb(opts.reference_glb)
    compare_glb(a, b)
    compare_json(opts.out, opts.reference_json, opts.reference_metadata)
    raise SystemExit(0 if sha256(a.path) == sha256(b.path) else 1)


if __name__ == '__main__':
    main()
