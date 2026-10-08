import Runestone
import SwiftUI
import TreeSitterCPPRunestone
import TreeSitterJavaRunestone
import TreeSitterPythonRunestone
import TreeSitterSwiftRunestone
import UIKit

/// Code editor for card snippets (D1, UC-02): Runestone + tree-sitter. Line
/// numbers, auto-indent, bracket pairs, 4-space tabs, no autocorrect or smart
/// punctuation. Only this file and CodeyRunestoneTheme import Runestone (R12):
/// the fallback is a plain TextEditor with those traits off.
struct CodeEditorView: UIViewRepresentable {
    @Binding var text: String
    var language: CodeLanguage
    var isEditable = true

    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> TextView {
        let textView = TextView()
        textView.editorDelegate = context.coordinator
        textView.backgroundColor = UIColor(named: "CodeBackground")
        textView.showLineNumbers = true
        textView.lineSelectionDisplayType = .line
        textView.isLineWrappingEnabled = false
        textView.indentStrategy = .space(length: 4)
        textView.characterPairs = Self.characterPairs
        textView.characterPairTrailingComponentDeletionMode = .immediatelyFollowingLeadingComponent
        textView.gutterLeadingPadding = CodeySpacing.sm
        textView.gutterTrailingPadding = CodeySpacing.sm
        textView.textContainerInset = UIEdgeInsets(top: CodeySpacing.sm, left: CodeySpacing.xs, bottom: CodeySpacing.sm, right: CodeySpacing.sm)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        textView.keyboardType = .asciiCapable

        textView.setState(TextViewState(
            text: text,
            theme: CodeyRunestoneTheme(traits: textView.traitCollection),
            language: language.treeSitterLanguage
        ))
        context.coordinator.language = language
        context.coordinator.colorScheme = colorScheme
        apply(isEditable: isEditable, to: textView)
        return textView
    }

    func updateUIView(_ textView: TextView, context: Context) {
        let coordinator = context.coordinator
        if textView.text != text {
            textView.text = text
        }
        if coordinator.language != language {
            coordinator.language = language
            textView.setLanguageMode(TreeSitterLanguageMode(language: language.treeSitterLanguage))
        }
        if coordinator.colorScheme != colorScheme {
            coordinator.colorScheme = colorScheme
            // Runestone caches resolved colors; a new theme re-highlights.
            textView.theme = CodeyRunestoneTheme(traits: textView.traitCollection)
            textView.backgroundColor = UIColor(named: "CodeBackground")
        }
        if textView.isEditable != isEditable {
            apply(isEditable: isEditable, to: textView)
        }
    }

    private func apply(isEditable: Bool, to textView: TextView) {
        textView.isEditable = isEditable
        textView.inputAccessoryView = isEditable ? CodeKeyboardAccessory(textView: textView) : nil
    }

    private static let characterPairs: [any CharacterPair] = [
        CodePair(leading: "(", trailing: ")"),
        CodePair(leading: "[", trailing: "]"),
        CodePair(leading: "{", trailing: "}"),
        CodePair(leading: "\"", trailing: "\""),
        CodePair(leading: "'", trailing: "'"),
    ]

    final class Coordinator: NSObject, TextViewDelegate {
        private let text: Binding<String>
        var language: CodeLanguage?
        var colorScheme: ColorScheme?

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: TextView) {
            if text.wrappedValue != textView.text {
                text.wrappedValue = textView.text
            }
        }
    }
}

private struct CodePair: CharacterPair {
    let leading: String
    let trailing: String
}

extension CodeLanguage {
    fileprivate var treeSitterLanguage: TreeSitterLanguage {
        switch self {
        case .swift: .swift
        case .python: .python
        case .java: .java
        case .cpp: .cpp
        }
    }
}

/// Keyboard row with the symbols code needs most, a Tab key (4 spaces), and
/// a dismiss button. Scrolls horizontally on small phones.
private final class CodeKeyboardAccessory: UIInputView {
    private static let symbols = ["{", "}", "(", ")", "[", "]", ";", "\"", "'", "<", ">", "=", ":", "."]
    private weak var textView: TextView?

    init(textView: TextView) {
        self.textView = textView
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 48), inputViewStyle: .keyboard)
        allowsSelfSizing = true
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func build() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = CodeySpacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(key(title: "⇥", label: "Tab") { [weak self] in
            self?.textView?.insertText("    ")
        })
        for symbol in Self.symbols {
            stack.addArrangedSubview(key(title: symbol, label: symbol) { [weak self] in
                self?.textView?.insertText(symbol)
            })
        }

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        var dismissConfig = UIButton.Configuration.plain()
        dismissConfig.image = UIImage(systemName: "keyboard.chevron.compact.down")
        let dismiss = UIButton(configuration: dismissConfig, primaryAction: UIAction { [weak self] _ in
            self?.textView?.resignFirstResponder()
        })
        dismiss.accessibilityLabel = "Hide keyboard"
        dismiss.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scroll)
        addSubview(dismiss)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: CodeySpacing.sm),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.trailingAnchor.constraint(equalTo: dismiss.leadingAnchor, constant: -CodeySpacing.xs),
            dismiss.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -CodeySpacing.xs),
            dismiss.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismiss.widthAnchor.constraint(equalToConstant: 44),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            stack.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func key(title: String, label: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.cornerStyle = .medium
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var attributes = $0
            attributes.font = .monospacedSystemFont(ofSize: 17, weight: .medium)
            return attributes
        }
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in
            UIDevice.current.playInputClick()
            action()
        })
        button.accessibilityLabel = label
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        return button
    }
}

extension CodeKeyboardAccessory: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

#Preview("Code editor") {
    @Previewable @State var source = "def greet(name):\n    return f\"Hi {name}\"\n"
    @Previewable @State var language = CodeLanguage.python
    VStack {
        Picker("Language", selection: $language) {
            ForEach(CodeLanguage.allCases) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)
        CodeEditorView(text: $source, language: language)
            .frame(height: 220)
            .clipShape(.codey(CodeyRadius.md))
    }
    .padding()
}
