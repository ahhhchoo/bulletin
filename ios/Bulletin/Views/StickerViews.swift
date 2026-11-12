import SwiftUI
import PhotosUI

// MARK: - Stickers

struct StickerView: View {
    let sticker: Sticker
    var size: CGFloat = 72

    var body: some View {
        Group {
            if let image = sticker.image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if let symbol = sticker.symbol {
                ZStack {
                    // a white edge, like a die-cut sticker
                    Image(systemName: symbol).font(.system(size: size * 0.7, weight: .black))
                        .foregroundStyle(.white).scaleEffect(1.22)
                    Image(systemName: symbol).font(.system(size: size * 0.7, weight: .black))
                        .foregroundStyle(sticker.tint ?? .black)
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
    }
}

/// Pick which sticker is in the dock, or make a new one from a photo.
/// (Not on any screen right now: stickers will come back inside the notes layer.)
struct StickerTray: View {
    @Environment(StickerStore.self) private var stickers
    @Environment(\.dismiss) private var dismiss
    @State private var pick: PhotosPickerItem?
    @State private var making = false
    @State private var errorText: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Stickers").font(.system(size: 22, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }.font(.system(size: 16, weight: .semibold))
            }
            PhotosPicker(selection: $pick, matching: .images) {
                HStack(spacing: 10) {
                    if making { ProgressView() } else { Image(systemName: "person.crop.circle.badge.plus") }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Make one from a photo").font(.system(size: 15, weight: .semibold))
                        Text("We’ll lift the person or thing out for you").font(.footnote).foregroundStyle(.black.opacity(0.5))
                    }
                    Spacer()
                }
                .foregroundStyle(.black)
                .padding(14)
                .background(Color("CardPrompt"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(making)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(stickers.all) { s in
                        Button { stickers.selected = s; dismiss() } label: {
                            StickerView(sticker: s, size: 56)
                                .frame(maxWidth: .infinity).frame(height: 76)
                                .background(.black.opacity(stickers.selected == s ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.black.opacity(stickers.selected == s ? 0.5 : 0), lineWidth: 1.5))
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu {
                            if s.isMine { Button("Delete", systemImage: "trash", role: .destructive) { stickers.remove(s) } }
                        }
                    }
                }
            }
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .presentationBackground(.white)
        .onChange(of: pick) { _, item in
            guard let item else { return }
            making = true
            Task {
                defer { making = false; pick = nil }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw StickerMaker.Failure.unreadable }
                    let cut = try await StickerMaker.cutout(from: data)
                    stickers.add(cutout: cut)
                } catch {
                    errorText = (error as? LocalizedError)?.errorDescription ?? "Couldn’t make a sticker from that photo."
                }
            }
        }
        .alert("No sticker", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorText ?? "") }
    }
}
