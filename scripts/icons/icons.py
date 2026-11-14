#!/usr/bin/env python3
"""Codey's line icons (S40), drawn here and written as template SVG image sets.

    python3 scripts/icons/icons.py

One 24 pt grid, 2 pt rounded strokes, no fills except the play
triangle: quiet line drawings that sit with the pastel-ink palette instead
of SF Symbols' filled glyphs. Every icon is our own drawing (no icon pack is
bundled). The Swift side is `Icon` (DesignSystem/Components/Icon.swift):
it maps the SF Symbol names the app already stores (topic `iconName`, tier
symbols, call sites) onto these assets, so data and call sites keep their
names and anything unmapped falls back to SF Symbols.
"""
import json
import pathlib
import shutil

OUT = pathlib.Path(__file__).resolve().parents[2] / 'codey/Resources/Assets.xcassets/Icons'

# name: (SF Symbol names it replaces, SVG body)
ICONS = {
    # Tabs
    'home': (['house.fill', 'house'],
             '<path d="M4 10.5 12 4l8 6.5V19a1 1 0 0 1-1 1h-4.5v-5.5h-5V20H5a1 1 0 0 1-1-1z"/>'),
    'cards': (['rectangle.stack.fill', 'rectangle.stack', 'rectangle.stack.badge.plus', 'rectangle.on.rectangle'],
              '<rect x="4" y="8" width="13" height="12" rx="2"/><path d="M8 4.5h10a2 2 0 0 1 2 2V16"/>'),
    'quiz': (['questionmark.bubble.fill', 'questionmark.bubble'],
             '<path d="M4 6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-6l-4.5 3.5V17H6a2 2 0 0 1-2-2z"/>'
             '<path d="M10 8.7a2 2 0 1 1 2.7 1.9c-.4.2-.7.5-.7.9v.3M12 14h.01"/>'),
    # Topics (Topic.iconName in the bundled question bank)
    'algorithm': (['function'],
                  '<circle cx="12" cy="5.5" r="2.5"/><circle cx="6" cy="18.5" r="2.5"/><circle cx="18" cy="18.5" r="2.5"/>'
                  '<path d="M10.9 7.8 7.1 16.2M13.1 7.8l3.8 8.4"/>'),
    'layers': (['square.stack.3d.up.fill', 'square.stack.3d.up'],
               '<path d="M12 3.5 21 8l-9 4.5L3 8z"/><path d="m3 12 9 4.5 9-4.5M3 16l9 4.5 9-4.5"/>'),
    'database': (['cylinder.split.1x2.fill', 'cylinder.split.1x2'],
                 '<ellipse cx="12" cy="5.5" rx="7.5" ry="2.5"/>'
                 '<path d="M4.5 5.5v13c0 1.4 3.4 2.5 7.5 2.5s7.5-1.1 7.5-2.5v-13M4.5 12c0 1.4 3.4 2.5 7.5 2.5s7.5-1.1 7.5-2.5"/>'),
    'globe': (['network', 'globe'],
              '<circle cx="12" cy="12" r="9"/><path d="M3 12h18"/>'
              '<path d="M12 3c2.4 2.6 3.6 5.6 3.6 9s-1.2 6.4-3.6 9c-2.4-2.6-3.6-5.6-3.6-9S9.6 5.6 12 3z"/>'),
    'chip': (['cpu'],
             '<rect x="6" y="6" width="12" height="12" rx="2"/><rect x="9.5" y="9.5" width="5" height="5" rx=".75"/>'
             '<path d="M9.5 2.5V6M14.5 2.5V6M9.5 18v3.5M14.5 18v3.5M2.5 9.5H6M2.5 14.5H6M18 9.5h3.5M18 14.5h3.5"/>'),
    'cube': (['cube.transparent', 'cube', 'shippingbox'],
             '<path d="M12 3 20 7.5v9L12 21l-8-4.5v-9z"/><path d="M4 7.5 12 12l8-4.5M12 12v9"/>'),
    'braces': (['swift', 'curlybraces'],
               '<path d="M8 4C6 4 5.5 5 5.5 7v2.2c0 1.3-.7 2.3-2 2.8 1.3.5 2 1.5 2 2.8V17c0 2 .5 3 2.5 3'
               'M16 4c2 0 2.5 1 2.5 3v2.2c0 1.3.7 2.3 2 2.8-1.3.5-2 1.5-2 2.8V17c0 2-.5 3-2.5 3"/>'),
    'code': (['chevron.left.forwardslash.chevron.right'],
             '<path d="m8 7.5-4.5 4.5L8 16.5M16 7.5l4.5 4.5-4.5 4.5M13.5 5l-3 14"/>'),
    'terminal': (['terminal'],
                 '<rect x="3" y="4.5" width="18" height="15" rx="2.5"/><path d="m7.5 10 2.5 2-2.5 2M12.5 15h4"/>'),
    # Actions
    'sparkles': (['sparkles'],
                 '<path d="M10 3.5 11.6 8.4 16.5 10l-4.9 1.6L10 16.5l-1.6-4.9L3.5 10l4.9-1.6z"/>'
                 '<path d="M18 14.5v5M15.5 17h5"/>'),
    'play': (['play.fill', 'play'],
             '<path d="M8 5.5v13l10.5-6.5z" fill="#000"/>'),
    'plus': (['plus'], '<path d="M12 5v14M5 12h14"/>'),
    'plus-circle': (['plus.circle.fill', 'plus.circle'],
                    '<circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/>'),
    'close': (['xmark'], '<path d="m6.5 6.5 11 11M17.5 6.5l-11 11"/>'),
    'chevron-right': (['chevron.right'], '<path d="m9.5 6 6 6-6 6"/>'),
    'chevron-left': (['chevron.left'], '<path d="m14.5 6-6 6 6 6"/>'),
    'chevron-down': (['chevron.down'], '<path d="m6 9.5 6 6 6-6"/>'),
    'arrow-up': (['arrow.up'], '<path d="M12 19V5M6 11l6-6 6 6"/>'),
    'level-up': (['arrow.up.circle.fill', 'arrow.up.circle'],
                 '<circle cx="12" cy="12" r="9"/><path d="M12 16.5v-9M8 11l4-4 4 4"/>'),
    'restart': (['arrow.counterclockwise'],
                '<path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3L4.5 9"/><path d="M4.5 4.5V9H9"/>'),
    'refresh': (['arrow.clockwise', 'arrow.triangle.2.circlepath'],
                '<path d="M19.5 12a7.5 7.5 0 1 1-2.2-5.3L19.5 9"/><path d="M19.5 4.5V9H15"/>'),
    'trash': (['trash'],
              '<path d="M4.5 7h15M10 4h4M6.5 7l1 12a1.5 1.5 0 0 0 1.5 1.4h6a1.5 1.5 0 0 0 1.5-1.4l1-12"/>'),
    'pencil': (['pencil'], '<path d="m15.5 4.5 4 4-11 11-4.5.5.5-4.5zM13.5 6.5l4 4"/>'),
    'eye': (['eye'],
            '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>'),
    'eye-off': (['eye.slash'],
                '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/>'
                '<circle cx="12" cy="12" r="3"/><path d="m4 4 16 16"/>'),
    'cloud-up': (['icloud.and.arrow.up', 'checkmark.icloud'],
                 '<path d="M7 18.5a4.5 4.5 0 0 1-.6-9A6 6 0 0 1 18 8.6a4 4 0 0 1-.5 9.9"/><path d="M12 20.5V12M9 14.5l3-3 3 3"/>'),
    # Status
    'flame': (['flame.fill', 'flame'],
              '<path d="M12 21c-3.6 0-6-2.4-6-5.6 0-3.2 2.4-5 3.4-7.9.5 1.6 1.4 2.6 2.4 3.1C12 7.5 13 5 15 3'
              'c.3 3.4 3 5.6 3 10.4 0 4.2-2.4 7.6-6 7.6z"/>'),
    'leaf': (['leaf.fill', 'leaf'], '<path d="M5 19C5 11 10 5.5 19 5c0 8.5-5.5 14-14 14zM5 19l8.5-8.5"/>'),
    'bolt': (['bolt.fill', 'bolt'], '<path d="M13 3 5 13.5h6L10 21l8-10.5h-6z"/>'),
    'lock': (['lock.fill', 'lock'], '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>'),
    'unlock': (['lock.open.fill', 'lock.open'],
               '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 7.7-1.5"/>'),
    'check': (['checkmark'], '<path d="m5 12.5 4.5 4.5L19 7.5"/>'),
    'check-circle': (['checkmark.circle.fill', 'checkmark.circle', 'checkmark.seal.fill'],
                     '<circle cx="12" cy="12" r="9"/><path d="m8.5 12.2 2.4 2.4 4.6-4.8"/>'),
    'alert': (['exclamationmark.triangle.fill', 'exclamationmark.triangle'],
              '<path d="M10.3 4.6 3 17.5a2 2 0 0 0 1.7 3h14.6a2 2 0 0 0 1.7-3L13.7 4.6a2 2 0 0 0-3.4 0z"/><path d="M12 9.5v4M12 17h.01"/>'),
    'star': (['star.fill', 'star', 'star.circle.fill'],
             '<path d="m12 3.8 2.5 5.2 5.7.7-4.2 3.9 1.1 5.6-5.1-2.7-5.1 2.7 1.1-5.6-4.2-3.9 5.7-.7z"/>'),
    'trophy': (['trophy.fill', 'trophy'],
               '<path d="M8 4h8v5a4 4 0 0 1-8 0z"/><path d="M8 6H5.5a2.5 2.5 0 0 0 2.6 3.5M16 6h2.5a2.5 2.5 0 0 1-2.6 3.5M12 13v7M8.5 20h7"/>'),
    'flag': (['flag.checkered', 'flag.fill', 'flag'], '<path d="M5.5 21V4M5.5 4.5h12l-2.5 4 2.5 4h-12"/>'),
    'pin': (['pin.fill', 'pin'], '<path d="M12 16v5M8 4h8l-1 5.5 3 3V16H6v-3.5l3-3z"/>'),
    'hash': (['number'], '<path d="M5 9h15M4 15h15M10 4 8 20M16 4l-2 16"/>'),
    'bulb': (['lightbulb'],
             '<path d="M9 18h6M10 21h4M8.5 14.5a6 6 0 1 1 7 0c-.6.6-1 1.4-1 2.3V18h-5v-1.2c0-.9-.4-1.7-1-2.3z"/>'),
    'chart': (['chart.line.uptrend.xyaxis'], '<path d="M3.5 20.5h17M5 16l5-5 3.5 3.5L20 8M15 8h5v5"/>'),
    # People
    'profile': (['person.crop.circle'],
                '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="10" r="3"/><path d="M6.6 18.2a6 6 0 0 1 10.8 0"/>'),
    'group': (['person.3.fill', 'person.3', 'person.2'],
              '<circle cx="9" cy="9" r="3"/><path d="M3.5 19a5.5 5.5 0 0 1 11 0M15.5 6.3a3 3 0 0 1 0 5.4M17.5 14.2a5.5 5.5 0 0 1 3 4.8"/>'),
}

