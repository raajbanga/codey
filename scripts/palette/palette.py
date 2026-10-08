"""Codey color palette (light, dark) + WCAG contrast check (NFR-12).

Edit P, then:
  python3 scripts/palette/palette.py            # every pair must pass 4.5:1
  python3 scripts/palette/gen_colors.py codey/Resources/Assets.xcassets
"""
from contrast import *
# name: (light, dark)
P = {
 'Brand':        ('#4F4FE8', '#9A9AFF'),
 'BrandFill':    ('#4F4FE8', '#5656F0'),
 'Success':      ('#1A7034', '#4ADE80'),
 'Warning':      ('#965000', '#FBBF24'),
 'Danger':       ('#C4202B', '#FF7A7F'),
 'TierEasy':     ('#1A7034', '#4ADE80'),
 'TierMedium':   ('#965000', '#FBBF24'),
 'TierHard':     ('#A3238F', '#F27FE0'),
 'CodeBackground':('#F3F3F8', '#17171C'),
 'SyntaxPlain':  ('#1F1F24', '#E6E6EB'),
 'SyntaxKeyword':('#A1258F', '#FF7AB2'),
 'SyntaxType':   ('#0E6B78', '#5DD8C8'),
 'SyntaxString': ('#B3261E', '#FF8170'),
 'SyntaxNumber': ('#2F38C4', '#D9C97C'),
 'SyntaxComment':('#5D6B78', '#8B99A6'),
 'SyntaxFunction':('#356B2E', '#8FD07A'),
 'SyntaxAttribute':('#8A4A00', '#FFA14F'),
}
def main():
    LB={'raised':'#FFFFFF','grouped':'#F2F2F7'}; DB={'raised':'#1C1C1E','grouped':'#000000'}
    rows=[]; bad=[0]
    def check(name, fg, bg, label, minimum=4.5):
        c=cr(fg,bg); ok=c>=minimum; bad[0]+= not ok
        rows.append((name,label,fg,bg,c,ok))
    for n,(l,d) in P.items():
        if n.startswith('Syntax'):
            check(n,l,P['CodeBackground'][0],'light/code'); check(n,d,P['CodeBackground'][1],'dark/code')
        elif n=='CodeBackground': continue
        elif n=='BrandFill':
            check(n,'#FFFFFF',l,'light white-label'); check(n,'#FFFFFF',d,'dark white-label')
        else:
            for k,bg in LB.items(): check(n,l,bg,'light/'+k)
            check(n,l,blend(l,LB['raised'],.12),'light/own-12%-fill')
            for k,bg in DB.items(): check(n,d,bg,'dark/'+k)
            check(n,d,blend(d,DB['raised'],.16),'dark/own-16%-fill')
    for r in rows:
        print('%-16s %-20s %s on %s  %.2f %s'%(r[0],r[1],r[2],r[3],r[4],'' if r[5] else 'FAIL'))
    print('FAILS',bad[0])
    raise SystemExit(1 if bad[0] else 0)

if __name__ == '__main__':
    main()
