import json, os, sys
sys.path.insert(0, '.')
from palette import P
root = sys.argv[1]
extra = {'BrandSoft': (('#4F4FE8', 0.12), ('#9A9AFF', 0.16))}
def comp(h, a=1.0):
    h = h.lstrip('#')
    return {"color-space": "srgb", "components": {
        "red": "0x%s" % h[0:2].upper(), "green": "0x%s" % h[2:4].upper(),
        "blue": "0x%s" % h[4:6].upper(), "alpha": "%.3f" % a}}
def colorset(light, dark, la=1.0, da=1.0):
    return {"colors": [
        {"idiom": "universal", "color": comp(light, la)},
        {"idiom": "universal", "appearances": [{"appearance": "luminosity", "value": "dark"}], "color": comp(dark, da)},
    ], "info": {"author": "xcode", "version": 1}}
folder = os.path.join(root, 'Colors')
os.makedirs(folder, exist_ok=True)
json.dump({"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}},
          open(os.path.join(folder, 'Contents.json'), 'w'), indent=2)
def write(name, data, base=folder):
    d = os.path.join(base, name + '.colorset'); os.makedirs(d, exist_ok=True)
    json.dump(data, open(os.path.join(d, 'Contents.json'), 'w'), indent=2)
for name, (l, d) in P.items():
    write(name, colorset(l, d))
for name, ((l, la), (d, da)) in extra.items():
    write(name, colorset(l, d, la, da))
# Accent = Brand (tint for text, toggles, links).
write('AccentColor', colorset(*P['Brand']), base=root)
print(sorted(list(P) + list(extra)))
