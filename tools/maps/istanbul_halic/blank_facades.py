"""Estimate how many nearby facades a visibility range blanks, reading generated maps only.
Godot hides a mesh when the camera is farther than its visibility range from the
centre of the mesh's AABB, so a building's facade detail disappears with the mesh
(chunk or cell) that holds it. For 3,000 street points (Road_* triangle centres,
fixed seed) and every ordinary building whose centroid lies within NEAR metres,
the share whose detail mesh is farther than RANGE from the eye (1.7 m above the
street) is printed per map.
Run: python blank_facades.py --plain DIR [--cells METRES DIR ...]
"""
from pathlib import Path
import argparse, json, math, random
import numpy as np
from compare_outputs import Glb, PLAIN_RUN

BOUNDS = ((28.952-28.975)*111320*math.cos(math.radians(41.023)), (41.013-41.023)*111320)  # build_map.py
CASES = [(50, 100), (100, 100), (100, 200), (200, 200)]  # (NEAR, RANGE): low profile 100 m, high 200 m


def detail_mesh(x, y, cell):
    cx, cy = math.floor((x-BOUNDS[0])/150), math.floor((y-BOUNDS[1])/150)
    name = f'Detail_{cx:02}_{cy:02}'
    if cell:
        index = lambda offset: min(max(math.floor(offset/cell), 0), math.ceil(150/cell)-1)
        name += f'_{index(x-BOUNDS[0]-cx*150)}_{index(y-BOUNDS[1]-cy*150)}'
    return name


def main():
    cli = argparse.ArgumentParser(description='Share of nearby buildings whose facade detail a visibility range hides.')
    cli.add_argument('--plain', type=Path, default=PLAIN_RUN, help='run without --detail-cell (default: %(default)s)')
    cli.add_argument('--cells', nargs=2, action='append', default=[], metavar=('METRES', 'DIR'), help='a --detail-cell run')
    opts = cli.parse_args()
    records = [r for r in json.loads((opts.plain/'buildings.json').read_text()) if r.get('height_source') in ('osm', 'estimated')]
    east = np.array([r['east'] for r in records])
    north = np.array([r['north'] for r in records])
    plain = Glb(opts.plain/'istanbul_halic.glb')
    points = []
    for name, primitive in plain.meshes.items():
        if name.startswith('Road_'):
            v = plain.accessor(primitive['attributes']['POSITION'])
            points.append(v[plain.accessor(primitive['indices']).reshape(-1, 3)].mean(axis=1))
    points = np.concatenate(points)
    random.seed(7)
    points = points[random.sample(range(len(points)), 3000)]
    for label, folder, cell in [('plain', opts.plain, None)] + [(f'{m} m', Path(d), float(m)) for m, d in opts.cells]:
        glb = Glb(folder/'istanbul_halic.glb')
        centres = {}
        for name, primitive in glb.meshes.items():
            a = glb.json['accessors'][primitive['attributes']['POSITION']]
            centres[name] = (np.array(a['min']) + np.array(a['max'])) / 2

        def centre(x, y):  # buildings.json rounds to 1 cm; at a cell edge try the neighbours
            for dx, dy in [(0, 0), (.01, 0), (-.01, 0), (0, .01), (0, -.01), (.01, .01), (-.01, -.01), (.01, -.01), (-.01, .01)]:
                if detail_mesh(x + dx, y + dy, cell) in centres:
                    return centres[detail_mesh(x + dx, y + dy, cell)]
            raise KeyError(detail_mesh(x, y, cell))
        mesh_centres = np.array([centre(x, y) for x, y in zip(east, north)])  # glTF: x east, y up, z -north
        shares = []
        for near, visible in CASES:
            blank = total = 0
            for p in points:
                nearby = np.hypot(east - p[0], -north - p[2]) <= near
                eye = p + np.array([0, 1.7, 0])
                blank += int((np.linalg.norm(mesh_centres[nearby] - eye, axis=1) > visible).sum())
                total += int(nearby.sum())
            shares.append(f'within {near} m, range {visible} m: {100 * blank / total:.1f} % blank')
        print(f'{label:6s} ' + '; '.join(shares))


if __name__ == '__main__':
    main()
