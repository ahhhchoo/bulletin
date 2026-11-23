import SwiftUI
import PhotosUI

enum SignUpMethod { case phone, apple }

/// What sign-up collects. Nothing here talks to a server yet: availability is checked against a local list and the
/// result is saved on the device.
@Observable final class SignUpModel {
    var phone = ""        // digits only, US numbers
    var code = ""
    var first = ""
    var last = ""
    var username = ""
    var photo: UIImage?
    var birthday = Calendar.current.date(byAdding: .year, value: -22, to: .now) ?? .now
    /// Set by the username screen once the server says the name is free.
    var usernameFree = false

    static let minimumAge = 13
    static let usernameRange = 3...20
    /// Stand-in for the server's list of taken names.
    static let taken: Set<String> = ["maya", "sam", "alina", "jo", "bulletin", "admin", "support", "mia", "leo", "kai"]

    var age: Int { Calendar.current.dateComponents([.year], from: birthday, to: .now).year ?? 0 }
    var isOldEnough: Bool { age >= Self.minimumAge }
    var initial: String { String((username.first ?? first.first ?? "?")).uppercased() }
}

private enum Step { case phone, code, name, username, photo, birthday, done }

/// Sign up: phone and code (skipped for Apple), name, username, photo, birthday.
struct SignUpView: View {
    let method: SignUpMethod
    let onBack: () -> Void
    let onFinish: () -> Void

    @Environment(ProfileStore.self) private var profile
    @Environment(AuthService.self) private var auth
    @Environment(ProfileService.self) private var service
    @State private var model = SignUpModel()
    @State private var sending = false
    @State private var sendError: String?
    @State private var saveError: String?
    @State private var index = 0
    @State private var forward = true
    @State private var pickerItem: PhotosPickerItem?

    private var steps: [Step] {
        method == .phone ? [.phone, .code, .name, .username, .photo, .birthday, .done]
                         : [.name, .username, .photo, .birthday, .done]
    }
    private var step: Step { steps[index] }

    var body: some View {
        ZStack(alignment: .top) {
            Color("Paper").ignoresSafeArea()
                .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }

            VStack(spacing: 0) {
                if step != .done { topBar.transition(.opacity) }
                ZStack {
                    stepView
                        .id(index)
                        .transition(.asymmetric(insertion: .modifier(active: Shift(x: forward ? 28 : -28), identity: Shift(x: 0)),
                                                removal: .modifier(active: Shift(x: forward ? -28 : 28), identity: Shift(x: 0))))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = MediaProcessor.avatar(from: data) {
                    withAnimation(.spring(duration: 0.4)) { model.photo = image }
                }
            }
        }
    }

    // MARK: navigation

