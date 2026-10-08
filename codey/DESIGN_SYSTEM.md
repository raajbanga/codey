# Codey Design System

Tokens and components for every screen. Screens use these. They never use raw
`Color(...)`, hex values, literal corner radii, or raw system fonts.
`scripts/check-design-tokens.sh` enforces that.

## Layout (`codey/Sources/DesignSystem/`)

| Folder | What |
|---|---|
| `Tokens/` | `CodeyColor`, `CodeyRadius`, `CodeySpacing`, type (`Font.codey*`), `CodeyMotion`, `TierStyle`, `SyntaxRole` |
| `Components/` | `CodeyCard`, `CodeyButton`, `CodeyChip`, `AnswerOptionRow`, `ProgressBar`, `ProgressRing`, `StatTile`, `TierChipRow`, `EmptyStateView`, `CelebrationOverlay`, `XPGainLabel` |
| `Markdown/` | `CardMarkdownView` (the **only** `import Textual`), `CardMarkdownComposition`, `MarkdownTextEditor`, `MarkdownFormatting` |
| `CodeEditor/` | `CodeEditorView` + `CodeyRunestoneTheme` (the **only** Runestone/TreeSitter imports) |
| `Gallery/` | `ComponentGallery` previews: light, dark, AX3, XS |

## Rules

- **Glass is for the control layer only**: toolbars, floating CTAs (`CodeyButton(kind: .glassPrimary)`), and overlays. Content cards are solid `surfaceRaised`.
- **Corners (D19)**: use `Capsule` only for single-line, fixed-height controls (`CodeyChip`, `ProgressBar`, single-line `CodeyButton`). Anything that can wrap uses `.codey(CodeyRadius.md)`. Cards use `lg`. Nested surfaces use `CodeyRadius.concentric(outer:inset:)` or container-relative shapes.
- **Color is never the only signal**: tiers carry a symbol and a label (`TierStyle`), and answer states carry an icon and a VoiceOver value.
- **Motion**: use `.codeyAnimation` / `withCodeyAnimation`. Under Reduce Motion both fall back to a short crossfade. Particles only for level-ups and tier unlocks.
- **Haptics**: use `.sensoryFeedback`, not UIKit feedback generators.
- **brand vs brandFill**: `brand` is for text, icons, and tint. `brandFill` sits behind white labels. In dark mode, no single indigo passes 4.5:1 for both uses.

## Contrast (NFR-12)

The palette lives in `scripts/palette/palette.py`. To change a color, edit it
there and run:

```sh
python3 scripts/palette/palette.py                                   # must print FAILS 0
python3 scripts/palette/gen_colors.py codey/Resources/Assets.xcassets   # regenerates the colorsets
```

Surfaces and text use iOS semantic colors (`systemGroupedBackground`,
`secondarySystemGroupedBackground`, `label`, `secondaryLabel`). The checks
below use their default values: light raised `#FFFFFF`, light grouped
`#F2F2F7`, dark raised `#1C1C1E`, dark grouped `#000000`. Soft fills are 12%
(light) and 16% (dark) of the color over the raised surface (`CodeyColor.softFill`).

