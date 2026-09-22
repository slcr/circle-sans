#!/usr/bin/env python3
"""Derive the Circle Sans sources from Albert Sans 1.25.

    python3 scripts/derive-from-albert-sans.py \
        AlbertSans.glyphs AlbertSans-Italic.glyphs --out sources

Circle Sans is Albert Sans 1.25 - the last release before the 1.3 respacing - with
these changes, applied here so that the derivation is reproducible rather than a
pile of hand edits:

  * family name, manufacturer, copyright and vendor ID read Coffee Circle;
  * the long-stem g (ss02) and the open ampersand (ss04) become the defaults, and
    the originals move into those stylistic-set slots;
  * the Q's centred vertical tail becomes a diagonal stroke at -52 degrees, cut
    from the ring of the master's own O, so it scales with weight but never rotates;
  * an f_f ligature is assembled the way the upstream fi is: the fi's first f, one
    fused crossbar, and a second f planted where the fi plants its i;
  * the Coffee Circle drip mark is added as drip.logo at U+E000, identical in every
    master, and the liga feature learns "[drip]".

The sources stay in Glyphs format 2, the format upstream used: a glyphsLib round trip
of that format rebuilds Albert Sans 1.25 table for table, whereas the format 3
conversion drifts by a unit in a few hundred accent positions and loses the
stylistic-set names.
"""
import argparse
import json
import math
import sys

import glyphsLib
from glyphsLib.classes import GSAnchor, GSGlyph, GSLayer, GSNode, GSPath
from glyphsLib.types import Point

FAMILY = "Circle Sans"
MANUFACTURER = "Coffee Circle"
MANUFACTURER_URL = "https://www.coffeecircle.com"
VENDOR_ID = "CCIR"
COPYRIGHT = "Copyright 2026 The Circle Sans Project Authors (https://github.com/slcr/circle-sans)"

TAIL_ANGLE = -52.0     # degrees, the same in every master
TAIL_INNER = 0.57      # inner end, as a fraction of the counter's radius along the tail
TAIL_OUTER = 1.205     # outer end, as a fraction of the ring's outer radius along the tail

LIGA = (
    "lookupflag IgnoreMarks;\n"
    "sub f i by fi;\n"
    "sub f f by f_f;\n"
    "sub bracketleft d r i p bracketright by drip.logo;\n"
)

# The drip mark, in font units, 744 wide. Outer contour positive, counter negative.
DRIP_WIDTH = 744
DRIP = json.loads("""
[{"closed": 1, "nodes": [[570, 389, "curve", true], [570, 299, "offcurve", false], [510, 223, "offcurve", false], [428, 199, "curve", false], [405, 188, "offcurve", false], [385, 177, "offcurve", false], [375, 156, "curve", false], [369, 156, "line", false], [359, 177, "offcurve", false], [340, 188, "offcurve", false], [317, 198, "curve", false], [234, 222, "offcurve", false], [174, 299, "offcurve", false], [174, 389, "curve", true], [174, 499, "offcurve", false], [262, 588, "offcurve", false], [372, 588, "curve", true], [481, 588, "offcurve", false], [570, 499, "offcurve", false]]},
 {"closed": 1, "nodes": [[688, 383, "curve", true], [688, 558, "offcurve", false], [547, 700, "offcurve", false], [372, 700, "curve", true], [198, 700, "offcurve", false], [56, 558, "offcurve", false], [56, 383, "curve", true], [56, 224, "offcurve", false], [172, 93, "offcurve", false], [324, 70, "curve", false], [350, 64, "offcurve", false], [371, 42, "offcurve", false], [365, 30, "curve", false], [346, 4, "offcurve", false], [296, -70, "offcurve", false], [296, -117, "curve", true], [296, -159, "offcurve", false], [324, -200, "offcurve", false], [372, -200, "curve", true], [419, -200, "offcurve", false], [448, -159, "offcurve", false], [448, -117, "curve", true], [448, -70, "offcurve", false], [399, 2, "offcurve", false], [380, 29, "curve", false], [372, 41, "offcurve", false], [394, 64, "offcurve", false], [421, 70, "curve", false], [572, 93, "offcurve", false], [688, 225, "offcurve", false]]}]
""")


