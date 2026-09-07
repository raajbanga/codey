import Foundation
import SwiftData

enum DataSeeder {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Topic>()
        let existingTopics = (try? context.fetch(descriptor)) ?? []
        guard existingTopics.isEmpty else { return }

        let profile = UserProfile(
            username: "Codey Learner",
            totalXP: 1250,
            currentStreak: 7,
            lastActiveDate: .now
        )
        context.insert(profile)

        let dataStructures = Topic(
            title: "Data Structures",
            summary: "Arrays, linked lists, stacks, queues, and hash tables.",
            iconName: "square.stack.3d.up.fill"
        )

        let algorithms = Topic(
            title: "Algorithms",
            summary: "Sorting, searching, recursion, and complexity analysis.",
            iconName: "function"
        )

        let dsQuestions = [
            Question(
                prompt: "What is the average time complexity of accessing an element in a dynamic array by index?",
                options: ["O(1)", "O(log n)", "O(n)", "O(n log n)"],
                correctOptionIndex: 0,
                explanation: "Dynamic arrays support constant-time random access via index.",
                difficulty: .easy,
                topic: dataStructures
            ),
            Question(
                prompt: "Which data structure uses FIFO (First In, First Out) ordering?",
                options: ["Stack", "Queue", "Binary Tree", "Hash Map"],
                correctOptionIndex: 1,
                explanation: "Queues process elements in the order they were enqueued.",
                difficulty: .easy,
                topic: dataStructures
            ),
            Question(
                prompt: "What is the worst-case time complexity of lookup in a hash table with many collisions?",
                options: ["O(1)", "O(log n)", "O(n)", "O(n²)"],
                correctOptionIndex: 2,
                explanation: "With poor hashing or many collisions, lookup degrades to linear scan.",
                difficulty: .medium,
                topic: dataStructures
            ),
        ]

        let algoQuestions = [
            Question(
                prompt: "What is the time complexity of binary search on a sorted array?",
                options: ["O(1)", "O(log n)", "O(n)", "O(n log n)"],
                correctOptionIndex: 1,
                explanation: "Binary search halves the search space each step, giving O(log n).",
                difficulty: .easy,
                topic: algorithms
            ),
            Question(
                prompt: "Which sorting algorithm has a best-case time complexity of O(n)?",
                options: ["Merge Sort", "Quick Sort", "Insertion Sort", "Heap Sort"],
                correctOptionIndex: 2,
                explanation: "Insertion sort runs in O(n) when the input is already nearly sorted.",
                difficulty: .medium,
                topic: algorithms
            ),
            Question(
                prompt: "What does the Master Theorem help analyze?",
                options: [
                    "Graph traversal order",
                    "Divide-and-conquer recurrence relations",
                    "Hash collision resolution",
                    "Memory allocation patterns",
                ],
                correctOptionIndex: 1,
                explanation: "The Master Theorem provides closed-form solutions for common recurrences.",
                difficulty: .hard,
                topic: algorithms
            ),
        ]

        dataStructures.questions = dsQuestions
        algorithms.questions = algoQuestions

        context.insert(dataStructures)
        context.insert(algorithms)

        try? context.save()
    }

    static func resetAllData(context: ModelContext) {
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        profiles.forEach { context.delete($0) }

        let topics = (try? context.fetch(FetchDescriptor<Topic>())) ?? []
        topics.forEach { context.delete($0) }

        let questions = (try? context.fetch(FetchDescriptor<Question>())) ?? []
        questions.forEach { context.delete($0) }

        try? context.save()
        seedIfNeeded(context: context)
    }
}
