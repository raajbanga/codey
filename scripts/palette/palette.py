"""Codey color palette (light, dark) + WCAG contrast check (NFR-12).

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
 'Surface':       ('#F6F5F2', '#141518'),
 'SurfaceRaised': ('#FFFFFF', '#1D1F23'),
 'Separator':     ('#E4E2DC', '#2F3136'),
 'FillNeutral':   ('#EEECE7', '#26282D'),
 # The faint dot grid on the paper background. Decoration only, no text.
 'PaperDot':      ('#DCD9D1', '#2A2C31'),
 'TextPrimary':   ('#1B1C1E', '#ECEBE7'),
 'TextSecondary': ('#5C5B57', '#A3A29D'),
 # Brand. `Brand` is text/icon/tint ink. `BrandFill` is the pastel button
 # fill, labeled with `OnBrandFill` (not white). `BrandSoft` sits behind
 # brand text (chips, icon tiles, inline code).
 'Brand':         ('#3A5578', '#A9C0DD'),
 'BrandFill':     ('#CFDCEB', '#2E415A'),
 'OnBrandFill':   ('#1F3350', '#DCE7F4'),
 'BrandSoft':     ('#E8EEF5', '#222B37'),
 # Status + tiers: text color, then its pastel fill.
 'Success':       ('#2F5A3B', '#A9D1B3'),
 'SuccessSoft':   ('#DDEBDF', '#23322A'),
 'Warning':       ('#6B4C10', '#E6C98E'),
 'WarningSoft':   ('#F3E6CC', '#372F20'),
 'Danger':        ('#8E2F28', '#F0A79E'),
 'DangerSoft':    ('#F6DEDB', '#3A2422'),
 'TierEasy':      ('#2F5A3B', '#A9D1B3'),
 'TierEasySoft':  ('#DDEBDF', '#23322A'),
 'TierMedium':    ('#6B4C10', '#E6C98E'),
 'TierMediumSoft':('#F3E6CC', '#372F20'),
 'TierHard':      ('#7A3045', '#EBB1BF'),
 'TierHardSoft':  ('#F2DDE3', '#3A252C'),
 # Code
 'CodeBackground':('#F3F2EE', '#191A1D'),
 'SyntaxPlain':   ('#1B1C1E', '#E4E3DF'),
 'SyntaxKeyword': ('#7A3466', '#E3A6CF'),
 'SyntaxType':    ('#2F5F6B', '#8FC6CF'),
 'SyntaxString':  ('#8A4B1F', '#E6B48A'),
 'SyntaxNumber':  ('#3A5578', '#A9C0DD'),
 'SyntaxComment': ('#66655F', '#8E8D88'),
 'SyntaxFunction':('#3F6A4B', '#A9D1B3'),
 'SyntaxAttribute':('#6E5214', '#E6C98E'),
}
# Increase Contrast variants (light, dark) for the neutrals.
HC = {
 'Separator':     ('#BDBAB2', '#55585F'),
 'TextPrimary':   ('#000000', '#FFFFFF'),
 'TextSecondary': ('#3F3E3B', '#C9C8C3'),
}
TEXT = ['TextPrimary', 'TextSecondary', 'Brand', 'Success', 'Warning', 'Danger',
        'TierEasy', 'TierMedium', 'TierHard']

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
        check('Brand',P['Brand'][i],P['BrandSoft'][i],mode+'/brand-soft')
        check('TextPrimary',P['TextPrimary'][i],P['BrandSoft'][i],mode+'/brand-soft')
        check('OnBrandFill',P['OnBrandFill'][i],P['BrandFill'][i],mode+'/brand-fill')
        for n in P:
            if n.startswith('Syntax'): check(n,P[n][i],P['CodeBackground'][i],mode+'/code')
    for r in rows:
        print('%-16s %-20s %s on %s  %.2f %s'%(r[0],r[1],r[2],r[3],r[4],'' if r[5] else 'FAIL'))
    print('FAILS',bad[0])
    raise SystemExit(1 if bad[0] else 0)

if __name__ == '__main__':
    main()
