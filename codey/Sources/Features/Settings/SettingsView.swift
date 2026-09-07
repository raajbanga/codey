import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("preferredDarkMode") private var preferredDarkMode = false

    @State private var showResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: CodeySpacing.md) {
                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("Appearance")
                            .font(.codeyHeadline)

                        HStack {
                            VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                                Text("Dark Mode")
                                    .font(.codeySubheadline)
                                Text("Override system appearance for the app.")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColor.muted)
                            }
                            Spacer()
                            Toggle("", isOn: $preferredDarkMode)
                                .labelsHidden()
                        }
                    }
                }

                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("Local Data")
                            .font(.codeyHeadline)
                        Text("All data is stored on-device.")
                            .font(.codeySubheadline)
                            .foregroundStyle(ThemeColor.muted)
                        CodeyBadge("Local only", variant: .success)
                    }
                }

                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("Danger Zone")
                            .font(.codeyHeadline)
                        Text("Reset all local progress, topics, and questions. Fresh sample data will be re-seeded automatically.")
                            .font(.codeySubheadline)
                            .foregroundStyle(ThemeColor.muted)
                        CodeyButton("Reset Local Data", variant: .destructive) {
                            showResetConfirmation = true
                        }
                    }
                }
            }
            .padding(CodeySpacing.md)
        }
        .background(ThemeColor.canvas)
        .navigationTitle("Settings")
        .preferredColorScheme(preferredDarkMode ? .dark : .light)
        .alert("Reset Local Data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                DataSeeder.resetAllData(context: modelContext)
            }
        } message: {
            Text("This will erase all local progress and re-seed sample data. This action cannot be undone.")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(ModelContainerFactory.makePreview())
}
