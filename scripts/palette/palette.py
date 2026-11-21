"""Codey color palette (light, dark) + WCAG contrast check (NFR-12).

S41: muted two-tone hues (HSL, low saturation): a light soft fill, a mid
fill for buttons and bars, a dark ink. Slate brand; green / sand / rose /
red for status and tiers; neutral charcoal dark mode with clear edges.

Sprint 3 facelift (S9): "pastel ink". Warm paper neutrals, a desaturated
ink-blue accent, and pastel fills. Every color that carries text is dark
(light mode) or light (dark mode) enough to pass 4.5:1 on the surfaces and
on its own pastel fill.

Edit P (and HC for Increase Contrast variants), then:
  python3 scripts/palette/palette.py            # every pair must pass 4.5:1
  python3 scripts/palette/gen_colors.py codey/Resources/Assets.xcassets
"""
from contrast import *
# name: (light, dark)
P = {
 # Neutrals. Custom instead of iOS semantic colors so the paper tone is
 # warm; HC below restores the Increase Contrast behavior we gave up.
 'Surface':       ('#E6DECB', '#1B1B1A'),
 'SurfaceRaised': ('#FFFFFF', '#2D2D2B'),
 'Separator':     ('#BDB3A0', '#4C4B46'),
 'FillNeutral':   ('#DCD3BF', '#363531'),
 # The dot grid on the paper background (S40: stronger; ratio on Surface printed below
 # so it reads as a notebook page). Decoration only, never behind text alone.
 'PaperDot':      ('#B4AA94', '#43423E'),
 'TextPrimary':   ('#1B1C1E', '#F1EFE8'),
 'TextSecondary': ('#4E4C46', '#B4B2A9'),
 # Brand. `Brand` is text/icon/tint ink. `BrandFill` is the pastel button
 # fill, labeled with `OnBrandFill` (not white). `BrandSoft` sits behind
 # brand text (chips, icon tiles, inline code).
 'Brand':         ('#425576', '#AFBDD4'),
 'BrandFill':     ('#49576E', '#49576E'),
 'OnBrandFill':   ('#FFFFFF', '#FFFFFF'),
 'BrandSoft':     ('#E3E7ED', '#2F3641'),
 # Status + tiers: text color, then its pastel fill.
 'Success':       ('#355625', '#C1D9B5'),
 'SuccessSoft':   ('#E3ECDF', '#2E3928'),
 'Warning':       ('#564425', '#D9CCB5'),
 'WarningSoft':   ('#ECE7DF', '#393328'),
 'Danger':        ('#562625', '#D9B6B5'),
 'DangerSoft':    ('#ECDFDF', '#392828'),
 'TierEasy':      ('#355625', '#C1D9B5'),
 'TierEasySoft':  ('#E3ECDF', '#2E3928'),
 'TierMedium':    ('#564425', '#D9CCB5'),
 'TierMediumSoft':('#ECE7DF', '#393328'),
 'TierHard':      ('#562535', '#D9B5C1'),
 'TierHardSoft':  ('#ECDFE3', '#39282E'),
 # Game layer (S41): XP gold for rewards, and one hue per topic so the Play
 # board's tiles are told apart at a glance. Each is ink + pastel fill.
 'XP':            ('#594322', '#594322'),
 'XPSoft':        ('#EEE6D8', '#EEE6D8'),
 # Topic hues (S41, two-tone, muted): a light tile (Soft), dark text and
 # icons (ink), and a mid-tone Fill for the Play button and bars with a
 # white label.
 'TopicTeal':     ('#224F46', '#224F46'),
 'TopicTealSoft': ('#E0EBE9', '#E0EBE9'),
 'TopicTealFill': ('#42766B', '#42766B'),
 'TopicSand':   ('#4F3E22', '#4F3E22'),
 'TopicSandSoft':('#EBE7E0', '#EBE7E0'),
 'TopicSandFill':('#766342', '#766342'),
 'TopicSlate':    ('#26334A', '#26334A'),
 'TopicSlateSoft':('#E2E5E9', '#E2E5E9'),
 'TopicSlateFill':('#49576E', '#49576E'),
 'TopicCoral':    ('#4F2C22', '#4F2C22'),
 'TopicCoralSoft':('#EBE3E0', '#EBE3E0'),
 'TopicCoralFill':('#764E42', '#764E42'),
 'TopicSky':      ('#223B4F', '#223B4F'),
 'TopicSkySoft':  ('#E0E6EB', '#E0E6EB'),
 'TopicSkyFill':  ('#425F76', '#425F76'),
 'TopicRose':     ('#4F2231', '#4F2231'),
 'TopicRoseSoft': ('#EBE0E4', '#EBE0E4'),
 'TopicRoseFill': ('#764253', '#764253'),
 'TopicOlive':    ('#404F22', '#404F22'),
 'TopicOliveSoft':('#E7EBE0', '#E7EBE0'),
 'TopicOliveFill':('#647642', '#647642'),
 # Nov 17: five more hues for the extra topics and avatar colors (same
 # two-tone rule; white on Fill and Ink on Soft clear 4.5:1).
 'TopicGold':    ('#332F1E', '#332F1E'),
 'TopicGoldSoft':('#E2DCC6', '#E2DCC6'),
 'TopicGoldFill':('#6A5F34', '#6A5F34'),
 'TopicGreen':   ('#1E3320', '#1E3320'),
 'TopicGreenSoft':('#C6E2C8', '#C6E2C8'),
 'TopicGreenFill':('#346A39', '#346A39'),
 'TopicIndigo':  ('#1E1E33', '#1E1E33'),
 'TopicIndigoSoft':('#C6C6E2', '#C6C6E2'),
 'TopicIndigoFill':('#44447E', '#44447E'),
 'TopicViolet':  ('#2A1E33', '#2A1E33'),
 'TopicVioletSoft':('#D5C6E2', '#D5C6E2'),
 'TopicVioletFill':('#60427B', '#60427B'),
 'TopicPlum':    ('#331E32', '#331E32'),
 'TopicPlumSoft':('#E2C6DF', '#E2C6DF'),
 'TopicPlumFill':('#743E70', '#743E70'),
 # Code
 'CodeBackground':('#F3F2EE', '#222221'),
 'SyntaxPlain':   ('#1B1C1E', '#E4E3DF'),
 'SyntaxKeyword': ('#7A3466', '#E3A6CF'),
 'SyntaxType':    ('#2F5F6B', '#8FC6CF'),
 'SyntaxString':  ('#8A4B1F', '#E6B48A'),
 'SyntaxNumber':  ('#3A5578', '#A9C0DD'),
 'SyntaxComment': ('#66655F', '#8E8D88'),
 'SyntaxFunction':('#3F6A4B', '#A9D1B3'),
 'SyntaxAttribute':('#6E5214', '#E6C98E'),
}

