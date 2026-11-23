import SwiftUI
import UserNotifications

/// The first-minutes tooltips on the board: what you're into, a first post, inviting people, and, later, the
/// first time a note arrives, a question about notifications. One tip at a time, none blocks the board.
@MainActor @Observable
final class TipsStore {
    enum Step: String { case none, into, post, invite, note }
    /// We ask Apple for notification permission only after our own "want a heads-up?" is accepted, so a "Not now"
    /// never uses up the one real chance.
    enum NotifAsk: String { case notAsked, deferred, answered }

    private(set) var step: Step
    private(set) var notifAsk: NotifAsk
    /// Who left the note the notification tip is about.
    private(set) var noteFrom = "Maya"
    /// A private, single-use link for the invite tip. Until there is a server this is a stand-in.
    let inviteURL: URL

    init() {
        let d = UserDefaults.standard
        step = Step(rawValue: d.string(forKey: "tips.step") ?? "") ?? .none
        notifAsk = NotifAsk(rawValue: d.string(forKey: "tips.notifAsk") ?? "") ?? .notAsked
        let token = String((0..<8).map { _ in "abcdefghijkmnpqrstuvwxyz23456789".randomElement()! })
        inviteURL = URL(string: "https://bulletin.app/i/\(token)")!
    }

    private func go(_ new: Step) {
        withAnimation(.spring(duration: 0.55, bounce: 0.3)) { step = new }
        UserDefaults.standard.set(new.rawValue, forKey: "tips.step")
    }

    /// Sign-up just finished: start with what you're into.
    func begin() { go(.into) }

    /// "currently into" was set (or the tip was skipped): on to the first post.
    func finishInto() {
        guard step == .into else { return }
        Task { try? await Task.sleep(for: .milliseconds(450)); if step == .into { go(.post) } }
    }

    /// A post landed on the board.
    func postMade() {
        guard step == .post else { return }
        Task { try? await Task.sleep(for: .milliseconds(1100)); if step == .post { go(.invite) } }
    }

    #if DEBUG
    /// Jump straight to a tip (launch argument -tipInvite).
    func debugShow(_ new: Step) { go(new) }
    #endif

    /// The invite tip was used or put off.
    func finishInvite() { if step == .invite { go(.none) } }

    /// A friend left you a note. The first time, ask about notifications.
    func noteArrived(by name: String) {
        guard step == .none, notifAsk != .answered else { return }
        noteFrom = name
        go(.note)
    }

    func allowNotifications() {
        Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) }
        setAsk(.answered)
        go(.none)
    }

    /// "Not now": we'll ask once more on a later note, then leave it to Settings.
    func notNow() {
        setAsk(notifAsk == .notAsked ? .deferred : .answered)
        go(.none)
    }

    private func setAsk(_ a: NotifAsk) {
        notifAsk = a
        UserDefaults.standard.set(a.rawValue, forKey: "tips.notifAsk")
    }
}