# --- small geometry helpers --------------------------------------------------

def node(x, y, kind="line", smooth=False):
    n = GSNode(position=(round(x), round(y)), nodetype=kind)
    n.smooth = smooth
    return n


def path_from(nodes, closed=True):
    p = GSPath()
    for n in nodes:
        p.nodes.append(n)
    p.closed = closed
    return p


def copy_path(path, dx=0.0):
    return path_from(
        [node(n.position.x + dx, n.position.y, n.type, n.smooth) for n in path.nodes],
        path.closed,
    )


def signed_area(points):
    return sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(points, points[1:] + points[:1])) / 2


def flatten(path, steps=48):
    """Sample a closed Glyphs path (cubic Béziers and lines) as a polygon."""
    nodes = list(path.nodes)
    k = len(nodes) - 1
    while nodes[k].type == "offcurve":
        k -= 1
    prev = (nodes[k].position.x, nodes[k].position.y)
    seq = nodes[k + 1:] + nodes[: k + 1]
    pts, ctrl = [], []
    for nd in seq:
        p = (nd.position.x, nd.position.y)
        if nd.type == "offcurve":
            ctrl.append(p)
            continue
        if not ctrl:
            pts.append(prev)
        else:
            (c1, c2) = ctrl
            for j in range(steps):
                t = j / steps
                m = 1 - t
                pts.append((
                    m ** 3 * prev[0] + 3 * m * m * t * c1[0] + 3 * m * t * t * c2[0] + t ** 3 * p[0],
                    m ** 3 * prev[1] + 3 * m * m * t * c1[1] + 3 * m * t * t * c2[1] + t ** 3 * p[1],
                ))
            ctrl = []
        prev = p
    return pts


def ray_hits(polygon, origin, direction):
    """Distances along the ray at which it crosses the polygon's edges."""
    out = []
    for p, q in zip(polygon, polygon[1:] + polygon[:1]):
        e = (q[0] - p[0], q[1] - p[1])
        den = direction[0] * e[1] - direction[1] * e[0]
        if abs(den) < 1e-12:
            continue
        s = ((p[0] - origin[0]) * e[1] - (p[1] - origin[1]) * e[0]) / den
        u = ((p[0] - origin[0]) * direction[1] - (p[1] - origin[1]) * direction[0]) / den
        if 0 <= u < 1 and s > 0:
            out.append(s)
    return sorted(out)


def layer_of(glyph, master):
    for layer in glyph.layers:
        if layer.layerId == master.id:
            return layer
    raise KeyError(f"{glyph.name} has no layer for master {master.name}")


# --- the changes ------------------------------------------------------------

def rename(font):
    font.familyName = FAMILY
    font.manufacturer = MANUFACTURER
    font.manufacturerURL = MANUFACTURER_URL
    font.copyright = COPYRIGHT
    font.customParameters["vendorID"] = VENDOR_ID
    font.versionMajor = 2
    font.versionMinor = 0


def swap_glyphs(font, a_name, b_name):
    """Exchange everything but name and code point, so the alternate becomes the default."""
    a, b = font.glyphs[a_name], font.glyphs[b_name]
    for attr in ("leftKerningGroup", "rightKerningGroup", "leftMetricsKey", "rightMetricsKey"):
        va, vb = getattr(a, attr), getattr(b, attr)
        setattr(a, attr, vb)
        setattr(b, attr, va)
    for master in font.masters:
        la, lb = layer_of(a, master), layer_of(b, master)
        for attr in ("width", "paths", "components", "anchors", "hints"):
            va, vb = getattr(la, attr), getattr(lb, attr)
            if attr != "width":
                va, vb = list(va), list(vb)
            setattr(la, attr, vb)
            setattr(lb, attr, va)
    # Kerning written against the glyphs themselves follows the outlines.
    for master_kerning in font.kerning.values():
        for left, rights in list(master_kerning.items()):
            for old, new in ((a_name, b_name), (b_name, a_name)):
                if old in rights and new not in rights:
                    rights[new] = rights.pop(old)
        for old, new in ((a_name, b_name), (b_name, a_name)):
            if old in master_kerning and new not in master_kerning:
                master_kerning[new] = master_kerning.pop(old)


