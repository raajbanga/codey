import SwiftUI

// One overlay layer per presentation (§3b, Nov 15): the app draws its own
// dropdowns and dialogs instead of the system's glass menus,
// popovers, action sheets and alerts. Only the tab bar is system-drawn. Menus and dialogs are plain data (title, icon, role, action),
// so another platform can render the same lists its own way.

/// A row in a dropdown.
struct CodeyMenuItem: Identifiable {
    let id = UUID()
    let title: String
    var systemImage: String?
    var isDestructive = false
    /// Shows a checkmark: the current value of a picker.
    var isSelected = false
    var isDisabled = false
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, isDestructive: Bool = false, isSelected: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isDestructive = isDestructive
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.action = action
    }

    /// A picker's rows: one per option, the current one checked.
    static func choices<Value: Equatable>(
        _ options: [Value],
        selection: Binding<Value>,
        title: (Value) -> String,
        systemImage: (Value) -> String? = { _ in nil }
    ) -> [CodeyMenuItem] {
        options.map { option in
            CodeyMenuItem(title(option), systemImage: systemImage(option), isSelected: option == selection.wrappedValue) {
                selection.wrappedValue = option
            }
        }
    }
}

/// Lets a menu list its rows like a ViewBuilder (with `if` and `for`).
@resultBuilder
enum CodeyMenuBuilder {
    static func buildExpression(_ item: CodeyMenuItem) -> [CodeyMenuItem] { [item] }
    static func buildExpression(_ items: [CodeyMenuItem]) -> [CodeyMenuItem] { items }
    static func buildBlock(_ parts: [CodeyMenuItem]...) -> [CodeyMenuItem] { parts.flatMap { $0 } }
    static func buildOptional(_ part: [CodeyMenuItem]?) -> [CodeyMenuItem] { part ?? [] }
    static func buildEither(first: [CodeyMenuItem]) -> [CodeyMenuItem] { first }
    static func buildEither(second: [CodeyMenuItem]) -> [CodeyMenuItem] { second }
    static func buildArray(_ parts: [[CodeyMenuItem]]) -> [CodeyMenuItem] { parts.flatMap { $0 } }
}

/// A confirmation or error: a title, a message, its actions, and Cancel.
struct CodeyDialog {
    struct Action {
        let title: String
        var isDestructive = false
        let action: () -> Void

        init(_ title: String, isDestructive: Bool = false, action: @escaping () -> Void) {
            self.title = title
            self.isDestructive = isDestructive
            self.action = action
        }
    }

    let title: String
    var message: String?
    var actions: [Action] = []
    var cancelTitle = "Cancel"
}

/// What the host is showing right now.
@MainActor @Observable
final class CodeyOverlay {
    fileprivate enum Content {
        case menu([CodeyMenuItem], anchor: CGRect)
        case dialog(CodeyDialog)
    }

    fileprivate private(set) var content: Content?
    /// New for each presentation, so the panel is measured afresh.
    fileprivate private(set) var token = UUID()
    private var onDismiss: (() -> Void)?

    func present(menu items: [CodeyMenuItem], from anchor: CGRect) {
        show(.menu(items, anchor: anchor))
    }

    func present(_ dialog: CodeyDialog, onDismiss: @escaping () -> Void = {}) {
        show(.dialog(dialog))
        self.onDismiss = onDismiss
    }

    /// Closes what's showing, after running the chosen action (which may
    /// read state the dismissal clears, or present something new).
    func dismiss(running action: (() -> Void)? = nil) {
        let done = onDismiss
        content = nil
        onDismiss = nil
        action?()
        done?()
    }

    private func show(_ new: Content) {
        dismiss()
        token = UUID()
        content = new
    }
}

extension View {
    /// The overlay layer for one presentation: the app root, and the root
    /// of every sheet or full-screen cover (each draws above the last).
    func codeyOverlayHost() -> some View {
        modifier(OverlayHost())
    }

    /// A confirmation drawn by the overlay host (replaces the system's
    /// confirmationDialog). Cancel is always added.
    func codeyConfirm(
        _ title: @autoclosure @escaping () -> String,
        isPresented: Binding<Bool>,
        message: @autoclosure @escaping () -> String? = nil,
        cancelTitle: String = "Cancel",
        actions: @escaping () -> [CodeyDialog.Action]
    ) -> some View {
        modifier(DialogPresenter(isPresented: isPresented) {
            CodeyDialog(title: title(), message: message(), actions: actions(), cancelTitle: cancelTitle)
        })
    }

    /// "Something Went Wrong" with an OK button while `message` is set.
    func errorAlert(_ message: Binding<String?>) -> some View {
        modifier(DialogPresenter(isPresented: message.isPresent()) {
            CodeyDialog(title: "Something Went Wrong", message: message.wrappedValue, cancelTitle: "OK")
        })
    }
}

private struct DialogPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let dialog: () -> CodeyDialog
    @Environment(CodeyOverlay.self) private var overlay: CodeyOverlay?

    func body(content: Content) -> some View {
        content.onChange(of: isPresented, initial: true) { _, shown in
            guard shown else { return }
            assert(overlay != nil, "A dialog needs .codeyOverlayHost() on its presentation")
            overlay?.present(dialog()) { isPresented = false }
        }
    }
}

private struct OverlayHost: ViewModifier {
    @State private var overlay = CodeyOverlay()

