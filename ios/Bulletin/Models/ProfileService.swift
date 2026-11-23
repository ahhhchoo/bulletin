import UIKit
import CryptoKit
import FirebaseFirestore
import FirebaseStorage

/// What the server knows about a person, handed back when they sign in again.
struct RemoteProfile {
    var username: String
    var first: String
    var last: String
    var birthday: Date?
    var usernameChangedAt: Date?
    var photo: UIImage?
    var signedUpWith: SignUpMethod
}

/// Saves and loads a person's profile in Firebase (Firestore for the details, Storage for the picture).
///
/// - `profiles/{uid}`: public, the username and picture
/// - `users/{uid}`: private, name and birthday (the phone number lives in Firebase Auth, not here)
/// - `usernames/{name}`: one document per taken name, which is what keeps names unique
///
/// The rules that protect all of this are in `backend/firestore.rules` and `backend/storage.rules`.
@Observable
final class ProfileService {
    enum ProfileError: LocalizedError {
        case usernameTaken
        case notSignedIn
        var errorDescription: String? {
            switch self {
            case .usernameTaken: "Someone just took that username. Pick another one."
            case .notSignedIn: "You aren’t signed in."
            }
        }
    }

    private var db: Firestore { Firestore.firestore() }
    private var storage: Storage { Storage.storage() }

    // MARK: usernames

    /// Is this username free? (Your own counts as free, so you can keep it.)
    func isUsernameFree(_ name: String, mine uid: String?) async throws -> Bool {
        let snap = try await db.collection("usernames").document(name).getDocument()
        guard snap.exists else { return true }
        return uid != nil && snap.data()?["uid"] as? String == uid
    }

    // MARK: signing up

    /// Creates the profile: claims the username and writes both documents in one go, so it all happens or none of it does.
    func createProfile(uid: String, username: String, first: String, last: String, birthday: Date,
                       photo: UIImage?, method: SignUpMethod) async throws {
        let photoPath = try await uploadAvatar(photo, uid: uid)

        var publicInfo: [String: Any] = ["username": username]
        if let photoPath { publicInfo["photoPath"] = photoPath }

        let batch = db.batch()
        batch.setData(["uid": uid, "claimedAt": FieldValue.serverTimestamp()], forDocument: db.collection("usernames").document(username))
        batch.setData(publicInfo, forDocument: db.collection("profiles").document(uid))
        batch.setData(["first": first, "last": last, "birthday": Timestamp(date: birthday),
                       "signedUpWith": method == .apple ? "apple" : "phone",
                       "createdAt": FieldValue.serverTimestamp()], forDocument: db.collection("users").document(uid))
        do { try await batch.commit() } catch { throw Self.translate(error) }
    }

    // MARK: signing in again

    /// The saved profile, or nil if this person never finished signing up.
    func loadProfile(uid: String) async throws -> RemoteProfile? {
        let publicSnap = try await db.collection("profiles").document(uid).getDocument()
        guard let pub = publicSnap.data(), let username = pub["username"] as? String else { return nil }
        let privateSnap = try await db.collection("users").document(uid).getDocument()
        let priv = privateSnap.data() ?? [:]

        var photo: UIImage?
        if let path = pub["photoPath"] as? String,
           let data = try? await storage.reference(withPath: path).data(maxSize: 3 * 1024 * 1024) {
            photo = UIImage(data: data)
        }
        return RemoteProfile(username: username,
                             first: priv["first"] as? String ?? "",
                             last: priv["last"] as? String ?? "",
                             birthday: (priv["birthday"] as? Timestamp)?.dateValue(),
                             usernameChangedAt: (pub["usernameChangedAt"] as? Timestamp)?.dateValue(),
                             photo: photo,
                             signedUpWith: priv["signedUpWith"] as? String == "apple" ? .apple : .phone)
    }

    // MARK: editing

    /// Moves to a new username: claims it and lets go of the old one together. The server only allows this once a month.
    func changeUsername(uid: String, from old: String, to new: String) async throws {
        let batch = db.batch()
        batch.setData(["uid": uid, "claimedAt": FieldValue.serverTimestamp()], forDocument: db.collection("usernames").document(new))
        if !old.isEmpty { batch.deleteDocument(db.collection("usernames").document(old)) }
        batch.updateData(["username": new, "usernameChangedAt": FieldValue.serverTimestamp()], forDocument: db.collection("profiles").document(uid))
        do { try await batch.commit() } catch { throw Self.translate(error) }
    }

    func updateName(uid: String, first: String, last: String) async throws {
        try await db.collection("users").document(uid).updateData(["first": first, "last": last])
    }

    func updateBirthday(uid: String, birthday: Date) async throws {
        try await db.collection("users").document(uid).updateData(["birthday": Timestamp(date: birthday)])
    }

    func updatePhoto(uid: String, photo: UIImage) async throws {
        guard let path = try await uploadAvatar(photo, uid: uid) else { return }
        try await db.collection("profiles").document(uid).updateData(["photoPath": path])
    }

    // MARK: pictures

    /// Uploads a profile picture (already shrunk to 512 px). Its file name is a fingerprint of the picture, so a
    /// different picture is a different file and a phone can keep any copy of it for good.
    private func uploadAvatar(_ image: UIImage?, uid: String) async throws -> String? {
        guard let image, let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let name = SHA256.hash(data: data).prefix(12).map { String(format: "%02x", $0) }.joined()
        let path = "avatars/\(uid)/\(name).jpg"
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        meta.cacheControl = "public, max-age=31536000, immutable"
        _ = try await storage.reference(withPath: path).putDataAsync(data, metadata: meta)
        return path
    }

    /// A refused batch means the username was taken (the rules never let a taken name be written again).
    private static func translate(_ error: Error) -> Error {
        let e = error as NSError
        if e.domain == FirestoreErrorDomain, e.code == FirestoreErrorCode.permissionDenied.rawValue { return ProfileError.usernameTaken }
        return error
    }
}
