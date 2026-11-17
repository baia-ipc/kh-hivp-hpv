"""
Place small text labels next to tree nodes without touching anything drawn.

All coordinates are in points on the page. Obstacles are axis-aligned line
segments (branches) and boxes (tip labels, tip markers, labels already
placed). For each label the positions closest to its node are tried first:
on the branch leading to the node, inside the fork to its right, and then
further away on a fine grid.
"""

from __future__ import annotations

from typing import Iterator, List, Optional, Tuple

Box = Tuple[float, float, float, float]  # x0, y0, x1, y1


def _overlap(a: Box, b: Box) -> bool:
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


class Obstacles:
    def __init__(self, clearance: float = 0.45) -> None:
        self.boxes: List[Box] = []
        self.clearance = clearance

    def add_segment(self, x0: float, y0: float, x1: float, y1: float, width: float = 0.5) -> None:
        half = width / 2
        self.boxes.append((min(x0, x1) - half, min(y0, y1) - half,
                           max(x0, x1) + half, max(y0, y1) + half))

    def add_box(self, box: Box) -> None:
        self.boxes.append(box)

    def is_free(self, box: Box) -> bool:
        c = self.clearance
        grown = (box[0] - c, box[1] - c, box[2] + c, box[3] + c)
        return not any(_overlap(grown, other) for other in self.boxes)


def _candidates(nx: float, ny: float, stem: float, w: float, h: float,
                pad: float) -> Iterator[Tuple[float, float]]:
    """Lower-left corners to try, nearest to the node first."""
    yield nx - pad - w, ny + pad                      # on the branch, above
    yield nx - pad - w, ny - pad - h                  # on the branch, below
    if stem > w + 2 * pad:
        yield nx - stem / 2 - w / 2, ny + pad         # middle of the branch
        yield nx - stem / 2 - w / 2, ny - pad - h
    yield nx + pad, ny - h / 2                        # inside the fork
    yield nx + pad, ny + pad
    yield nx + pad, ny - pad - h
    offsets = []
    for i in range(-60, 21):
        for j in range(-24, 25):
            dx, dy = i * 0.5, j * 0.5
            offsets.append((dx * dx + 4 * dy * dy, dx, dy))
    for _, dx, dy in sorted(offsets):
        yield nx - pad - w + dx, ny + pad + dy


def place_label(obstacles: Obstacles, nx: float, ny: float, stem: float,
                w: float, h: float, pad: float = 0.7) -> Optional[Tuple[float, float]]:
    """Return the lower-left corner of a free position and reserve it."""
    for x0, y0 in _candidates(nx, ny, stem, w, h, pad):
        box = (x0, y0, x0 + w, y0 + h)
        if obstacles.is_free(box):
            obstacles.add_box(box)
            return x0, y0
    return None