def tail_path(o_layer, italic_angle):
    """The Q's tail: a straight stroke at TAIL_ANGLE through the centre of this master's O.

    It is as thick as the ring where it crosses it, starts inside the counter and
    ends past the outer edge. Italic masters are measured upright and slanted back.
    """
    skew = math.tan(math.radians(italic_angle))
    upright = lambda p: (p[0] - p[1] * skew, p[1])
    slant = lambda p: (p[0] + p[1] * skew, p[1])

    polys = [[upright(p) for p in flatten(path)] for path in o_layer.paths]
    polys.sort(key=lambda poly: max(x for x, _ in poly) - min(x for x, _ in poly))
    inner, outer = polys[0], polys[-1]
    xs = [x for x, _ in outer]
    ys = [y for _, y in outer]
    centre = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2)

    d = (math.cos(math.radians(TAIL_ANGLE)), math.sin(math.radians(TAIL_ANGLE)))
    n = (-d[1], d[0])
    r_in = ray_hits(inner, centre, d)[0]
    r_out = ray_hits(outer, centre, d)[0]
    thickness = r_out - r_in
    start, end = TAIL_INNER * r_in, TAIL_OUTER * r_out

    def at(s, side):
        return (centre[0] + d[0] * s + n[0] * side, centre[1] + d[1] * s + n[1] * side)

    h = thickness / 2
    corners = [at(start, h), at(start, -h), at(end, -h), at(end, h)]
    if signed_area(corners) < 0:
        corners.reverse()
    return path_from([node(*slant(c)) for c in corners]), thickness


def redraw_q(font):
    """Replace the Q's vertical bar with the diagonal tail.

    The roman Q is an O component plus the bar; the italic Q carries its own copy
    of the O's two contours plus the bar. Either way the bar is the one short
    straight path, and the ring the tail is cut from is whatever the Q shows.
    """
    report = []
    for master in font.masters:
        q = layer_of(font.glyphs["Q"], master)
        ring = [p for p in q.paths if len(p.nodes) > 4]
        bars = [p for p in q.paths if len(p.nodes) <= 4]
        if len(bars) != 1:
            sys.exit(f"{master.name}: expected the Q to have exactly one bar path, found {len(bars)}")
        if any(c.name == "O" for c in q.components):
            source = layer_of(font.glyphs["O"], master)
        elif len(ring) == 2:
            source = GSLayer()
            source.paths = ring
        else:
            sys.exit(f"{master.name}: cannot find the Q's ring")
        tail, thickness = tail_path(source, master.italicAngle)
        q.paths = ring + [tail]
        report.append(f"{master.name}: tail {thickness:.0f} thick")
    return report


def build_ff(f_layer, fi_layer):
    f_nodes = [n for p in f_layer.paths for n in p.nodes]
    f_stem_left = min(n.position.x for n in f_nodes if abs(n.position.y) < 0.5)
    fi_feet = sorted(n.position.x for p in fi_layer.paths for n in p.nodes if abs(n.position.y) < 0.5)
    if len(fi_feet) != 4:
        raise ValueError("fi should stand on exactly two stems")
    dx = fi_feet[2] - f_stem_left

    bar_top = 500
    bottoms = {round(n.position.y) for n in f_nodes if 300 < n.position.y < 499}
    if len(bottoms) != 1:
        raise ValueError(f"cannot find the f's crossbar bottom: {bottoms}")
    bar_bottom = bottoms.pop()
    right_bottom = max(n.position.x for n in f_nodes if abs(n.position.y - bar_bottom) < 0.5)
    right_top = max(n.position.x for n in f_nodes if abs(n.position.y - bar_top) < 0.5)

    def has_foot(p):
        return any(abs(n.position.y) < 0.5 for n in p.nodes)

    def has_bar(p):
        return any(300 < n.position.y < 502 for n in p.nodes)

    bar_paths = [p for p in fi_layer.paths if has_foot(p) and has_bar(p)]
    stem_paths = [p for p in fi_layer.paths if has_foot(p) and not has_bar(p)]
    if len(bar_paths) != 1 or len(stem_paths) != 1:
        raise ValueError("fi is not drawn as a first f plus a bar-and-stem")
    lefts = sorted(bar_paths[0].nodes, key=lambda n: n.position.x)[:2]
    left_top = max(lefts, key=lambda n: n.position.y)
    left_bottom = min(lefts, key=lambda n: n.position.y)

    fused_bar = path_from([
        node(left_top.position.x, bar_top),
        node(left_bottom.position.x, bar_bottom),
        node(right_bottom + dx, bar_bottom),
        node(right_top + dx, bar_top),
    ])
    layer = GSLayer()
    layer.width = dx + f_layer.width
    layer.paths = [copy_path(stem_paths[0]), fused_bar] + [copy_path(p, dx) for p in f_layer.paths]
    layer.anchors = [GSAnchor(a.name, Point(a.position.x, a.position.y)) for a in fi_layer.anchors]
    return layer


