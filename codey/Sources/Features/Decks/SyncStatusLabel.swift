import SwiftUI

/// FR-48 badge: a symbol + label per sync state (never color alone).
struct SyncStatusLabel: View {
    let state: DeckSyncStateKind

    var body: some View {
        CodeyChip(state.displayName, systemImage: state.symbol, variant: state.chipVariant)
            .symbolEffect(.rotate, isActive: state == .syncing)
            .accessibilityLabel("Sync status: \(state.displayName)")
            .accessibilityIdentifier("syncStatus")
    }
}

extension DeckSyncStateKind {
    var displayName: String {
        switch self {
        case .drafting: "Draft"
        case .locallyPersisted: "Saved locally"
        case .syncing: "Syncing"
        case .synced: "Synced"
        case .conflict: "Conflict"
        }
    }

    var symbol: String {
        switch self {
        case .drafting: "pencil"
        case .locallyPersisted: "internaldrive"
        case .syncing: "arrow.triangle.2.circlepath"
        case .synced: "checkmark.icloud"
        case .conflict: "exclamationmark.triangle.fill"
        }
    }

    var chipVariant: CodeyChipVariant {
        switch self {
        case .drafting, .locallyPersisted: .neutral
        case .syncing: .brand
        case .synced: .success
        case .conflict: .warning
        }
    }
}
