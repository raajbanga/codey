import SwiftData
import SwiftUI
import os

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    @State private var showResetProgressConfirmation = false
    @State private var showEraseConfirmation = false
    @State private var actionError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: CodeySpacing.md) {
                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("Appearance")
                            .font(.codeyHeadline)

                        Picker("Appearance", selection: $appearance) {
                            ForEach(AppAppearance.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("Local Data")
                            .font(.codeyHeadline)
                        Text("All data is stored on-device.")
                            .font(.codeySubheadline)
                            .foregroundStyle(CodeyColor.textSecondary)
                        CodeyChip("Local only", variant: .success)
                    }
                }

                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("Danger Zone")
                            .font(.codeyHeadline)
                        Text("Reset progress sets XP, streak, and card mastery back to zero. Your decks stay.")
                            .font(.codeySubheadline)
                            .foregroundStyle(CodeyColor.textSecondary)
                        CodeyButton("Reset Progress", kind: .secondary) {
                            showResetProgressConfirmation = true
                        }
                        Text("Erase all local data deletes your decks, progress, and profile from this device.")
                            .font(.codeySubheadline)
                            .foregroundStyle(CodeyColor.textSecondary)
                        CodeyButton("Erase All Local Data", kind: .destructive) {
                            showEraseConfirmation = true
                        }
                    }
                }
            }
            .padding(CodeySpacing.md)
        }
        .background(CodeyColor.surface)
        .navigationTitle("Settings")
        .alert("Reset Progress?", isPresented: $showResetProgressConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                perform { try LocalDataReset.resetProgress(context: modelContext) }
            }
        } message: {
            Text("XP, streak, and card mastery go back to zero. This can't be undone.")
        }
        .alert("Erase All Local Data?", isPresented: $showEraseConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Erase", role: .destructive) {
                perform {
                    try LocalDataReset.eraseAllLocalData(
                        context: modelContext,
                        bank: QuestionBankLoader.loadBank()
                    )
                }
            }
        } message: {
            Text("Your decks, progress, and profile will be deleted from this device. This can't be undone.")
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            Logger.settings.error("Data action failed: \(String(describing: error))")
            actionError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(ModelContainerFactory.makePreview())
}
