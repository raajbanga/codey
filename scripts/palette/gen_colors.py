"""Writes palette.P (and HC variants) into the asset catalog as colorsets.

Usage (from scripts/palette):
  python3 gen_colors.py ../../codey/Resources/Assets.xcassets
Regenerates Colors/ from scratch, so a color removed from P disappears.
"""
import json, os, shutil, sys
sys.path.insert(0, '.')
from palette import P, HC
root = sys.argv[1]
def comp(h, a=1.0):
    h = h.lstrip('#')
    return {"color-space": "srgb", "components": {
        "red": "0x%s" % h[0:2].upper(), "green": "0x%s" % h[2:4].upper(),
        "blue": "0x%s" % h[4:6].upper(), "alpha": "%.3f" % a}}
def colorset(light, dark, hc=None):
    dark_look = {"appearance": "luminosity", "value": "dark"}
    high = {"appearance": "contrast", "value": "high"}
    colors = [
        {"idiom": "universal", "color": comp(light)},
        {"idiom": "universal", "appearances": [dark_look], "color": comp(dark)},
    ]
    if hc:
        colors += [
            {"idiom": "universal", "appearances": [high], "color": comp(hc[0])},
            {"idiom": "universal", "appearances": [dark_look, high], "color": comp(hc[1])},
        ]
    return {"colors": colors, "info": {"author": "xcode", "version": 1}}
folder = os.path.join(root, 'Colors')
shutil.rmtree(folder, ignore_errors=True)
os.makedirs(folder)
json.dump({"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}},
          open(os.path.join(folder, 'Contents.json'), 'w'), indent=2)
def write(name, data, base=folder):
    d = os.path.join(base, name + '.colorset'); os.makedirs(d, exist_ok=True)
    json.dump(data, open(os.path.join(d, 'Contents.json'), 'w'), indent=2)
for name, (l, d) in P.items():
    write(name, colorset(l, d, HC.get(name)))
# Accent = Brand (tint for text, toggles, links).
write('AccentColor', colorset(*P['Brand']), base=root)
print(sorted(P))
