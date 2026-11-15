import SwiftUI

/// A deck's badge: "Starter" for bundled decks, otherwise the FR-48 sync
/// state as symbol + label (never color alone).
struct DeckStatusChip: View {
    let deck: FlashcardDeck
    /// Icon only, for a half-width tile's tag row (the name stays in
    /// VoiceOver).
    var compact = false

    var body: some View {
        if deck.origin == .starter {
            CodeyChip(compact ? "" : "Starter", systemImage: "sparkles", variant: .brand)
                .accessibilityLabel("Starter deck")
        } else {
            let state = deck.syncState
            CodeyChip(compact ? "" : state.displayName, systemImage: state.symbol, variant: state.chipVariant)
                .symbolEffect(.rotate, isActive: state == .syncing)
                .accessibilityLabel("Sync status: \(state.displayName)")
                .accessibilityIdentifier("syncStatus")
        }
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
