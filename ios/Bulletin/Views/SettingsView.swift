import SwiftUI
import PhotosUI

/// SET-04: your profile. Change your photo, username (once a month), name and birthday, or add a phone number later,
/// for people who signed up with Apple. Reached from the picture at the top of the Shelf.
struct SettingsView: View {
    @Environment(ProfileStore.self) private var profile
    @Environment(AuthService.self) private var auth
    @Environment(ProfileService.self) private var service
    @Environment(\.dismiss) private var dismiss
    @State private var editing: ProfileField?
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ZStack(alignment: .top) {
            Color("Paper").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(spacing: 0) {
                        row("Username", value: profile.username.isEmpty ? "" : "@\(profile.username)", field: .username)
                        divider
                        row("Name", value: profile.fullName, field: .name)
                        divider
                        row("Birthday", value: profile.birthday?.formatted(.dateTime.month(.wide).day().year()) ?? "", field: .birthday)
                        divider
                        phoneRow
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.black.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.top, 34)

                    Text("Your username and photo are all anyone else sees. Your name, birthday and phone number stay private.")
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 44)
                        .padding(.top, 18)
                }
                .padding(.top, 70)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)

            topBar
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = MediaProcessor.avatar(from: data) {
                    withAnimation(.spring(duration: 0.4)) { profile.photo = image }
                    profile.save()
                    if let uid = auth.uid { try? await service.updatePhoto(uid: uid, photo: image) }
                }
            }
        }
        .fullScreenCover(item: $editing) { field in
            EditProfileView(field: field)
        }
    }

    // MARK: pieces

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(.white, in: Circle())
                    .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Back")
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(LinearGradient(colors: [Color("Paper"), Color("Paper").opacity(0)], startPoint: .center, endPoint: .bottom))
    }

    private var header: some View {
        VStack(spacing: 0) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                AvatarView(photo: profile.photo, initial: profile.initial, size: 112)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.black, in: Circle())
                            .overlay(Circle().strokeBorder(Color("Paper"), lineWidth: 2.5))
                    }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Change photo")
            Text(profile.username.isEmpty ? "Your profile" : "@\(profile.username)")
                .font(.system(size: 26, weight: .heavy))
                .tracking(-0.6)
                .padding(.top, 18)
        }
    }

    private var divider: some View {
        Rectangle().fill(.black.opacity(0.08)).frame(height: 1).padding(.leading, 18)
    }

    private func row(_ title: String, value: String, field: ProfileField) -> some View {
        Button { editing = field } label: {
            HStack(spacing: 12) {
                Text(title).font(.system(size: 17, weight: .medium))
                Spacer(minLength: 12)
                Text(value.isEmpty ? "Add" : value)
                    .font(.system(size: 17))
                    .foregroundStyle(.black.opacity(value.isEmpty ? 0.3 : 0.5))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.25))
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 58)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// Someone who signed up with Apple has no number yet. This row asks for one, and says why.
    private var phoneRow: some View {
        Button { editing = .phone } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text("Phone number").font(.system(size: 17, weight: .medium))
                    Spacer(minLength: 12)
                    Text(profile.hasPhone ? profile.formattedPhone : "Add a number")
                        .font(.system(size: 17, weight: profile.hasPhone ? .regular : .semibold))
                        .foregroundStyle(profile.hasPhone ? .black.opacity(0.5) : Color(red: 0, green: 0.471, blue: 0.988))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.25))
                }
                if !profile.hasPhone {
                    Text("So you can sign in and get your account back without Apple.")
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.45))
                        .padding(.trailing, 28)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .frame(minHeight: 58)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

enum ProfileField: String, Identifiable {
    case username, name, birthday, phone
    var id: String { rawValue }
}

// MARK: - editing one thing

/// One edit at a time, in the same screens sign-up used, so the rules match: the username is checked as you type,
/// the birthday has to be 13 or older, and a new phone number gets a code before it is saved.
struct EditProfileView: View {
    let field: ProfileField
    @Environment(ProfileStore.self) private var profile
    @Environment(AuthService.self) private var auth
    @Environment(ProfileService.self) private var service
    @Environment(\.dismiss) private var dismiss

    @State private var saving = false
    @State private var model = SignUpModel()
    @State private var sendError: String?
    @State private var saveError: String?
    @State private var sentCode = false
    @State private var ready = false

