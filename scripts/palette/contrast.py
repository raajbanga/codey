"""WCAG 2.x contrast helpers used by palette.py (NFR-12).

lum(): relative luminance of "#rrggbb"; cr(a, b): contrast ratio;
blend(fg, bg, a): fg at alpha a over bg, for translucent fills.
"""
import sys
def lum(h):
    h=h.lstrip('#'); r,g,b=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    f=lambda c: c/12.92 if c<=0.03928 else ((c+0.055)/1.055)**2.4
    return 0.2126*f(r)+0.7152*f(g)+0.0722*f(b)
def cr(a,b):
    la,lb=sorted([lum(a),lum(b)],reverse=True); return (la+0.05)/(lb+0.05)
def blend(fg,bg,a):
    fg=fg.lstrip('#'); bg=bg.lstrip('#')
    return '#'+''.join('%02x'%round(int(fg[i:i+2],16)*a+int(bg[i:i+2],16)*(1-a)) for i in (0,2,4))