# ---------------------------------------------------------------------------
# S41: the neutrals, brand, XP and topic hues come from Radix custom scales
# (radix_scales.json: seeds and source URL inside), so light and dark are
# one system instead of hand-picked hexes. Radix step roles:
#   1 page · 2 subtle bg · 3-5 component bg · 6-8 borders · 9-10 solid ·
#   11 low-contrast text · 12 high-contrast text.
# Topic tiles, XP and brand fills are two-tone: the light scale in both modes
# (light pastel cards on the dark page), so only neutrals and text change.
import json as _json, math as _math, os as _os

def _oklch_hex(L, C, H):
    a, b = C * _math.cos(_math.radians(H)), C * _math.sin(_math.radians(H))
    l_ = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m_ = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s_ = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    rgb = (4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
           -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
           -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_)
    def enc(x):
        x = min(max(x, 0.0), 1.0)
        return 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055
    return '#' + ''.join('%02X' % round(enc(c) * 255) for c in rgb)

_R = _json.load(open(_os.path.join(_os.path.dirname(__file__), 'radix_scales.json')))['scales']
def R(scale, mode, step):
    return _oklch_hex(*_R[scale][mode][step - 1])
def both(scale, light_step, dark_step=None):
    return (R(scale, 'light', light_step), R(scale, 'dark', dark_step or light_step))