    var body: some View {
        ZStack(alignment: .top) {
            Color("Paper").ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { close() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(.white, in: Circle())
                            .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Close")
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)

                if ready { content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) }
                else { Spacer() }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        }
        .onAppear {
            // start from what is saved
            model.username = profile.username
            model.first = profile.first
            model.last = profile.last
            if let b = profile.birthday { model.birthday = b }
            model.phone = ""
            ready = true
        }
    }

    // MARK: what to show

    @ViewBuilder private var content: some View {
        switch field {
        case .username:
            if profile.canChangeUsername {
                UsernameStep(model: model, onDone: { if canSave { save() } })
            } else {
                StepHeader(title: "Username locked",
                           subtitle: "You changed your username recently. You can pick a new one on \(profile.nextUsernameChange?.formatted(.dateTime.month(.wide).day()) ?? "a later day").") { EmptyView() }
            }
        case .name:
            NameStep(model: model, onDone: { if canSave { save() } })
        case .birthday:
            BirthdayStep(model: model)
        case .phone:
            if sentCode {
                CodeStep(model: model, linking: true, onVerified: { save() })
            } else {
                PhoneStep(model: model,
                          title: profile.hasPhone ? "New number" : "Add your number",
                          subtitle: profile.hasPhone ? "US numbers only for now. We’ll text you a code to check it’s yours."
                                                     : "So you can sign in and get your account back without Apple. US numbers only for now.")
            }
        }
    }

    private var canSave: Bool {
        switch field {
        case .username:
            profile.canChangeUsername && UsernameCheck.isUsable(model.username) && model.usernameFree && model.username != profile.username
        case .name:
            !model.first.trimmingCharacters(in: .whitespaces).isEmpty && !model.last.trimmingCharacters(in: .whitespaces).isEmpty
        case .birthday:
            model.isOldEnough
        case .phone:
            model.phone.count == 10
        }
    }

    @ViewBuilder private var bottomBar: some View {
        Group {
            if field == .username && !profile.canChangeUsername {
                Button { close() } label: { CapsuleLabel(title: "Done", style: .solid) }.buttonStyle(PressableStyle())
            } else if field == .phone && sentCode {
                EmptyView()      // the code checks itself
            } else {
                Button {
                    if field == .phone {
                        Task {
                            do {
                                try await auth.sendCode(toUSNumber: model.phone)
                                withAnimation(.easeOut(duration: 0.25)) { sentCode = true }
                            } catch { sendError = error.localizedDescription }
                        }
                    } else { save() }
                } label: { CapsuleLabel(title: field == .phone ? "Send code" : "Save", style: .solid) }
                    .buttonStyle(PressableStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.22)
                    .animation(.easeOut(duration: 0.2), value: canSave)
            }
        }
        .padding(.horizontal, 27)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .alert("Couldn’t send the code", isPresented: Binding(get: { sendError != nil }, set: { if !$0 { sendError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(sendError ?? "") }
        .alert("Couldn’t save that", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(saveError ?? "") }
    }

    // MARK: saving

    /// Saves to the server first, then on the phone, so the two never disagree. The phone number was already
    /// attached to the account by the code check, so it only needs saving here.
    private func save() {
        guard !saving else { return }
        saving = true
        Task {
            defer { saving = false }
            do {
                let uid = auth.uid
                switch field {
                case .username:
                    if let uid { try await service.changeUsername(uid: uid, from: profile.username, to: model.username) }
                    profile.username = model.username
                    profile.usernameChangedAt = .now
                case .name:
                    let first = model.first.trimmingCharacters(in: .whitespaces), last = model.last.trimmingCharacters(in: .whitespaces)
                    if let uid { try await service.updateName(uid: uid, first: first, last: last) }
                    profile.first = first
                    profile.last = last
                case .birthday:
                    if let uid { try await service.updateBirthday(uid: uid, birthday: model.birthday) }
                    profile.birthday = model.birthday
                case .phone:
                    profile.phone = model.phone
                }
                profile.save()
                close()
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

    private func close() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        dismiss()
    }
}

#Preview("Settings") {
    SettingsView().environment(ProfileStore()).environment(AuthService()).environment(ProfileService())
}