    private func go(_ delta: Int) {
        let next = index + delta
        if next < 0 { onBack(); return }
        guard next < steps.count else { return }
        forward = delta > 0
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.4)) { index = next }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { go(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(.white, in: Circle())
                    .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Back")

            HStack(spacing: 5) {
                ForEach(0..<(steps.count - 1), id: \.self) { i in
                    Capsule().fill(.black.opacity(0.1)).frame(height: 4)
                        .overlay(alignment: .leading) {
                            Capsule().fill(.black).scaleEffect(x: i <= index ? 1 : 0, anchor: .leading)
                        }
                        .clipShape(Capsule())
                }
            }
            .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.45), value: index)
            .accessibilityElement()
            .accessibilityLabel("Step \(index + 1) of \(steps.count - 1)")
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }

    // MARK: the screens

    @ViewBuilder private var stepView: some View {
        switch step {
        case .phone: PhoneStep(model: model)
        case .code: CodeStep(model: model, onVerified: { afterVerified() })
        case .name: NameStep(model: model, onDone: { if canContinue { go(1) } })
        case .username: UsernameStep(model: model, onDone: { if canContinue { go(1) } })
        case .photo: PhotoStep(model: model, picker: $pickerItem)
        case .birthday: BirthdayStep(model: model)
        case .done: DoneStep(model: model)
        }
    }

    private var canContinue: Bool {
        switch step {
        case .phone: model.phone.count == 10
        case .name: !model.first.trimmingCharacters(in: .whitespaces).isEmpty && !model.last.trimmingCharacters(in: .whitespaces).isEmpty
        case .username: UsernameCheck.isUsable(model.username) && model.usernameFree
        case .birthday: model.isOldEnough
        default: true
        }
    }

    @ViewBuilder private var bottomBar: some View {
        VStack(spacing: 12) {
            switch step {
            case .code:
                EmptyView()
            case .photo:
                if model.photo == nil {
                    PhotosPicker(selection: $pickerItem, matching: .images) { CapsuleLabel(title: "Choose a photo", style: .solid) }
                    Button { go(1) } label: { CapsuleLabel(title: "Skip for now", style: .outline) }.buttonStyle(PressableStyle())
                } else {
                    PhotosPicker(selection: $pickerItem, matching: .images) { CapsuleLabel(title: "Choose a different photo", style: .outline) }
                    Button { go(1) } label: { CapsuleLabel(title: "Looks good", style: .solid) }.buttonStyle(PressableStyle())
                }
            case .done:
                Button {
                    profile.adopt(model, method: method)
                    onFinish()
                } label: { CapsuleLabel(title: "Start your Bulletin", style: .solid) }.buttonStyle(PressableStyle())
            default:
                Button {
                    if step == .phone { sendCode() } else if step == .birthday { saveProfile() } else { go(1) }
                } label: { CapsuleLabel(title: step == .phone ? (sending ? "Sending…" : "Send code") : (step == .birthday && sending ? "Saving…" : "Continue"), style: .solid) }
                    .buttonStyle(PressableStyle())
                    .disabled(!canContinue || sending)
                    .opacity(canContinue && !sending ? 1 : 0.22)
                    .animation(.easeOut(duration: 0.2), value: canContinue)
            }
        }
        .padding(.horizontal, 27)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .alert("Couldn’t send the code", isPresented: Binding(get: { sendError != nil }, set: { if !$0 { sendError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(sendError ?? "") }
        .alert("Couldn’t save your profile", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(saveError ?? "") }
    }

    /// The code was right. Someone who has signed up before gets their profile back and skips the rest.
    private func afterVerified() {
        guard let uid = auth.uid else { go(1); return }
        Task {
            if let remote = try? await service.loadProfile(uid: uid) {
                profile.restore(remote, phone: model.phone)
                onFinish()
            } else {
                go(1)
            }
        }
    }

    /// The last details are in: save the profile to the server, then show the "You're in" screen.
    private func saveProfile() {
        // Apple sign-in has no account on the server yet, so there is nothing to save.
        guard method == .phone, let uid = auth.uid else { go(1); return }
        sending = true
        Task {
            defer { sending = false }
            do {
                try await service.createProfile(uid: uid, username: model.username,
                                                first: model.first.trimmingCharacters(in: .whitespaces),
                                                last: model.last.trimmingCharacters(in: .whitespaces),
                                                birthday: model.birthday, photo: model.photo, method: method)
                go(1)
            } catch ProfileService.ProfileError.usernameTaken {
                // someone claimed it while this person was filling in the rest: back to pick another
                model.usernameFree = false
                if let i = steps.firstIndex(of: .username) { forward = false; withAnimation { index = i } }
                saveError = ProfileService.ProfileError.usernameTaken.errorDescription
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

    /// Texts the code, then moves on to the code screen.
    private func sendCode() {
        sending = true
        Task {
            defer { sending = false }
            do {
                try await auth.sendCode(toUSNumber: model.phone)
                go(1)
            } catch {
                sendError = error.localizedDescription
            }
        }
    }
}

// MARK: - pieces shared by the screens

private struct Shift: ViewModifier {
    var x: CGFloat
    func body(content: Content) -> some View {
        content.opacity(x == 0 ? 1 : 0).offset(x: x)
    }
}

struct CapsuleLabel: View {
    enum Style { case solid, outline }
    let title: String
    let style: Style
    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(style == .solid ? .white : .black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(style == .solid ? Color.black : Color.white, in: Capsule())
            .overlay { if style == .outline { Capsule().strokeBorder(.black.opacity(0.12), lineWidth: 1) } }
    }
}

struct StepHeader<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 32, weight: .heavy))
                .tracking(-0.96)
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.black.opacity(0.55))
                .padding(.top, 12)
                .fixedSize(horizontal: false, vertical: true)
            content.padding(.top, 28)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 27)
        .padding(.top, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum FieldState { case normal, bad, good }

/// A white rounded field that gets a black outline while it is focused.
struct FieldBox: ViewModifier {
    var focused: Bool
    var state: FieldState = .normal
    func body(content: Content) -> some View {
        let color: Color = switch state { case .bad: Color(red: 0.9, green: 0.28, blue: 0.3); case .good: Color(red: 0.18, green: 0.62, blue: 0.36); case .normal: .black }
        content
            .font(.system(size: 20, weight: .medium))
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(state == .normal && !focused ? .black.opacity(0.12) : color, lineWidth: state == .normal && !focused ? 1 : 2)
            }
            .animation(.easeOut(duration: 0.18), value: focused)
            .animation(.easeOut(duration: 0.18), value: state)
    }
}

private struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}