    func body(content: Content) -> some View {
        content
            .environment(overlay)
            .overlay { OverlayLayer(overlay: overlay) }
            // Sheets and covers don't inherit the app root's setting, and
            // every one of them has a host: no scroll bars anywhere.
            .scrollIndicators(.hidden)
    }
}

// MARK: - Drawing

private struct OverlayLayer: View {
    let overlay: CodeyOverlay
    /// The open panel's size, keyed by presentation; hidden until measured
    /// so it never flashes in the wrong place.
    @State private var measured: (token: UUID, size: CGSize)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var panelSize: CGSize? {
        measured?.token == overlay.token ? measured?.size : nil
    }

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            ZStack(alignment: .topLeading) {
                switch overlay.content {
                case let .menu(items, anchor):
                    backdrop(dim: false)
                    anchored(at: anchor, origin: origin, in: proxy.size) {
                        MenuPanel(items: items) { item in overlay.dismiss(running: item.action) }
                            .frame(width: 240)
                    }
                case let .dialog(dialog):
                    backdrop(dim: true)
                    DialogCard(dialog: dialog) { action in overlay.dismiss(running: action) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.96)))
                case nil:
                    EmptyView()
                }
            }
        }
        .ignoresSafeArea()
        // Closed, the layer must not swallow touches (the tab bar below is
        // UIKit and would never see them).
        .allowsHitTesting(overlay.content != nil)
        .animation(CodeyMotion.resolve(CodeyMotion.snappy, reduceMotion: reduceMotion), value: overlay.token)
        .animation(CodeyMotion.resolve(CodeyMotion.snappy, reduceMotion: reduceMotion), value: overlay.content == nil)
    }

    /// Tap outside (or VoiceOver's escape gesture) closes it.
    private func backdrop(dim: Bool) -> some View {
        (dim ? Color.black.opacity(0.28) : Color.clear)
            .contentShape(.rect)
            .onTapGesture { overlay.dismiss() }
            .accessibilityHidden(true)
            .transition(.opacity)
    }

    private func anchored(at anchor: CGRect, origin: CGPoint, in size: CGSize, @ViewBuilder panel: () -> some View) -> some View {
        let token = overlay.token
        return panel()
            .onGeometryChange(for: CGSize.self, of: \.size) { measured = (token, $0) }
            .offset(position(of: anchor.offsetBy(dx: -origin.x, dy: -origin.y), in: size))
            .opacity(panelSize == nil ? 0 : 1)
            .accessibilityAction(.escape) { overlay.dismiss() }
            .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.94, anchor: .top)))
    }

    /// Under the trigger, lined up with its nearer edge; above it when the
    /// panel would run off the bottom.
    private func position(of anchor: CGRect, in size: CGSize) -> CGSize {
        let panel = panelSize ?? .zero
        let margin = CodeySpacing.md
        let leading = anchor.midX < size.width / 2 ? anchor.minX : anchor.maxX - panel.width
        let x = min(max(leading, margin), size.width - margin - panel.width)
        let below = anchor.maxY + CodeySpacing.xs
        let fitsBelow = below + panel.height < size.height - margin * 2
        let y = fitsBelow ? below : max(margin * 3, anchor.minY - CodeySpacing.xs - panel.height)
        return CGSize(width: x, height: y)
    }
}

private struct MenuPanel: View {
    let items: [CodeyMenuItem]
    let choose: (CodeyMenuItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                if item.id != items.first?.id {
                    HairlineDivider()
                }
                Button { choose(item) } label: {
                    HStack(spacing: CodeySpacing.sm) {
                        if let systemImage = item.systemImage {
                            Icon(systemImage, size: 17, relativeTo: .body)
                                .frame(width: 24)
                        }
                        Text(item.title)
                            .font(.codeyBody)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        if item.isSelected {
                            Icon("checkmark", size: 15, relativeTo: .body)
                        }
                    }
                    .foregroundStyle(item.isDestructive ? CodeyColor.danger : CodeyColor.textPrimary)
                    .padding(.horizontal, CodeySpacing.md)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(item.isDisabled)
                .opacity(item.isDisabled ? 0.4 : 1)
                .accessibilityAddTraits(item.isSelected ? .isSelected : [])
            }
        }
        .codeyNote()
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

private struct DialogCard: View {
    private static let danger = CodeyColor.TopicHue(ink: CodeyColor.danger, soft: CodeyColor.Soft.danger, fill: CodeyColor.danger)

    let dialog: CodeyDialog
    /// nil: Cancel.
    let finish: ((() -> Void)?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.md) {
            Text(dialog.title)
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let message = dialog.message {
                Text(message)
                    .font(.codeyCallout)
                    .foregroundStyle(CodeyColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: CodeySpacing.sm) {
                ForEach(dialog.actions.indices, id: \.self) { index in
                    let action = dialog.actions[index]
                    // Solid red, so the risky choice never reads like Cancel.
                    CodeyButton(action.title, kind: action.isDestructive ? .hue(Self.danger) : .primary, fullWidth: true) {
                        finish(action.action)
                    }
                }
                CodeyButton(dialog.cancelTitle, kind: .secondary, fullWidth: true) { finish(nil) }
                    .accessibilityIdentifier("dialog.cancel")
            }
            .padding(.top, CodeySpacing.xs)
        }
        .codeyPanelPadding()
        .frame(maxWidth: 360)
        // The same lifted card as FloatingPanel and celebrations.
        .codeyFloatingCard()
        .padding(CodeySpacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { finish(nil) }
    }
}
