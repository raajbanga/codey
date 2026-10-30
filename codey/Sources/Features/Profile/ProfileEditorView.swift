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
    private var nameError: String? { ModelValidator().validateDisplayName(name).first?.message }

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: CodeySpacing.sm)]

    var body: some View {
        Form {
            Section {
                TextField("Display name", text: $name)
                    .textContentType(.nickname)
                    .submitLabel(.done)
                    .accessibilityIdentifier("profileEditor.name")
            } header: {
                Text("Name")
            } footer: {
                HStack {
                    if loaded, let nameError {
                        Text(nameError).foregroundStyle(CodeyColor.danger)
                    } else {
                        Text("Shown on Home and, when signed in, to your groups.")
                    }
                    Spacer()
                    Text("\(length)/\(limit)")
                        .monospacedDigit()
                        .foregroundStyle(length > limit ? CodeyColor.danger : CodeyColor.textSecondary)
                }
                .font(.codeyCaption)
            }

            Section("Avatar") {
                LazyVGrid(columns: columns, spacing: CodeySpacing.sm) {
                    ForEach(ProfileAvatar.symbols, id: \.self) { symbol in
                        AvatarChoice(symbol: symbol, isSelected: avatarId == symbol) {
                            avatarId = avatarId == symbol ? nil : symbol
                        }
                    }
                }
                .padding(.vertical, CodeySpacing.xs)
            }
        }
        .codeyListBackground()
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
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
            avatarId = profiles.first?.avatarId
            loaded = true
        }
        .errorAlert($actionError)
    }

    private func save() {
        $actionError.attempt {
            try backend.updateProfile(displayName: name, avatarId: avatarId)
            dismiss()
        }
    }
}

private struct AvatarChoice: View {
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 52

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.codeyTitle)
                .foregroundStyle(isSelected ? CodeyColor.onBrandFill : CodeyColor.brand)
                .frame(width: size, height: size)
                .background(isSelected ? CodeyColor.brandFill : CodeyColor.brandSoft, in: Circle())
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(CodeyColor.brand, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel(symbol.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The learner's avatar: their picked symbol on a soft circle, or the
/// default person glyph.
struct ProfileAvatarView: View {
    let avatarId: String?
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 56

    var body: some View {
        Group {
            if avatarId != nil {
                Image(systemName: ProfileAvatar.symbol(for: avatarId))
                    .font(.codeyTitle)
                    .frame(width: size, height: size)
                    .background(CodeyColor.brandSoft, in: Circle())
            } else {
                Image(systemName: ProfileAvatar.fallback)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        }
        .foregroundStyle(CodeyColor.brand)
        .accessibilityHidden(true)
    }
}
