#!/usr/bin/env python3
"""Lists what an exported package holds and compares it with what it should.

Reads an Android APK (the project's files under assets/) or a Godot .pck
(the iOS export's), maps every packed file back to the project file it
comes from (X.remap and X.import name X; X.gdc is the compiled X.gd; the
.godot/exported and .godot/imported files are what those remaps and imports
point to), and prints the sizes per folder. With --expect (the list that
tools/check_release.gd --list writes) it fails when the package holds a
project file that is not on the list, lacks one that is, or holds a
converted or imported file that no packed project file points to.

  python3 -I tools/release_contents.py build/android/map-simulator-release.apk --expect build/release/android.expected.txt
  python3 -I tools/release_contents.py build/ios_release/map_simulator.pck --expect build/release/ios.expected.txt

Exit code 0 when the package is as expected (or no list was given), 1 when not.
"""

import argparse
import re
import struct
import sys
import zipfile
from collections import defaultdict

# Files an export adds at the top that are not project files (the project
# settings, the Android export's index of its files, its command line).
ENGINE_FILES = {"project.binary", "assets.sparsepck", "_cl_"}


def read_apk(path):
    """{project-relative path: (size, reader)} of the files under assets/."""
    archive = zipfile.ZipFile(path)
    entries = {}
    for info in archive.infolist():
        if info.filename.startswith("assets/") and not info.filename.startswith("assets/dexopt/") and not info.is_dir():
            entries[info.filename[len("assets/"):]] = (info.compress_size, lambda name=info.filename: archive.read(name))
    return entries


def read_pck(path):
    """{project-relative path: (size, reader)} of a Godot 4 .pck (format 2 to 4)."""
    handle = open(path, "rb")
    magic, version, _major, _minor, _patch, _flags, file_base = struct.unpack("<4sIIIIIQ", handle.read(32))
    if magic != b"GDPC" or not 2 <= version <= 4:
        sys.exit("%s: not a Godot 4 pack (magic %r, version %d)" % (path, magic, version))
    if version >= 3:
        (directory,) = struct.unpack("<Q", handle.read(8))
        handle.seek(directory)
    else:
        handle.read(64)
    (count,) = struct.unpack("<I", handle.read(4))
    entries = {}
    for _ in range(count):
        (length,) = struct.unpack("<I", handle.read(4))
        name = handle.read(length).rstrip(b"\0").decode("utf-8")
        offset, size = struct.unpack("<QQ", handle.read(16))
        handle.read(20)  # md5, flags

        def reader(offset=offset, size=size):
            handle.seek(file_base + offset)
            return handle.read(size)

        entries[name[len("res://"):] if name.startswith("res://") else name] = (size, reader)
    return entries


def project_file(name):
    """The project file a packed file stands for, or None for engine data."""
    for suffix in (".remap", ".import"):
        if name.endswith(suffix):
            return name[: -len(suffix)]
    if name.endswith(".gdc"):
        return name[:-1]
    if name.startswith(".godot/") or name in ENGINE_FILES:
        return None
    return name


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("package")
    parser.add_argument("--expect")
    args = parser.parse_args()
    entries = read_apk(args.package) if args.package.endswith(".apk") else read_pck(args.package)

    sources = defaultdict(int)
    pointed = set()
    for name, (size, reader) in entries.items():
        source = project_file(name)
        if source is not None:
            sources[source] += size
        if name.endswith((".remap", ".import")):
            pointed.update(re.findall(rb'path(?:\.[a-z0-9_]+)?="res://([^"]+)"', reader()))
    pointed = {path.decode("utf-8") for path in pointed}

    per_folder = defaultdict(lambda: [0, 0])
    for name, (size, _reader) in entries.items():
        folders = name.split("/")[:-1]
        key = "/".join(folders[: 3 if folders[:1] == ["maps"] else 2]) or "(root)"
        per_folder[key][0] += 1
        per_folder[key][1] += size
    total = sum(size for size, _ in entries.values())
    print("%s: %d files, %.1f MB stored" % (args.package, len(entries), total / 1e6))
    for key in sorted(per_folder, key=lambda k: -per_folder[k][1]):
        count, size = per_folder[key]
        print("  %-60s %6d files %9.1f MB" % (key, count, size / 1e6))

    if not args.expect:
        return 0
    expected = {line.strip()[len("res://"):] for line in open(args.expect) if line.strip()}
    unexpected = sorted(set(sources) - expected)
    missing = sorted(expected - set(sources))
    orphans = sorted(name for name in entries if name.startswith((".godot/exported/", ".godot/imported/")) and name not in pointed)
    for name in unexpected:
        print("UNEXPECTED %s" % name)
    for name in missing:
        print("MISSING %s" % name)
    for name in orphans:
        print("ORPHAN %s (no packed file points to it)" % name)
    print("%d project files packed, %d expected: %d unexpected, %d missing, %d orphaned converted or imported files"
          % (len(sources), len(expected), len(unexpected), len(missing), len(orphans)))
    return 1 if unexpected or missing or orphans else 0


if __name__ == "__main__":
    sys.exit(main())
