# Codey Design System

Tokens and components for every screen. Screens use these. They never use raw
`Color(...)`, hex values, literal corner radii, or raw system fonts.
`scripts/check-design-tokens.sh` enforces that.

## Layout (`codey/Sources/DesignSystem/`)

| Folder | What |
|---|---|
| `Tokens/` | `CodeyColor`, `CodeyRadius`, `CodeySpacing`, type (`Font.codey*`), `CodeyMotion`, `TierStyle`, `SyntaxRole` |
| `Components/` | `FloatingPanel` (`.floatingPanel(item:)`, `\.dismissPanel`), `BentoSection` + `BentoGrid` + `BentoTile` + `PageHeader` + `SectionTitle`, `Icon` (+ `CodeyIcon`, `Label(_:icon:)`), `CircleIconButton` (+ `CloseButton`, `AskAIButton`), `ChatBubble` + `TypingIndicator`, `CodeyCard`, `CodeyButton`, `CodeyChip`, `AnswerOptionRow`, `ProgressBar`, `ProgressRing`, `StatTile` + `StatTileRow`, `TierLockNote` (in `TierChipRow.swift`), `SessionSummary` + `SummaryBanner` + `ResultBanner` + `LabeledCodeBlock` (in `Session.swift`), `EmptyStateView`, `CelebrationOverlay`, `XPGainLabel`, `IconTile`, `CloseButton`, `AppGlyph`, `MasteryDots`, and `FormFeedback` (`FieldErrorLabel`, `LimitCounter`, `.errorBorder`, `.errorAlert` + `Binding.attempt`) |
| `Markdown/` | `CardMarkdownView` (the **only** `import Textual`), `CardMarkdownComposition`, `MarkdownTextEditor`, `MarkdownFormatting` |
| `CodeEditor/` | `CodeEditorView` + `CodeyRunestoneTheme` (the **only** Runestone/TreeSitter imports) |
| `Gallery/` | `ComponentGallery` previews (DEBUG builds only): light, dark, AX3, XS |

## Rules

