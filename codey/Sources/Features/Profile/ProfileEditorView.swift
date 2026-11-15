import SwiftData
import SwiftUI

/// FR-04: display name + avatar. Pushed from the profile header. Saves
/// through BackendFacade, which validates and queues the sync.
struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BackendFacade.self) private var backend
    @Query private var profiles: [UserProfile]

    @State private var name = ""
    @State private var avatarId: String?
    @State private var loaded = false
    @State private var actionError: String?

    private var limit: Int { ModelValidator.Limits.displayName.upperBound }
    private var length: Int { ModelValidator.measuredLength(name) }
    private var nameError: String? { ModelValidator.validateDisplayName(name).first?.message }

    @State private var color: ProfileAvatar.Color = .slate

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: CodeySpacing.sm)]
    private let swatchColumns = [GridItem(.adaptive(minimum: 44), spacing: CodeySpacing.sm)]
    private var hue: CodeyColor.TopicHue { color.hue }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                preview
                nameField
                VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                    SectionTitle("Color")
                    LazyVGrid(columns: swatchColumns, spacing: CodeySpacing.sm) {
                        ForEach(ProfileAvatar.Color.allCases) { option in
                            ColorSwatch(color: option, isSelected: color == option) {
                                color = option
                                if avatarId == nil { avatarId = ProfileAvatar.fallback }
                            }
                        }
                    }
                    .padding(CodeySpacing.md)
                    .codeyNote()
                }
                VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                    SectionTitle("Icon")
                    LazyVGrid(columns: columns, spacing: CodeySpacing.sm) {
                        ForEach(ProfileAvatar.symbols, id: \.self) { symbol in
                            AvatarChoice(symbol: symbol, hue: hue, isSelected: avatarId == symbol) {
                                avatarId = avatarId == symbol ? nil : symbol
                            }
                        }
                    }
                    .padding(CodeySpacing.md)
                    .codeyNote()
                }
            }
            .padding(CodeySpacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .codeyPaperBackground()
        .codeyPageTitle("Edit Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(nameError != nil)
                    .accessibilityIdentifier("profileEditor.save")
            }
        }
        .onAppear {
            guard !loaded else { return }
            name = profiles.first?.username ?? UserProfile.defaultUsername
            let stored = ProfileAvatar.parse(profiles.first?.avatarId)
            avatarId = stored?.symbol
            color = stored?.color ?? .slate
            loaded = true
        }
        .errorAlert($actionError)
    }

    /// The avatar and name as the group board shows them.
    private var preview: some View {
        HStack(spacing: CodeySpacing.md) {
            ProfileAvatarView(avatarId: storedId, size: 64, emphasized: true)
            VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                Text(name.isEmpty ? UserProfile.defaultUsername : name)
                    .font(.codeyTitle.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("How your groups see you")
                    .font(.codeySubheadline)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(hue.ink)
        .padding(CodeySpacing.md)
        .background(hue.soft, in: .codey(CodeyRadius.lg))
        .environment(\.colorScheme, .light)
        .codeyAnimation(CodeyMotion.snappy, value: color)
        .accessibilityElement(children: .combine)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            SectionTitle("Name")
            TextField("Display name", text: $name)
                .font(.codeyBody)
                .textContentType(.nickname)
                .submitLabel(.done)
                .padding(CodeySpacing.md)
                .codeyNote()
                .accessibilityIdentifier("profileEditor.name")
            HStack {
                if loaded, let nameError {
                    Text(nameError).foregroundStyle(CodeyColor.danger)
                } else {
                    Text("Shown on Play and, when signed in, to your groups.")
                }
                Spacer()
                Text("\(length)/\(limit)")
                    .monospacedDigit()
                    .foregroundStyle(length > limit ? CodeyColor.danger : CodeyColor.textSecondary)
            }
            .font(.codeyCaption)
            .foregroundStyle(CodeyColor.textSecondary)
            .padding(.horizontal, CodeySpacing.xs)
        }
    }

    /// What gets saved: nil, or the symbol with its color.
    private var storedId: String? {
        avatarId.map { ProfileAvatar.id(symbol: $0, color: color) }
    }

    private func save() {
        $actionError.attempt {
            try backend.updateProfile(displayName: name, avatarId: storedId)
            dismiss()
        }
    }
}

private struct AvatarChoice: View {
    let symbol: String
    let hue: CodeyColor.TopicHue
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 52

    var body: some View {
        Button(action: action) {
            AvatarGlyph(symbol: symbol, hue: hue, size: size, emphasized: isSelected)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(hue.ink, lineWidth: 2).padding(-4)
                    }
                }
                .padding(4)
        }
        .buttonStyle(TilePressStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel(ProfileAvatar.glyph(for: symbol).replacingOccurrences(of: ".", with: " "))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// One avatar color: a swatch in the hue, ringed when picked.
private struct ColorSwatch: View {
    let color: ProfileAvatar.Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.hue.fill)
                .frame(width: 36, height: 36)
                .overlay {
                    if isSelected {
                        Icon("checkmark", size: 16, relativeTo: .callout)
                            .foregroundStyle(.white)
                    }
                }
                .padding(4)
                .overlay {
                    if isSelected { Circle().strokeBorder(color.hue.fill, lineWidth: 2) }
                }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(TilePressStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel(color.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// An avatar symbol in a circle of its hue: the soft pastel with ink, or
/// (picked) the fill with white.
struct AvatarGlyph: View {
    let symbol: String
    let hue: CodeyColor.TopicHue
    let size: CGFloat
    var emphasized = false

    var body: some View {
        Image(systemName: ProfileAvatar.glyph(for: symbol))
            .resizable()
            .scaledToFit()
            .fontWeight(.medium)
            .frame(width: size * 0.5, height: size * 0.5)
            .foregroundStyle(emphasized ? .white : hue.ink)
            .frame(width: size, height: size)
            .background(emphasized ? hue.fill : hue.soft, in: Circle())
            .accessibilityHidden(true)
    }
}

/// The learner's avatar: their symbol in their color, or the default person
/// on slate. Used on the profile, the editor and group boards.
struct ProfileAvatarView: View {
    let avatarId: String?
    /// The hue's fill with a white glyph, for an avatar on its own pastel.
    var emphasized = false
    @ScaledMetric private var size: CGFloat

    init(avatarId: String?, size: CGFloat = 56, emphasized: Bool = false) {
        self.avatarId = avatarId
        self.emphasized = emphasized
        _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
    }

    var body: some View {
        AvatarGlyph(
            symbol: ProfileAvatar.symbol(for: avatarId),
            hue: ProfileAvatar.color(for: avatarId).hue,
            size: size,
            emphasized: emphasized
        )
    }
}
