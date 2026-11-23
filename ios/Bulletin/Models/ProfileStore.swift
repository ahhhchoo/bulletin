import SwiftUI

/// Who you are in Bulletin: what sign-up collected, kept on this device until there is a server. Settings edits it.
/// Only the username and photo are ever shown to other people. The name, birthday and phone number are private.
@Observable final class ProfileStore {
    var username = ""
    var first = ""
    var last = ""
    var phone = ""            // 10 digits, US. Empty when they signed up with Apple and haven't added one
    var birthday: Date?
    var photo: UIImage?
    var signedUpWith = SignUpMethod.phone
    var usernameChangedAt: Date?

    /// A username can change once a month.
    static let usernameCooldownDays = 30

    init() {
        load()
        #if DEBUG
        // launch with -noPhone to see the state of someone who signed up with Apple and hasn't added a number
        if CommandLine.arguments.contains("-noPhone") { phone = ""; signedUpWith = .apple; usernameChangedAt = nil }
        #endif
    }

    var isSignedUp: Bool { !username.isEmpty }
    var hasPhone: Bool { phone.count == 10 }
    var initial: String { String((username.first ?? first.first ?? "?")).uppercased() }
    var fullName: String { [first, last].filter { !$0.isEmpty }.joined(separator: " ") }

    var nextUsernameChange: Date? {
        usernameChangedAt.flatMap { Calendar.current.date(byAdding: .day, value: Self.usernameCooldownDays, to: $0) }
    }
    var canChangeUsername: Bool { nextUsernameChange.map { $0 <= .now } ?? true }

    var formattedPhone: String {
        guard hasPhone else { return "" }
        return "(\(phone.prefix(3))) \(phone.dropFirst(3).prefix(3))-\(phone.dropFirst(6))"
    }

    /// Called when sign-up finishes.
    func adopt(_ model: SignUpModel, method: SignUpMethod) {
        username = model.username
        first = model.first.trimmingCharacters(in: .whitespaces)
        last = model.last.trimmingCharacters(in: .whitespaces)
        phone = model.phone
        birthday = model.birthday
        photo = model.photo
        signedUpWith = method
        usernameChangedAt = nil
        save()
    }

    /// Called when someone signs in again: puts back what the server saved.
    func restore(_ remote: RemoteProfile, phone: String) {
        username = remote.username
        first = remote.first
        last = remote.last
        self.phone = phone
        birthday = remote.birthday
        photo = remote.photo
        signedUpWith = remote.signedUpWith
        usernameChangedAt = remote.usernameChangedAt
        save()
    }

    // MARK: saving

    private static var photoURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("profile.jpg")
    }

    func save() {
        let d = UserDefaults.standard
        d.set(username, forKey: "profile.username")
        d.set(first, forKey: "profile.firstName")
        d.set(last, forKey: "profile.lastName")
        d.set(phone, forKey: "profile.phone")
        d.set(birthday, forKey: "profile.birthday")
        d.set(signedUpWith == .apple ? "apple" : "phone", forKey: "profile.method")
        d.set(usernameChangedAt, forKey: "profile.usernameChangedAt")
        guard let url = Self.photoURL else { return }
        if let data = photo?.jpegData(compressionQuality: 0.85) { try? data.write(to: url) }
        else { try? FileManager.default.removeItem(at: url) }
    }

    private func load() {
        let d = UserDefaults.standard
        username = d.string(forKey: "profile.username") ?? ""
        first = d.string(forKey: "profile.firstName") ?? ""
        last = d.string(forKey: "profile.lastName") ?? ""
        phone = d.string(forKey: "profile.phone") ?? ""
        birthday = d.object(forKey: "profile.birthday") as? Date
        signedUpWith = d.string(forKey: "profile.method") == "apple" ? .apple : .phone
        usernameChangedAt = d.object(forKey: "profile.usernameChangedAt") as? Date
        if let url = Self.photoURL, let data = try? Data(contentsOf: url) { photo = UIImage(data: data) }
    }
}
