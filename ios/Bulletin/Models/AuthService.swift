import Foundation
import FirebaseAuth

/// Signing in with Firebase. Phone first: send a code to a US number, then check what they type.
/// (Sign in with Apple comes later, once the paid Apple Developer account is set up.)
@Observable
final class AuthService {
    /// Who is signed in, or nil. Filled in by `start()`.
    private(set) var uid: String?
    var isSignedIn: Bool { uid != nil }

    /// Handed back by Firebase when a code is sent; the code the person types is checked against it.
    private var verificationID: String?
    private var started = false

    /// Call once the app is up, never from `App.init`: Firebase Auth looks for the running app the first time it is
    /// used, and at that early moment there isn't one yet, so phone sign-in fails with "notification not forwarded".
    func start() {
        guard !started else { return }
        started = true
        #if DEBUG
        // In the simulator there are no push notifications, so Firebase can't check the app is real. This switch skips
        // that check, and only works for the fake numbers added in the Firebase console (Authentication > Sign-in method
        // > Phone > Phone numbers for testing).
        #if targetEnvironment(simulator)
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif
        #endif
        uid = Auth.auth().currentUser?.uid
    }

    enum AuthError: LocalizedError {
        case noCodeSent
        case noUser
        var errorDescription: String? {
            switch self {
            case .noCodeSent: "Ask for a code first."
            case .noUser: "You aren’t signed in."
            }
        }
    }

    /// Texts a code to a US number given as 10 digits.
    func sendCode(toUSNumber digits: String) async throws {
        start()
        verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber("+1" + digits, uiDelegate: nil)
    }

    /// Checks the code. `linking` is for someone already signed in (with Apple) adding or changing their number,
    /// so it attaches to their account instead of signing in as a new one.
    func verify(code: String, linking: Bool = false) async throws {
        start()
        guard let verificationID else { throw AuthError.noCodeSent }
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: code)
        if linking {
            guard let user = Auth.auth().currentUser else { throw AuthError.noUser }
            try await user.updatePhoneNumber(credential)
            uid = user.uid
        } else {
            uid = try await Auth.auth().signIn(with: credential).user.uid
        }
    }

    func signOut() {
        start()
        try? Auth.auth().signOut()
        uid = nil
        verificationID = nil
    }
}
