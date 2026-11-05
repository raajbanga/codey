# Codey Design System

Tokens and components for every screen. Screens use these. They never use raw
`Color(...)`, hex values, literal corner radii, or raw system fonts.
`scripts/check-design-tokens.sh` enforces that.

## Layout (`codey/Sources/DesignSystem/`)

| Folder | What |
|---|---|
| `Tokens/` | `CodeyColor`, `CodeyRadius`, `CodeySpacing`, type (`Font.codey*`), `CodeyMotion`, `TierStyle`, `SyntaxRole` |
| `Components/` | `CodeyCard`, `CodeyButton`, `CodeyChip`, `AnswerOptionRow`, `ProgressBar`, `ProgressRing`, `StatTile` + `StatTileRow`, `TierChipRow` + `TierUnlockedBanner`, `EmptyStateView`, `CelebrationOverlay`, `XPGainLabel`, `IconTile`, `CloseButton`, `AppGlyph`, `MasteryDots`, and `FormFeedback` (`FieldErrorLabel`, `LimitCounter`, `.errorBorder`, `.errorAlert` + `Binding.attempt`) |
| `Markdown/` | `CardMarkdownView` (the **only** `import Textual`), `CardMarkdownComposition`, `MarkdownTextEditor`, `MarkdownFormatting` |
| `CodeEditor/` | `CodeEditorView` + `CodeyRunestoneTheme` (the **only** Runestone/TreeSitter imports) |
| `Gallery/` | `ComponentGallery` previews (DEBUG builds only): light, dark, AX3, XS |

## Rules

- **Look ("pastel ink", notes on paper)**: content sits on rounded notes (`.codeyNote()`: raised fill, hairline edge, a barely-there lift) laid on warm dotted paper (`.codeyPaperBackground()`). A desaturated ink-blue accent and pastel fills. One `.primary` button per screen.
- **Type**: headings and numbers in SF Rounded (`codeyDisplay`, `codeyTitle`, `codeyHeadline`, `codeyNumeric*`, and system navigation titles via `CodeyNavigationTitles`); reading text in SF Pro. Nothing smaller than footnote: `codeyCaption` is footnote, and secondary lines under a title use `codeySubheadline`. Flashcard and quiz prompts/answers use `codeyCardText` (title3) via `CardMarkdownView(font:)`.
- **Glass is the system's only**: tab bar, toolbars, and sheets get Liquid Glass from iOS. Our own buttons, toasts, and overlays are flat (`CodeyFillButtonStyle`, `.codeyFloatingSurface()`). Content cards are `.codeyNote()` surfaces; the only shadow is the note's faint lift.
- **Corners**: use `Capsule` only for single-line, fixed-height controls (`CodeyChip`, `ProgressBar`, single-line `CodeyButton`). Anything that can wrap uses `.codey(CodeyRadius.md)`. Cards use `lg`. Nested surfaces use `ConcentricRectangle` or container-relative shapes (`.containerShape`).
- **Color is never the only signal**: tiers carry a symbol and a label (`TierStyle`), and answer states carry an icon and a VoiceOver value.
- **Motion**: use `.codeyAnimation` / `withCodeyAnimation`. Under Reduce Motion both fall back to a short crossfade. Quiet only: snaps and smooth settles, no bounce, no particles. Level-ups and unlocks use `CelebrationOverlay`, a fading banner plus a haptic.
- **Haptics**: use `.sensoryFeedback`, not UIKit feedback generators.
- **brand vs brandFill**: `brand` is ink for text, icons, and tint. `brandFill` is the pastel button fill, always labeled with `onBrandFill` (never white). `brandSoft` sits behind brand text.
- **Pastel pairs**: every status/tier color has a `…Soft` fill (`CodeyColor.Soft`, or `CodeyChipVariant.softColor`). Put a color's text only on its own soft fill or on the surfaces.
- **Backgrounds**: every page uses `.codeyPaperBackground()` (Increase Contrast hides the dots); `.codeyListBackground()` does the same for a `List`. The dots use `paperDot`, which never carries text.