def two_tone(scale, step):
    return (R(scale, 'light', step), R(scale, 'light', step))

P.update({
 'Surface':       both('gray', 1),
 'SurfaceRaised': ('#FFFFFF', R('gray', 'dark', 3)),
 'FillNeutral':   both('gray', 4),
 'Separator':     both('gray', 7),
 'PaperDot':      both('gray', 7, 6),
 'TextSecondary': both('gray', 11),
 'TextPrimary':   both('gray', 12),
 'Brand':         both('brand', 11),
 'BrandSoft':     both('brand', 4),
 'BrandFill':     two_tone('brand', 10),
 'XP':            two_tone('xp', 12),
 'XPSoft':        two_tone('xp', 4),
 'CodeBackground':(R('gray', 'light', 2), R('gray', 'dark', 2)),
})
for _name, _scale in [('Teal', 'teal'), ('Sand', 'sand'), ('Slate', 'brand'), ('Coral', 'coral'),
                      ('Sky', 'sky'), ('Rose', 'rose'), ('Olive', 'olive')]:
    P['Topic' + _name] = two_tone(_scale, 12)
    P['Topic' + _name + 'Soft'] = two_tone(_scale, 4)
    P['Topic' + _name + 'Fill'] = two_tone(_scale, 10)
# ---------------------------------------------------------------------------

# Increase Contrast variants (light, dark) for the neutrals.
HC = {
 'Separator':     ('#ABA8A0', '#5F5E5A'),
 'TextPrimary':   ('#000000', '#FFFFFF'),
 'TextSecondary': ('#363532', '#D2D1CC'),
}
TEXT = ['TextPrimary', 'TextSecondary', 'Brand', 'Success', 'Warning', 'Danger',
        'TierEasy', 'TierMedium', 'TierHard']
# Game colors (S41) keep their light pastels in dark mode too, as in the
# mockup: light cards on the dark page. Their inks are only ever drawn on
# their own soft fill, so that is the one pair checked.
GAME = ['XP', 'TopicTeal', 'TopicSand', 'TopicSlate', 'TopicCoral', 'TopicSky', 'TopicRose', 'TopicOlive', 'TopicGold', 'TopicGreen', 'TopicIndigo', 'TopicViolet', 'TopicPlum']

def main():
    rows=[]; bad=[0]
    def check(name, fg, bg, label, minimum=4.5):
        c=cr(fg,bg); ok=c>=minimum; bad[0]+= not ok
        rows.append((name,label,fg,bg,c,ok))
    for i, mode in ((0,'light'), (1,'dark')):
        surfaces = {'surface': P['Surface'][i], 'raised': P['SurfaceRaised'][i]}
        for n in TEXT:
            for k,bg in surfaces.items(): check(n,P[n][i],bg,mode+'/'+k)
            if n+'Soft' in P: check(n,P[n][i],P[n+'Soft'][i],mode+'/own-soft')
        for n in GAME: check(n,P[n][i],P[n+'Soft'][i],mode+'/own-soft')
        check('Brand',P['Brand'][i],P['BrandSoft'][i],mode+'/brand-soft')
        check('TextPrimary',P['TextPrimary'][i],P['BrandSoft'][i],mode+'/brand-soft')
        check('OnBrandFill',P['OnBrandFill'][i],P['BrandFill'][i],mode+'/brand-fill')
        for n in P:
            if n.startswith('Topic') and n.endswith('Fill'):
                check(n,'#FFFFFF',P[n][i],mode+'/white-label')
        for n in P:
            if n.startswith('Syntax'): check(n,P[n][i],P['CodeBackground'][i],mode+'/code')
    for r in rows:
        print('%-16s %-20s %s on %s  %.2f %s'%(r[0],r[1],r[2],r[3],r[4],'' if r[5] else 'FAIL'))
    print('FAILS',bad[0])
    raise SystemExit(1 if bad[0] else 0)

if __name__ == '__main__':
    main()
