import Foundation

/// Which quiz to run, for `.fullScreenCover(item:)`.
struct QuizRequest: Identifiable, Equatable {
    let topic: Topic
    let mode: QuizMode

    var id: String {
        switch mode {
        case .mixed: "\(topic.id).mixed"
        case .tier(let tier): "\(topic.id).\(tier.rawValue)"
        case .review: "\(topic.id).review"
        }
    }
}
