import SwiftUI

/// Rows on a note (S40): the pattern Home used for its plan and groups
/// notes, shared by Home, the Quiz tab, and the exercise list so screens
/// don't each rebuild icon + title + subtitle + chevron.
///
///     This week's plan                ← SectionTitle
///     ╭ ◆ Networking          ›  ╮    ← NoteList: one note,
///     │ ◆ Databases           ›  │      ChevronRows divided by hairlines
///     ╰ ◆ Algorithms          ›  ╯

/// A titled NoteList.
struct NoteSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            SectionTitle(title)
            NoteList { content }
        }
    }
}

/// One note holding rows, with a hairline between each pair.
struct NoteList<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Divider().overlay(CodeyColor.separator) }
                    row
                }
            }
        }
        .padding(.horizontal, CodeySpacing.md)
        .codeyNote()
    }
}

/// A section heading above a note.
struct SectionTitle: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.codeyHeadline)
            .foregroundStyle(CodeyColor.textSecondary)
            .accessibilityAddTraits(.isHeader)
            .padding(.leading, CodeySpacing.xs)
    }
}

/// A row inside a note (NoteList): icon, title, subtitle (plus optional extra
/// content such as a progress bar), and a trailing chevron. The caller
/// wraps it in a Button or NavigationLink.
struct ChevronRow<Extra: View>: View {
    let systemImage: String
    var tint: Color = CodeyColor.brand
    let title: String
    let subtitle: String
    @ViewBuilder var extra: Extra

    var body: some View {
        // Icon and chevron sit on the title's line, also when extra content
        // (chips, a progress bar) makes the row taller.
        HStack(alignment: .firstTextBaseline, spacing: CodeySpacing.sm) {
            RowIcon(systemName: systemImage, tint: tint)
            VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                Text(title)
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.codeySubheadline)
                    .monospacedDigit()
                    .foregroundStyle(CodeyColor.textSecondary)
                extra
            }
            Spacer(minLength: 0)
            RowChevron()
        }
        .padding(.vertical, CodeySpacing.md)
        .contentShape(.rect)
    }
}

extension ChevronRow where Extra == EmptyView {
    init(systemImage: String, tint: Color = CodeyColor.brand, title: String, subtitle: String) {
        self.init(systemImage: systemImage, tint: tint, title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.codeyCallout.weight(.semibold))
            .foregroundStyle(CodeyColor.textSecondary)
            .accessibilityHidden(true)
    }
}

/// The leading symbol of a row, in a fixed-width column so titles line
/// up whatever the symbol's width (person.3 is much wider than f(x)).
struct RowIcon: View {
    let systemName: String
    var tint: Color = CodeyColor.brand

    @ScaledMetric(relativeTo: .callout) private var width: CGFloat = 32

    var body: some View {
        Image(systemName: systemName)
            .font(.codeyCallout)
            .foregroundStyle(tint)
            .frame(width: width)
            .accessibilityHidden(true)
    }
}
