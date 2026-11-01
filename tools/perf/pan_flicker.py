#!/usr/bin/env python3
"""Shimmering in a slow camera pan, from tools/capture_views.gd --pan frames.

    <VENV>/bin/python -I tools/perf/pan_flicker.py VIEW X0,Y0,X1,Y1 OUT.gif LABEL=DIR/PREFIX [LABEL=DIR/PREFIX ...]

Each LABEL=DIR/PREFIX names the frames DIR/PREFIX_pan_NN.png of one variant
(e.g. cells=shots/cells/istanbul_halic_cells_high_far_avenue). For the region
X0,Y0-X1,Y1 it prints per variant the mean change per frame |I(t+1) - I(t)|,
the mean temporal second difference |2 I(t) - I(t-1) - I(t+1)| (luminance,
0-255, over the region's pixels and the frames), and their ratio. A steady
image moving a fraction of a pixel per frame changes almost linearly, so its
second difference stays small against its change (ratio near 0); pixels that
flip between window and wall and back (shimmering, aliasing) change by jumps,
which raises the ratio toward 1 and above. More detail raises both numbers.
Also writes OUT.gif with the regions side by side, at 1:1, one GIF frame per
captured frame. Needs Pillow and numpy (the generator's pinned environment,
docs/maps/istanbul_halic/README.md).
"""
import pathlib
import sys

import numpy as np
from PIL import Image


def frames(pattern, box):
    paths = sorted(pathlib.Path(pattern).parent.glob(pathlib.Path(pattern).name + "_pan_*.png"))
    return [Image.open(p).convert("RGB").crop(box) for p in paths]


def differences(images):
    """Mean |first difference| and mean |second difference| over pixels and frames."""
    lum = [np.asarray(im.convert("L"), dtype=np.float64) for im in images]
    first = [np.abs(lum[t + 1] - lum[t]).mean() for t in range(len(lum) - 1)]
    second = [np.abs(2 * lum[t] - lum[t - 1] - lum[t + 1]).mean() for t in range(1, len(lum) - 1)]
    return float(np.mean(first)), float(np.mean(second))


def main():
    if len(sys.argv) < 5:
        sys.exit(__doc__)
    view, box, out = sys.argv[1], tuple(int(v) for v in sys.argv[2].split(",")), sys.argv[3]
    variants = [arg.split("=", 1) for arg in sys.argv[4:]]
    clips = []
    print("| View | Variant | Frames | Change per frame | Second difference | Ratio |")
    print("|---|---|---|---|---|---|")
    for label, pattern in variants:
        images = frames(pattern, box)
        first, second = differences(images)
        print("| %s | %s | %d | %.2f | %.2f | %.2f |" % (view, label, len(images), first, second, second / first if first else 0.0))
        clips.append(images)
    width, height = box[2] - box[0], box[3] - box[1]
    count = min(len(c) for c in clips)
    sheets = []
    for t in range(count):
        sheet = Image.new("RGB", (width * len(clips) + 4 * (len(clips) - 1), height), "white")
        for i, clip in enumerate(clips):
            sheet.paste(clip[t], (i * (width + 4), 0))
        sheets.append(sheet)
    # One palette for every frame, so the GIF itself adds no flicker.
    palette = sheets[0].quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    gif = [sheet.quantize(palette=palette, dither=Image.Dither.NONE) for sheet in sheets]
    gif[0].save(out, save_all=True, append_images=gif[1:], duration=66, loop=0, optimize=True)


if __name__ == "__main__":
    main()