- **Look ("pastel ink", notes on paper)**: content sits on rounded notes (`.codeyNote()`: raised fill, hairline edge, a barely-there lift) laid on warm dotted paper (`.codeyPaperBackground()`). A desaturated ink-blue accent and pastel fills. One `.primary` button per screen.
- **Type**: headings and numbers in SF Rounded (`codeyDisplay`, `codeyTitle`, `codeyHeadline`, `codeyNumeric*`, and system navigation titles via `CodeyNavigationTitles`); reading text in SF Pro. Nothing smaller than footnote: `codeyCaption` is footnote, and secondary lines under a title use `codeySubheadline`. Flashcard and quiz prompts/answers use `codeyCardText` (title3) via `CardMarkdownView(font:)`.
- **Lists are bento tiles** (S40): Home's plan, challenge, groups and topics, the Quiz topics, the exercises and the deck library are `BentoTile`s in a two-column `BentoSection`/`BentoGrid` (tiles in a row share its height; a last odd tile spans the row and lays out sideways; one column at accessibility text sizes). Use `CodeyCard` only for things that are not a list (a summary, a form).
- **Line icons** (S40): `Icon(name)` / `CodeyIcon.image(name)` draw our own 24 pt, 2 pt-stroke icons (`scripts/icons/icons.py` writes the SVG assets and the `IconTable.swift` lookup). Names are the SF Symbol names the app already stores, so data doesn't change; an unmapped name falls back to SF Symbols. Add an icon by drawing it in `icons.py`, never by importing an icon pack.
- **Floating panels** (S40): small tasks that keep the page in view (quiz setup, Ask AI) open with `.floatingPanel(item:)`: a dotted-paper card (`.codeyFloatingCard()`) centered over a dimmed page, with a margin on every side. It closes by a swipe in any direction, a tap outside, or VoiceOver escape (quiz setup has no ✕; a panel may still add a `CloseButton` via `@Environment(\.dismissPanel)`). Every floating card (panels, dialogs, celebrations) insets its content with `.codeyPanelPadding()` (16 pt sides, 24 pt top and bottom). Its shadow is the one deep shadow in the app, because the note is off the page. Editing flows (deck builder, profile) stay system sheets.
- **One floating motion** (S40): everything that floats over the page (panels, `CelebrationOverlay`, the level toast, undo bars) appears and leaves with `CodeyMotion.popTransition` (96% scale plus fade, fade only under Reduce Motion) driven by `CodeyMotion.pop`. Centered cards use `.codeyFloatingCard()`; small toasts and bars use `.codeyFloatingSurface()`. Don't add slide-ins or bespoke offsets.
- **Icon-only buttons** are `CircleIconButton` (44 pt): `.neutral` to close, `.soft` for Ask AI, `.filled` for play and send.
- **The tab bar is the only system-drawn control** (§3b, Nov 15): no navigation bars, back buttons, toolbar buttons, system menus, popovers, action sheets or alerts. Everything else is drawn by us, as plain data so another platform can render the same thing: `CodeyMenu(trigger) { CodeyMenuItem(...) }` for every dropdown (`.value` tag for pickers, `.icon` round button for actions; `CodeyMenuItem.choices` for pickers), and `.codeyConfirm(...)` / `.errorAlert(...)` for dialogs. They draw in the presentation's `.codeyOverlayHost()` layer (the app root and every sheet/cover root). Our buttons, toasts and overlays are flat (`CodeyFillButtonStyle`, `.codeyFloatingSurface()`); content cards are `CodeyCard` / `.codeyCard()` (a padded `.codeyNote()`), one-line fields `.codeyField()`, lines `HairlineDivider`. The soft edge where content scrolls under the screen's top or bottom (or a `codeyBar`) is `EdgeFade`: our own backdrop blur under one smooth gradient, short at the top and long at the bottom, with the system scroll edge effect off.
- **Pages** (`CodeyPage`): a row of round buttons only (✕ leading on sheets, actions trailing, Play's streak leading), then the page's `HeroCard` (icon with a short line beside it, or the title beside it when there is no line; badge; title; optional progress + caption; in the page's pastel), then content. Pushed pages go back with the edge swipe (and VoiceOver's escape); there is no back button.
- **Choices** (`ChoiceChips`): full button height, at most three in a row; four or more go two to a row. A tier picker shows locked tiers as one `TierLockNote` line, not a row of tier tags.
- **Tiles** (`GameTile`): icon and one status tag (what it pays, or its state) on top, then the title, then one row of fact tags pinned above the progress bar and the action, so a row of tiles lines up. Tags are 32 pt tall, the same as a compact round button (⋯).
- **Corners**: controls (buttons, `ChoiceChips`, tile actions, search) use `.pill` (16 pt); tags (`CodeyChip`, XP badges) use `.tag` (12 pt, the roundest-looking since tags are short). `Capsule` only for `ProgressBar` and the onboarding dots. Anything else that can wrap uses `.codey(CodeyRadius.md)`. Cards use `lg`. Nested surfaces use `ConcentricRectangle` or container-relative shapes (`.containerShape`).
- **Color is never the only signal**: tiers carry a symbol and a label (`TierStyle`), and answer states carry an icon and a VoiceOver value.
- **Motion**: use `.codeyAnimation` / `withCodeyAnimation` (and `.trackKeyboard($isUp)` to follow the keyboard). Under Reduce Motion both fall back to a short crossfade. Quiet only: snaps and smooth settles, no bounce, no particles. Level-ups and unlocks use `CelebrationOverlay`, a fading banner plus a haptic.
- **Haptics**: use `.sensoryFeedback`, not UIKit feedback generators.
- **brand vs brandFill**: `brand` is ink for text, icons, and tint. `brandFill` is the pastel button fill, always labeled with `onBrandFill` (never white). `brandSoft` sits behind brand text.
- **Pastel pairs**: every status/tier color has a `…Soft` fill (`CodeyColor.Soft`, or `CodeyChipVariant.softColor`). Put a color's text only on its own soft fill or on the surfaces.
- **Backgrounds**: every page uses `.codeyPaperBackground()` (Increase Contrast hides the dots); no page uses a system `List` or `Form` any more. The dots use `paperDot` (2.4 pt on a 20 pt grid; 1.58:1 light, 1.68:1 dark against `surface`, S40), which never carries text.

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
`BrandFill`; XP and topic inks on their own `…Soft` tile; white labels on the
topic `…Fill`s; syntax colors on `CodeBackground`. The neutrals, brand, XP and
topic hues come from the Radix scales in `radix_scales.json` (the `P.update`
block in `palette.py` overrides the older hand-picked hexes above it).
`ContrastTests` re-checks the shipped assets.

| Token | Pair | Foreground | Background | Ratio |
|---|---|---|---|---|
| TextPrimary | light/surface | `#21201C` | `#EFEFEE` | 14.17 |
| TextPrimary | light/raised | `#21201C` | `#FFFFFF` | 16.30 |
| TextSecondary | light/surface | `#53524D` | `#EFEFEE` | 6.81 |
| TextSecondary | light/raised | `#53524D` | `#FFFFFF` | 7.83 |
| Brand | light/surface | `#46546B` | `#EFEFEE` | 6.66 |
| Brand | light/raised | `#46546B` | `#FFFFFF` | 7.66 |
| Brand | light/own-soft | `#46546B` | `#D2D8E2` | 5.35 |
| Success | light/surface | `#355625` | `#EFEFEE` | 7.27 |
| Success | light/raised | `#355625` | `#FFFFFF` | 8.37 |
| Success | light/own-soft | `#355625` | `#E3ECDF` | 6.91 |
| Warning | light/surface | `#564425` | `#EFEFEE` | 8.11 |
| Warning | light/raised | `#564425` | `#FFFFFF` | 9.34 |
| Warning | light/own-soft | `#564425` | `#ECE7DF` | 7.59 |
| Danger | light/surface | `#562625` | `#EFEFEE` | 10.74 |
| Danger | light/raised | `#562625` | `#FFFFFF` | 12.36 |
| Danger | light/own-soft | `#562625` | `#ECDFDF` | 9.52 |
| TierEasy | light/surface | `#355625` | `#EFEFEE` | 7.27 |
| TierEasy | light/raised | `#355625` | `#FFFFFF` | 8.37 |
| TierEasy | light/own-soft | `#355625` | `#E3ECDF` | 6.91 |
| TierMedium | light/surface | `#564425` | `#EFEFEE` | 8.11 |
| TierMedium | light/raised | `#564425` | `#FFFFFF` | 9.34 |
| TierMedium | light/own-soft | `#564425` | `#ECE7DF` | 7.59 |
| TierHard | light/surface | `#562535` | `#EFEFEE` | 10.66 |
| TierHard | light/raised | `#562535` | `#FFFFFF` | 12.27 |
| TierHard | light/own-soft | `#562535` | `#ECDFE3` | 9.48 |
| XP | light/own-soft | `#3B3529` | `#DED4C4` | 8.29 |
| TopicTeal | light/own-soft | `#1F3732` | `#C5DED8` | 8.97 |
| TopicSand | light/own-soft | `#373229` | `#DCD5C8` | 8.72 |
| TopicSlate | light/own-soft | `#1A222F` | `#D2D8E2` | 11.16 |
| TopicCoral | light/own-soft | `#3B2F2C` | `#E3D2CD` | 8.82 |
| TopicSky | light/own-soft | `#172733` | `#CED9E2` | 10.66 |
| TopicRose | light/own-soft | `#362429` | `#E5D0D6` | 9.94 |
| TopicOlive | light/own-soft | `#373F28` | `#D0DEBB` | 7.80 |
| TopicGold | light/own-soft | `#332F1E` | `#E2DCC6` | 9.76 |
| TopicGreen | light/own-soft | `#1E3320` | `#C6E2C8` | 9.75 |
| TopicIndigo | light/own-soft | `#1E1E33` | `#C6C6E2` | 9.76 |
| TopicViolet | light/own-soft | `#2A1E33` | `#D5C6E2` | 9.76 |
| TopicPlum | light/own-soft | `#331E32` | `#E2C6DF` | 9.75 |
| Brand | light/brand-soft | `#46546B` | `#D2D8E2` | 5.35 |
| TextPrimary | light/brand-soft | `#21201C` | `#D2D8E2` | 11.38 |
| OnBrandFill | light/brand-fill | `#FFFFFF` | `#3B485E` | 9.23 |
| TopicTealFill | light/white-label | `#FFFFFF` | `#34685D` | 6.39 |
| TopicSandFill | light/white-label | `#FFFFFF` | `#685535` | 7.14 |
| TopicSlateFill | light/white-label | `#FFFFFF` | `#3B485E` | 9.23 |
| TopicCoralFill | light/white-label | `#FFFFFF` | `#664034` | 8.94 |
| TopicSkyFill | light/white-label | `#FFFFFF` | `#345067` | 8.44 |
| TopicRoseFill | light/white-label | `#FFFFFF` | `#653344` | 9.95 |
| TopicOliveFill | light/white-label | `#FFFFFF` | `#576835` | 6.11 |
| TopicGoldFill | light/white-label | `#FFFFFF` | `#6A5F34` | 6.36 |
| TopicGreenFill | light/white-label | `#FFFFFF` | `#346A39` | 6.43 |
| TopicIndigoFill | light/white-label | `#FFFFFF` | `#44447E` | 8.85 |
| TopicVioletFill | light/white-label | `#FFFFFF` | `#60427B` | 8.19 |
| TopicPlumFill | light/white-label | `#FFFFFF` | `#743E70` | 7.88 |
| SyntaxPlain | light/code | `#1B1C1E` | `#EAEAE9` | 14.17 |
| SyntaxKeyword | light/code | `#7A3466` | `#EAEAE9` | 6.95 |
| SyntaxType | light/code | `#2F5F6B` | `#EAEAE9` | 5.87 |
| SyntaxString | light/code | `#8A4B1F` | `#EAEAE9` | 5.61 |
| SyntaxNumber | light/code | `#3A5578` | `#EAEAE9` | 6.34 |
| SyntaxComment | light/code | `#66655F` | `#EAEAE9` | 4.86 |
| SyntaxFunction | light/code | `#3F6A4B` | `#EAEAE9` | 5.17 |
| SyntaxAttribute | light/code | `#6E5214` | `#EAEAE9` | 6.06 |
| TextPrimary | dark/surface | `#F1EEE4` | `#1B1B1A` | 14.85 |
| TextPrimary | dark/raised | `#F1EEE4` | `#2B2A29` | 12.34 |
| TextSecondary | dark/surface | `#B7B4AB` | `#1B1B1A` | 8.31 |
| TextSecondary | dark/raised | `#B7B4AB` | `#2B2A29` | 6.91 |
| Brand | dark/surface | `#A8B7D1` | `#1B1B1A` | 8.50 |
| Brand | dark/raised | `#A8B7D1` | `#2B2A29` | 7.07 |
| Brand | dark/own-soft | `#A8B7D1` | `#2A3342` | 6.28 |
| Success | dark/surface | `#C1D9B5` | `#1B1B1A` | 11.38 |
| Success | dark/raised | `#C1D9B5` | `#2B2A29` | 9.45 |
| Success | dark/own-soft | `#C1D9B5` | `#2E3928` | 8.00 |
| Warning | dark/surface | `#D9CCB5` | `#1B1B1A` | 10.88 |
| Warning | dark/raised | `#D9CCB5` | `#2B2A29` | 9.04 |
| Warning | dark/own-soft | `#D9CCB5` | `#393328` | 7.90 |
| Danger | dark/surface | `#D9B6B5` | `#1B1B1A` | 9.28 |
| Danger | dark/raised | `#D9B6B5` | `#2B2A29` | 7.71 |
| Danger | dark/own-soft | `#D9B6B5` | `#392828` | 7.50 |
| TierEasy | dark/surface | `#C1D9B5` | `#1B1B1A` | 11.38 |
| TierEasy | dark/raised | `#C1D9B5` | `#2B2A29` | 9.45 |
| TierEasy | dark/own-soft | `#C1D9B5` | `#2E3928` | 8.00 |
| TierMedium | dark/surface | `#D9CCB5` | `#1B1B1A` | 10.88 |
| TierMedium | dark/raised | `#D9CCB5` | `#2B2A29` | 9.04 |
| TierMedium | dark/own-soft | `#D9CCB5` | `#393328` | 7.90 |
| TierHard | dark/surface | `#D9B5C1` | `#1B1B1A` | 9.30 |
| TierHard | dark/raised | `#D9B5C1` | `#2B2A29` | 7.73 |
| TierHard | dark/own-soft | `#D9B5C1` | `#39282E` | 7.47 |
| XP | dark/own-soft | `#3B3529` | `#DED4C4` | 8.29 |
| TopicTeal | dark/own-soft | `#1F3732` | `#C5DED8` | 8.97 |
| TopicSand | dark/own-soft | `#373229` | `#DCD5C8` | 8.72 |
| TopicSlate | dark/own-soft | `#1A222F` | `#D2D8E2` | 11.16 |
| TopicCoral | dark/own-soft | `#3B2F2C` | `#E3D2CD` | 8.82 |
| TopicSky | dark/own-soft | `#172733` | `#CED9E2` | 10.66 |
| TopicRose | dark/own-soft | `#362429` | `#E5D0D6` | 9.94 |
| TopicOlive | dark/own-soft | `#373F28` | `#D0DEBB` | 7.80 |
| TopicGold | dark/own-soft | `#332F1E` | `#E2DCC6` | 9.76 |
| TopicGreen | dark/own-soft | `#1E3320` | `#C6E2C8` | 9.75 |
| TopicIndigo | dark/own-soft | `#1E1E33` | `#C6C6E2` | 9.76 |
| TopicViolet | dark/own-soft | `#2A1E33` | `#D5C6E2` | 9.76 |
| TopicPlum | dark/own-soft | `#331E32` | `#E2C6DF` | 9.75 |
| Brand | dark/brand-soft | `#A8B7D1` | `#2A3342` | 6.28 |
| TextPrimary | dark/brand-soft | `#F1EEE4` | `#2A3342` | 10.96 |
| OnBrandFill | dark/brand-fill | `#FFFFFF` | `#3B485E` | 9.23 |
| TopicTealFill | dark/white-label | `#FFFFFF` | `#34685D` | 6.39 |
| TopicSandFill | dark/white-label | `#FFFFFF` | `#685535` | 7.14 |
| TopicSlateFill | dark/white-label | `#FFFFFF` | `#3B485E` | 9.23 |
| TopicCoralFill | dark/white-label | `#FFFFFF` | `#664034` | 8.94 |
| TopicSkyFill | dark/white-label | `#FFFFFF` | `#345067` | 8.44 |
| TopicRoseFill | dark/white-label | `#FFFFFF` | `#653344` | 9.95 |
| TopicOliveFill | dark/white-label | `#FFFFFF` | `#576835` | 6.11 |
| TopicGoldFill | dark/white-label | `#FFFFFF` | `#6A5F34` | 6.36 |
| TopicGreenFill | dark/white-label | `#FFFFFF` | `#346A39` | 6.43 |
| TopicIndigoFill | dark/white-label | `#FFFFFF` | `#44447E` | 8.85 |
| TopicVioletFill | dark/white-label | `#FFFFFF` | `#60427B` | 8.19 |
| TopicPlumFill | dark/white-label | `#FFFFFF` | `#743E70` | 7.88 |
| SyntaxPlain | dark/code | `#E4E3DF` | `#232220` | 12.38 |
| SyntaxKeyword | dark/code | `#E3A6CF` | `#232220` | 8.04 |
| SyntaxType | dark/code | `#8FC6CF` | `#232220` | 8.44 |
| SyntaxString | dark/code | `#E6B48A` | `#232220` | 8.52 |
| SyntaxNumber | dark/code | `#A9C0DD` | `#232220` | 8.53 |
| SyntaxComment | dark/code | `#8E8D88` | `#232220` | 4.78 |
| SyntaxFunction | dark/code | `#A9D1B3` | `#232220` | 9.43 |
| SyntaxAttribute | dark/code | `#E6C98E` | `#232220` | 9.92 |