| Token | Pair | Foreground | Background | Ratio |
|---|---|---|---|---|
| Brand | light/raised | `#4F4FE8` | `#FFFFFF` | 5.81 |
| Brand | light/grouped | `#4F4FE8` | `#F2F2F7` | 5.20 |
| Brand | light/own-12%-fill | `#4F4FE8` | `#eaeafc` | 4.89 |
| Brand | dark/raised | `#9A9AFF` | `#1C1C1E` | 6.84 |
| Brand | dark/grouped | `#9A9AFF` | `#000000` | 8.44 |
| Brand | dark/own-16%-fill | `#9A9AFF` | `#303042` | 5.19 |
| BrandFill | light white-label | `#FFFFFF` | `#4F4FE8` | 5.81 |
| BrandFill | dark white-label | `#FFFFFF` | `#5656F0` | 5.27 |
| Success | light/raised | `#1A7034` | `#FFFFFF` | 6.16 |
| Success | light/grouped | `#1A7034` | `#F2F2F7` | 5.52 |
| Success | light/own-12%-fill | `#1A7034` | `#e4eee7` | 5.18 |
| Success | dark/raised | `#4ADE80` | `#1C1C1E` | 9.76 |
| Success | dark/grouped | `#4ADE80` | `#000000` | 12.05 |
| Success | dark/own-16%-fill | `#4ADE80` | `#233b2e` | 6.94 |
| Warning | light/raised | `#965000` | `#FFFFFF` | 6.10 |
| Warning | light/grouped | `#965000` | `#F2F2F7` | 5.46 |
| Warning | light/own-12%-fill | `#965000` | `#f2eae0` | 5.12 |
| Warning | dark/raised | `#FBBF24` | `#1C1C1E` | 10.19 |
| Warning | dark/grouped | `#FBBF24` | `#000000` | 12.58 |
| Warning | dark/own-16%-fill | `#FBBF24` | `#40361f` | 7.13 |
| Danger | light/raised | `#C4202B` | `#FFFFFF` | 5.85 |
| Danger | light/grouped | `#C4202B` | `#F2F2F7` | 5.24 |
| Danger | light/own-12%-fill | `#C4202B` | `#f8e4e6` | 4.80 |
| Danger | dark/raised | `#FF7A7F` | `#1C1C1E` | 6.76 |
| Danger | dark/grouped | `#FF7A7F` | `#000000` | 8.34 |
| Danger | dark/own-16%-fill | `#FF7A7F` | `#402b2e` | 5.20 |
| TierEasy | light/raised | `#1A7034` | `#FFFFFF` | 6.16 |
| TierEasy | light/grouped | `#1A7034` | `#F2F2F7` | 5.52 |
| TierEasy | light/own-12%-fill | `#1A7034` | `#e4eee7` | 5.18 |
| TierEasy | dark/raised | `#4ADE80` | `#1C1C1E` | 9.76 |
| TierEasy | dark/grouped | `#4ADE80` | `#000000` | 12.05 |
| TierEasy | dark/own-16%-fill | `#4ADE80` | `#233b2e` | 6.94 |
| TierMedium | light/raised | `#965000` | `#FFFFFF` | 6.10 |
| TierMedium | light/grouped | `#965000` | `#F2F2F7` | 5.46 |
| TierMedium | light/own-12%-fill | `#965000` | `#f2eae0` | 5.12 |
| TierMedium | dark/raised | `#FBBF24` | `#1C1C1E` | 10.19 |
| TierMedium | dark/grouped | `#FBBF24` | `#000000` | 12.58 |
| TierMedium | dark/own-16%-fill | `#FBBF24` | `#40361f` | 7.13 |
| TierHard | light/raised | `#A3238F` | `#FFFFFF` | 6.57 |
| TierHard | light/grouped | `#A3238F` | `#F2F2F7` | 5.89 |
| TierHard | light/own-12%-fill | `#A3238F` | `#f4e5f2` | 5.43 |
| TierHard | dark/raised | `#F27FE0` | `#1C1C1E` | 7.20 |
| TierHard | dark/grouped | `#F27FE0` | `#000000` | 8.89 |
| TierHard | dark/own-16%-fill | `#F27FE0` | `#3e2c3d` | 5.44 |
| SyntaxPlain | light/code | `#1F1F24` | `#F3F3F8` | 14.84 |
| SyntaxPlain | dark/code | `#E6E6EB` | `#17171C` | 14.36 |
| SyntaxKeyword | light/code | `#A1258F` | `#F3F3F8` | 5.98 |
| SyntaxKeyword | dark/code | `#FF7AB2` | `#17171C` | 7.38 |
| SyntaxType | light/code | `#0E6B78` | `#F3F3F8` | 5.60 |
| SyntaxType | dark/code | `#5DD8C8` | `#17171C` | 10.31 |
| SyntaxString | light/code | `#B3261E` | `#F3F3F8` | 5.91 |
| SyntaxString | dark/code | `#FF8170` | `#17171C` | 7.34 |
| SyntaxNumber | light/code | `#2F38C4` | `#F3F3F8` | 7.64 |
| SyntaxNumber | dark/code | `#D9C97C` | `#17171C` | 10.71 |
| SyntaxComment | light/code | `#5D6B78` | `#F3F3F8` | 4.94 |
| SyntaxComment | dark/code | `#8B99A6` | `#17171C` | 6.13 |
| SyntaxFunction | light/code | `#356B2E` | `#F3F3F8` | 5.76 |
| SyntaxFunction | dark/code | `#8FD07A` | `#17171C` | 9.76 |
| SyntaxAttribute | light/code | `#8A4A00` | `#F3F3F8` | 6.20 |
| SyntaxAttribute | dark/code | `#FFA14F` | `#17171C` | 8.90 |
