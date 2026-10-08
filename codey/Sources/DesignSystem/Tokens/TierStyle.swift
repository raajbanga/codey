import SwiftUI

/// How a difficulty tier looks. Color is never the only signal: every tier
/// also has a symbol and a label (NFR-12).
struct TierStyle: Equatable {
    let color: Color
    let symbol: String
    let label: String

    init(_ difficulty: Difficulty) {
        switch difficulty {
        case .easy:
            color = CodeyColor.Tier.easy
            symbol = "leaf.fill"
            label = "Easy"
        case .medium:
            color = CodeyColor.Tier.medium
            symbol = "flame.fill"
            label = "Medium"
        case .hard:
            color = CodeyColor.Tier.hard
            symbol = "bolt.fill"
            label = "Hard"
        }
    }

    var accessibilityLabel: String { "\(label) tier" }
}

extension Difficulty {
    var style: TierStyle { TierStyle(self) }
}