let errorColor = Color(red: 0.9, green: 0.28, blue: 0.3)
let goodColor = Color(red: 0.18, green: 0.62, blue: 0.36)

// MARK: - phone

struct PhoneStep: View {
    @Bindable var model: SignUpModel
    var title = "What’s your number?"
    var subtitle = "US numbers only for now. We’ll text you a code to check it’s you."
    @FocusState private var focused: Bool

    private static func format(_ d: String) -> String {
        var out = ""
        if !d.isEmpty { out = "(" + d.prefix(3) }
        if d.count >= 3 { out += ") " }
        if d.count > 3 { out += d.dropFirst(3).prefix(3) }
        if d.count > 6 { out += "-" + d.dropFirst(6).prefix(4) }
        return out
    }

    var body: some View {
        StepHeader(title: title, subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    HStack(spacing: 8) { Text("🇺🇸"); Text("+1").fontWeight(.semibold) }
                        .padding(.trailing, 12)
                        .frame(height: 28)
                        .overlay(alignment: .trailing) { Rectangle().fill(.black.opacity(0.12)).frame(width: 1) }
                    // A hidden field takes the typing; what you see is the number drawn as (555) 123-4567.
                    ZStack(alignment: .leading) {
                        TextField("", text: $model.phone)
                            .keyboardType(.numberPad)
                            .textContentType(.telephoneNumber)
                            .focused($focused)
                            .opacity(0.01)
                        HStack(spacing: 1) {
                            if model.phone.isEmpty {
                                Text("(555) 123-4567").foregroundStyle(.black.opacity(0.28))
                            } else {
                                Text(Self.format(model.phone))
                            }
                            if focused { Rectangle().fill(.blue).frame(width: 2, height: 24) }
                        }
                        .allowsHitTesting(false)
                    }
                }
                .modifier(FieldBox(focused: focused))
                .contentShape(.rect)
                .onTapGesture { focused = true }
                Text(model.phone.count == 10 ? "We’ll text a 6-digit code. Standard message rates may apply."
                                             : "We’ll only use this to sign you in. No one else will see it.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black.opacity(0.5))
                    .frame(minHeight: 44, alignment: .topLeading)
            }
        }
        .onAppear { focused = true }
        .onChange(of: model.phone) { _, new in
            let digits = String(new.filter(\.isNumber).prefix(10))
            if digits != new { model.phone = digits }
        }
    }
}

// MARK: - code

struct CodeStep: View {
    @Environment(AuthService.self) private var auth
    @Bindable var model: SignUpModel
    /// True when someone already signed in is adding or changing their number (Settings).
    var linking = false
    let onVerified: () -> Void
    @FocusState private var focused: Bool
    @State private var seconds = 30
    @State private var wrong = false
    @State private var shake: CGFloat = 0

    var body: some View {
        StepHeader(title: "Enter the code", subtitle: "Sent to +1 \(display)") {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    // one hidden field takes the typing (and the code from Messages); the boxes just show it
                    TextField("", text: $model.code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focused)
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                    HStack(spacing: 9) {
                        ForEach(0..<6, id: \.self) { i in
                            let chars = Array(model.code)
                            Text(i < chars.count ? String(chars[i]) : "")
                                .font(.system(size: 28, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(wrong ? errorColor : (i == chars.count && focused ? .black : .black.opacity(0.12)),
                                                      lineWidth: wrong || (i == chars.count && focused) ? 2 : 1)
                                }
                        }
                    }
                    .modifier(Shake(animatableData: shake))
                    .contentShape(.rect)
                    .onTapGesture { focused = true }
                }
                Group {
                    if wrong {
                        Text("That code isn’t right. Try again.").foregroundStyle(errorColor)
                    } else if seconds > 0 {
                        Text("Resend in 0:\(String(format: "%02d", seconds))").foregroundStyle(.black.opacity(0.5))
                    } else {
                        Button("Send a new code") {
                            seconds = 30; model.code = ""
                            Task { try? await auth.sendCode(toUSNumber: model.phone) }
                        }
                            .foregroundStyle(.black).underline()
                    }
                }
                .font(.system(size: 14, weight: .medium))
            }
        }
        .onAppear { model.code = ""; focused = true }
        .task(id: seconds) {
            guard seconds > 0 else { return }
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled { seconds -= 1 }
        }
        .onChange(of: model.code) { _, new in
            let digits = String(new.filter(\.isNumber).prefix(6))
            if digits != new { model.code = digits; return }
            wrong = false
            guard digits.count == 6 else { return }
            Task {
                do {
                    try await auth.verify(code: digits, linking: linking)
                    try? await Task.sleep(for: .milliseconds(250))
                    onVerified()
                } catch {
                    wrong = true
                    withAnimation(.linear(duration: 0.4)) { shake += 1 }
                    try? await Task.sleep(for: .milliseconds(700))
                    model.code = ""; wrong = false
                }
            }
        }
    }

    private var display: String {
        let d = model.phone
        guard d.count == 10 else { return d }
        return "(\(d.prefix(3))) \(d.dropFirst(3).prefix(3))-\(d.dropFirst(6))"
    }
}

