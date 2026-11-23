import Foundation
import FirebaseFirestore

/// The monthly prompt: one question for everyone, written by hand, a month at a time.
///
/// The list is bundled with the app, so a prompt is always there, even offline. A Firestore document named for the
/// month (`prompts/2026-12`, with a `text` field) can replace any of them without an app update.
enum PromptCalendar {
    /// Used if a month has no entry (the list runs out in September 2028).
    static let fallback = "What’s been on your mind?"

    /// Keyed "yyyy-MM". Questions, short enough for the prompt card.
    static let bundled: [String: String] = [
        "2026-11": "What made you smile",
        "2026-12": "What’s something you’d like to remember?",
        "2027-01": "What are you looking forward to?",
        "2027-02": "What’s the smallest good thing that happened?",
        "2027-03": "What have you been putting off?",
        "2027-04": "What did you make?",
        "2027-05": "What’s your favorite spot right now?",
        "2027-06": "What would you do with an extra day?",
        "2027-07": "What’s the best thing you ate?",
        "2027-08": "What did you do just for fun?",
        "2027-09": "What did you learn lately?",
        "2027-10": "What felt a little strange?",
        "2027-11": "Who are you thankful for?",
        "2027-12": "What are you proud of lately?",
        "2028-01": "What would you tell yourself a month ago?",
        "2028-02": "What are you reading or watching?",
        "2028-03": "What’s a small thing that’s been bugging you?",
        "2028-04": "What are you obsessed with?",
        "2028-05": "What did your morning look like?",
        "2028-06": "What are you listening to on repeat?",
        "2028-07": "What’s in your bag right now?",
        "2028-08": "What surprised you?",
        "2028-09": "What’s been on your mind?",
    ]

    /// "2026-12" for any day in December 2026, in the person's own calendar.
    static func key(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    static func text(for date: Date = BoardCalendar.now) -> String { bundled[key(for: date)] ?? fallback }

    /// Next month's prompt, for the reveal at the end of the seal ritual.
    static func nextMonthText(after date: Date = BoardCalendar.now) -> String {
        text(for: Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date)
    }

    /// The server's version of a month's prompt, if there is one. Nil means "use the bundled one".
    static func remoteText(for date: Date = BoardCalendar.now) async -> String? {
        let snap = try? await Firestore.firestore().collection("prompts").document(key(for: date)).getDocument()
        guard let text = snap?.data()?["text"] as? String, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return text
    }
}