def add_ff(font):
    glyph = GSGlyph("f_f")
    glyph.export = True
    order = list(font.glyphs)
    order.insert(order.index(font.glyphs["fi"]) + 1, glyph)
    font.glyphs = order
    for master in font.masters:
        layer = build_ff(layer_of(font.glyphs["f"], master), layer_of(font.glyphs["fi"], master))
        layer.layerId = master.id
        glyph.layers.append(layer)
    # Kern it as the f is kerned, on both flanks.
    added = 0
    for master_kerning in font.kerning.values():
        for left, rights in list(master_kerning.items()):
            if "f" in rights:
                rights["f_f"] = rights["f"]
                added += 1
        if "f" in master_kerning:
            master_kerning["f_f"] = dict(master_kerning["f"])
            added += len(master_kerning["f"])
    return added


def add_drip(font):
    glyph = GSGlyph("drip.logo")
    glyph.unicode = "E000"
    glyph.export = True
    glyph.category = "Symbol"
    font.glyphs.append(glyph)
    for master in font.masters:
        layer = GSLayer()
        layer.layerId = master.id
        layer.width = DRIP_WIDTH
        layer.paths = [
            path_from([node(x, y, kind, smooth) for x, y, kind, smooth in p["nodes"]], bool(p["closed"]))
            for p in DRIP
        ]
        glyph.layers.append(layer)


SS_NAMES = {
    "ss02": "Original short-stem g",
    "ss04": "Original ampersand",
}


def set_features(font):
    """Extend liga, and rename the two stylistic sets whose contents moved.

    A Glyphs 2 file carries a stylistic set's menu name as a "Name:" note.
    """
    seen = set()
    for feature in font.features:
        seen.add(feature.name)
        if feature.name == "liga":
            feature.code = LIGA
        if feature.name in SS_NAMES:
            feature.notes = f"Name: {SS_NAMES[feature.name]}"
    if "liga" not in seen:
        sys.exit("no liga feature to extend")


def derive(src, dst):
    font = glyphsLib.GSFont(src)
    print(f"{src}: {font.familyName} {font.versionMajor}.{font.versionMinor:03d}, "
          f"{len(font.glyphs)} glyphs, masters {[m.name for m in font.masters]}")
    rename(font)
    swap_glyphs(font, "g", "g.ss02")
    swap_glyphs(font, "ampersand", "ampersand.ss04")
    for line in redraw_q(font):
        print("  Q", line)
    print(f"  f_f: {add_ff(font)} kern pairs mirrored from f")
    add_drip(font)
    set_features(font)
    font.save(dst)
    print(f"  -> {dst}: {len(font.glyphs)} glyphs")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("roman")
    ap.add_argument("italic")
    ap.add_argument("--out", default="sources")
    args = ap.parse_args()
    derive(args.roman, f"{args.out}/CircleSans.glyphs")
    derive(args.italic, f"{args.out}/CircleSans-Italic.glyphs")


if __name__ == "__main__":
    main()