// MARK: - name

struct NameStep: View {
    @Bindable var model: SignUpModel
    let onDone: () -> Void
    private enum Field { case first, last }
    @FocusState private var focus: Field?

    var body: some View {
        StepHeader(title: "What’s your name?", subtitle: "Only you and Bulletin can see this. It never shows on your board or to your friends.") {
            VStack(spacing: 12) {
                TextField("First name", text: $model.first)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focus, equals: .first)
                    .modifier(FieldBox(focused: focus == .first))
                    .onSubmit { focus = .last }
                TextField("Last name", text: $model.last)
                    .textContentType(.familyName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .focused($focus, equals: .last)
                    .modifier(FieldBox(focused: focus == .last))
                    .onSubmit(onDone)
            }
        }
        .onAppear { focus = model.first.isEmpty ? .first : .last }
    }
}

// MARK: - username

enum UsernameCheck: Equatable {
    case empty, short, checking, taken, free, offline

    /// Long enough and short enough. Whether it is free is the server's call (see `SignUpModel.usernameFree`).
    static func isUsable(_ name: String) -> Bool {
        SignUpModel.usernameRange.contains(name.count)
    }
}

struct UsernameStep: View {
    @Environment(AuthService.self) private var auth
    @Environment(ProfileService.self) private var service
    @Environment(ProfileStore.self) private var profile
    @Bindable var model: SignUpModel
    let onDone: () -> Void
    @FocusState private var focused: Bool
    @State private var check = UsernameCheck.empty
    @State private var notice: String?
    @State private var checking: Task<Void, Never>?