SVG = ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" '
       'stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{}</svg>\n')


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    (OUT / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
    for name, (_, body) in ICONS.items():
        folder = OUT / f'icon-{name}.imageset'
        folder.mkdir()
        (folder / f'icon-{name}.svg').write_text(SVG.format(body))
        (folder / 'Contents.json').write_text(json.dumps({
            'images': [{'filename': f'icon-{name}.svg', 'idiom': 'universal'}],
            'info': {'author': 'xcode', 'version': 1},
            'properties': {'preserves-vector-representation': True, 'template-rendering-intent': 'template'},
        }, indent=2) + '\n')
    # The Swift lookup table, so the two can't drift.
    pairs = sorted((sf, name) for name, (sfs, _) in ICONS.items() for sf in sfs)
    lines = ',\n'.join(f'        "{sf}": "icon-{name}"' for sf, name in pairs)
    swift = OUT.parents[2] / 'Sources/DesignSystem/Components/IconTable.swift'
    swift.write_text(
        '// Generated by scripts/icons/icons.py. Do not edit.\n\n'
        'extension CodeyIcon {\n'
        '    /// SF Symbol name → Codey line icon asset.\n'
        f'    static let assets: [String: String] = [\n{lines},\n    ]\n'
        '}\n')
    print(f'{len(ICONS)} icons, {len(pairs)} symbol names → {OUT.relative_to(OUT.parents[3])}')


if __name__ == '__main__':
    main()