## Contrast (NFR-12)

The palette lives in `scripts/palette/palette.py`. To change a color, edit it
there and run:

```sh
python3 scripts/palette/palette.py                                   # must print FAILS 0
python3 scripts/palette/gen_colors.py codey/Resources/Assets.xcassets   # regenerates the colorsets
```

Every color, neutrals included, is a custom asset (light, dark, and
Increase Contrast variants for text and separators). The table is
`palette.py`'s output: each text color on the paper `Surface`, on
`SurfaceRaised`, and on its own pastel `…Soft` fill; `OnBrandFill` on
`BrandFill`; syntax colors on `CodeBackground`. `ContrastTests` re-checks the
shipped assets.

| Token | Pair | Foreground | Background | Ratio |
|---|---|---|---|---|
| TextPrimary | light/surface | `#1B1C1E` | `#F6F5F2` | 15.64 |
| TextPrimary | light/raised | `#1B1C1E` | `#FFFFFF` | 17.05 |
| TextSecondary | light/surface | `#5C5B57` | `#F6F5F2` | 6.24 |
| TextSecondary | light/raised | `#5C5B57` | `#FFFFFF` | 6.80 |
| Brand | light/surface | `#3A5578` | `#F6F5F2` | 7.00 |
| Brand | light/raised | `#3A5578` | `#FFFFFF` | 7.63 |
| Brand | light/own-soft | `#3A5578` | `#E8EEF5` | 6.54 |
| Success | light/surface | `#2F5A3B` | `#F6F5F2` | 7.28 |
| Success | light/raised | `#2F5A3B` | `#FFFFFF` | 7.94 |
| Success | light/own-soft | `#2F5A3B` | `#DDEBDF` | 6.43 |
| Warning | light/surface | `#6B4C10` | `#F6F5F2` | 7.22 |
| Warning | light/raised | `#6B4C10` | `#FFFFFF` | 7.88 |
| Warning | light/own-soft | `#6B4C10` | `#F3E6CC` | 6.38 |
| Danger | light/surface | `#8E2F28` | `#F6F5F2` | 7.44 |
| Danger | light/raised | `#8E2F28` | `#FFFFFF` | 8.12 |
| Danger | light/own-soft | `#8E2F28` | `#F6DEDB` | 6.33 |
| TierEasy | light/surface | `#2F5A3B` | `#F6F5F2` | 7.28 |
| TierEasy | light/raised | `#2F5A3B` | `#FFFFFF` | 7.94 |
| TierEasy | light/own-soft | `#2F5A3B` | `#DDEBDF` | 6.43 |
| TierMedium | light/surface | `#6B4C10` | `#F6F5F2` | 7.22 |
| TierMedium | light/raised | `#6B4C10` | `#FFFFFF` | 7.88 |
| TierMedium | light/own-soft | `#6B4C10` | `#F3E6CC` | 6.38 |
| TierHard | light/surface | `#7A3045` | `#F6F5F2` | 8.24 |
| TierHard | light/raised | `#7A3045` | `#FFFFFF` | 8.99 |
| TierHard | light/own-soft | `#7A3045` | `#F2DDE3` | 6.95 |
| Brand | light/brand-soft | `#3A5578` | `#E8EEF5` | 6.54 |
| TextPrimary | light/brand-soft | `#1B1C1E` | `#E8EEF5` | 14.60 |
| OnBrandFill | light/brand-fill | `#1F3350` | `#CFDCEB` | 9.16 |
| SyntaxPlain | light/code | `#1B1C1E` | `#F3F2EE` | 15.22 |
| SyntaxKeyword | light/code | `#7A3466` | `#F3F2EE` | 7.47 |
| SyntaxType | light/code | `#2F5F6B` | `#F3F2EE` | 6.31 |
| SyntaxString | light/code | `#8A4B1F` | `#F3F2EE` | 6.03 |
| SyntaxNumber | light/code | `#3A5578` | `#F3F2EE` | 6.82 |
| SyntaxComment | light/code | `#66655F` | `#F3F2EE` | 5.22 |
| SyntaxFunction | light/code | `#3F6A4B` | `#F3F2EE` | 5.56 |
| SyntaxAttribute | light/code | `#6E5214` | `#F3F2EE` | 6.51 |
| TextPrimary | dark/surface | `#ECEBE7` | `#141518` | 15.30 |
| TextPrimary | dark/raised | `#ECEBE7` | `#1D1F23` | 13.83 |
| TextSecondary | dark/surface | `#A3A29D` | `#141518` | 7.14 |
| TextSecondary | dark/raised | `#A3A29D` | `#1D1F23` | 6.45 |
| Brand | dark/surface | `#A9C0DD` | `#141518` | 9.80 |
| Brand | dark/raised | `#A9C0DD` | `#1D1F23` | 8.86 |
| Brand | dark/own-soft | `#A9C0DD` | `#222B37` | 7.67 |
| Success | dark/surface | `#A9D1B3` | `#141518` | 10.83 |
| Success | dark/raised | `#A9D1B3` | `#1D1F23` | 9.79 |
| Success | dark/own-soft | `#A9D1B3` | `#23322A` | 7.98 |
| Warning | dark/surface | `#E6C98E` | `#141518` | 11.40 |
| Warning | dark/raised | `#E6C98E` | `#1D1F23` | 10.30 |
| Warning | dark/own-soft | `#E6C98E` | `#372F20` | 8.25 |
| Danger | dark/surface | `#F0A79E` | `#141518` | 9.33 |
| Danger | dark/raised | `#F0A79E` | `#1D1F23` | 8.43 |
| Danger | dark/own-soft | `#F0A79E` | `#3A2422` | 7.37 |
| TierEasy | dark/surface | `#A9D1B3` | `#141518` | 10.83 |
| TierEasy | dark/raised | `#A9D1B3` | `#1D1F23` | 9.79 |
| TierEasy | dark/own-soft | `#A9D1B3` | `#23322A` | 7.98 |
| TierMedium | dark/surface | `#E6C98E` | `#141518` | 11.40 |
| TierMedium | dark/raised | `#E6C98E` | `#1D1F23` | 10.30 |
| TierMedium | dark/own-soft | `#E6C98E` | `#372F20` | 8.25 |
| TierHard | dark/surface | `#EBB1BF` | `#141518` | 10.06 |
| TierHard | dark/raised | `#EBB1BF` | `#1D1F23` | 9.10 |
| TierHard | dark/own-soft | `#EBB1BF` | `#3A252C` | 7.82 |
| Brand | dark/brand-soft | `#A9C0DD` | `#222B37` | 7.67 |
| TextPrimary | dark/brand-soft | `#ECEBE7` | `#222B37` | 11.99 |
| OnBrandFill | dark/brand-fill | `#DCE7F4` | `#2E415A` | 8.31 |
| SyntaxPlain | dark/code | `#E4E3DF` | `#191A1D` | 13.55 |
| SyntaxKeyword | dark/code | `#E3A6CF` | `#191A1D` | 8.80 |
| SyntaxType | dark/code | `#8FC6CF` | `#191A1D` | 9.24 |
| SyntaxString | dark/code | `#E6B48A` | `#191A1D` | 9.33 |
| SyntaxNumber | dark/code | `#A9C0DD` | `#191A1D` | 9.34 |
| SyntaxComment | dark/code | `#8E8D88` | `#191A1D` | 5.23 |
| SyntaxFunction | dark/code | `#A9D1B3` | `#191A1D` | 10.32 |
| SyntaxAttribute | dark/code | `#E6C98E` | `#191A1D` | 10.86 |