    var body: some View {
        StepHeader(title: "Pick a username", subtitle: "This is how friends find you. Letters, numbers and underscores. You can change it once a month.") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    Text("@").foregroundStyle(.black.opacity(0.35))
                    TextField("", text: $model.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.continue)
                        .focused($focused)
                        .onSubmit { if check == .free { onDone() } }
                }
                .modifier(FieldBox(focused: focused, state: fieldState))
                status.frame(minHeight: 70, alignment: .topLeading)
            }
        }
        .onAppear { focused = true; run() }
        .onChange(of: model.username) { old, new in
            // lowercase letters, numbers and underscores only, 3 to 20 long
            var clean = String(new.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") })
            var message: String?
            if new.contains(" ") { message = "No spaces in usernames." }
            else if clean.count != new.count { message = "Only letters, numbers and underscores." }
            if clean.count > SignUpModel.usernameRange.upperBound { clean = String(clean.prefix(SignUpModel.usernameRange.upperBound)); message = "20 characters is the most." }
            if clean != new { model.username = clean }
            if let message {
                notice = message
                Task { try? await Task.sleep(for: .seconds(1.6)); if notice == message { notice = nil } }
            }
            run()
        }
    }

    private var fieldState: FieldState {
        if notice != nil || check == .taken { return .bad }
        return check == .free ? .good : .normal
    }

    private func run() {
        checking?.cancel()
        let name = model.username
        model.usernameFree = false
        if name.isEmpty { check = .empty; return }
        if name.count < SignUpModel.usernameRange.lowerBound { check = .short; return }
        if name == profile.username { check = .free; model.usernameFree = true; return }      // keeping your own
        check = .checking
        checking = Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            do {
                let free = try await service.isUsernameFree(name, mine: auth.uid)
                guard !Task.isCancelled else { return }
                check = free ? .free : .taken
                model.usernameFree = free
            } catch {
                guard !Task.isCancelled else { return }
                check = .offline
            }
        }
    }

    @ViewBuilder private var status: some View {
        if let notice {
            Text(notice).font(.system(size: 14, weight: .medium)).foregroundStyle(errorColor)
        } else {
            switch check {
            case .empty:
                Text("Pick something you’d like on your board. 3 to 20 characters.").dim()
            case .short:
                Text("At least 3 characters.").dim()
            case .checking:
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Checking…") }.dim()
            case .offline:
                Text("Couldn’t check that name. Check your connection.").font(.system(size: 14, weight: .medium)).foregroundStyle(errorColor)
            case .free:
                Text("@\(model.username) is yours.").font(.system(size: 14, weight: .medium)).foregroundStyle(goodColor)
            case .taken:
                VStack(alignment: .leading, spacing: 10) {
                    Text("@\(model.username) is taken. Try one of these:")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(errorColor)
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { s in
                            Button { model.username = s } label: {
                                Text("@\(s)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 13).padding(.vertical, 7)
                                    .background(.white, in: Capsule())
                                    .overlay(Capsule().strokeBorder(.black.opacity(0.12), lineWidth: 1))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }
        }
    }

    /// Three free names close to the one that was taken.
    private var suggestions: [String] {
        let base = String(model.username.prefix(16))
        return [base + "_", base + "23", base + "_\(Int.random(in: 10...99))"]
            .map { String($0.prefix(20)) }
            .filter { !SignUpModel.taken.contains($0) }
    }
}

private extension View {
    func dim() -> some View {
        self.font(.system(size: 14, weight: .medium)).foregroundStyle(.black.opacity(0.5))
    }
}

// MARK: - photo

struct AvatarView: View {
    let photo: UIImage?
    let initial: String
    var size: CGFloat = 184
    var body: some View {
        ZStack {
            Circle().fill(.white)
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
            } else {
                Text(initial)
                    .font(.system(size: size * 0.39, weight: .heavy))
                    .tracking(-2)
                    .foregroundStyle(.black.opacity(0.18))
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 10)
    }
}

private struct PhotoStep: View {
    let model: SignUpModel
    @Binding var picker: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(title: "Add a photo", subtitle: "Friends see this next to your name. You can change it any time.") { EmptyView() }
                .frame(height: 150, alignment: .top)
            PhotosPicker(selection: $picker, matching: .images) {
                AvatarView(photo: model.photo, initial: model.initial)
                    .overlay(alignment: .bottomTrailing) {
                        if model.photo == nil {
                            Image(systemName: "camera")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.black, in: Circle())
                                .overlay(Circle().strokeBorder(Color("Paper"), lineWidth: 3))
                                .offset(x: -4, y: -4)
                        }
                    }
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 56)
            Text("@\(model.username)")
                .font(.system(size: 22, weight: .semibold))
                .padding(.top, 20)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - birthday

struct BirthdayStep: View {
    @Bindable var model: SignUpModel

    var body: some View {
        StepHeader(title: "Your birthday?", subtitle: "We use it to make sure you’re old enough. It’s never shown to anyone.") {
            VStack(spacing: 18) {
                DatePicker("Birthday", selection: $model.birthday, in: ...Date.now, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.black.opacity(0.12), lineWidth: 1))
                Group {
                    if model.isOldEnough {
                        Text(model.birthday.formatted(.dateTime.month(.wide).day().year())).foregroundStyle(.black.opacity(0.5))
                    } else {
                        Text("Bulletin is for people \(SignUpModel.minimumAge) and older.").foregroundStyle(errorColor)
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - done

private struct DoneStep: View {
    let model: SignUpModel
    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            AvatarView(photo: model.photo, initial: model.initial, size: 120)
                .scaleEffect(shown ? 1 : 0.8)
                .opacity(shown ? 1 : 0)
            Text("You’re in.")
                .font(.system(size: 40, weight: .heavy))
                .tracking(-1.2)
                .padding(.top, 26)
            Text("@\(model.username)")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.black.opacity(0.5))
                .padding(.top, 10)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear { withAnimation(.spring(duration: 0.6, bounce: 0.3)) { shown = true } }
    }
}

#Preview("Phone") { SignUpView(method: .phone, onBack: {}, onFinish: {}).environment(ProfileStore()).environment(AuthService()).environment(ProfileService()) }
#Preview("Apple") { SignUpView(method: .apple, onBack: {}, onFinish: {}).environment(ProfileStore()).environment(AuthService()).environment(ProfileService()) }
