import SwiftUI
import PhotosUI
import UIKit

@Observable
final class ProfileStore {
    static let shared = ProfileStore()

    var image: UIImage?
    var name: String {
        didSet { UserDefaults.standard.set(name, forKey: "profileName") }
    }

    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("profile.jpg")

    private init() {
        name = UserDefaults.standard.string(forKey: "profileName") ?? "Berat"
        if let data = try? Data(contentsOf: url) {
            image = UIImage(data: data)
        }
    }

    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func setImage(_ newImage: UIImage?) {
        guard let newImage else {
            image = nil
            try? FileManager.default.removeItem(at: url)
            return
        }
        let small = newImage.squareThumbnail(side: 600)
        image = small
        if let data = small.jpegData(compressionQuality: 0.85) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

extension UIImage {
    func squareThumbnail(side: CGFloat) -> UIImage {
        let shortest = min(size.width, size.height)
        guard shortest > 0 else { return self }
        let scale = side / shortest
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(x: (side - drawSize.width) / 2, y: (side - drawSize.height) / 2)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            self.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}

struct AvatarView: View {
    @Environment(ProfileStore.self) private var profile
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let image = profile.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.loz
                    if let first = profile.displayName.first {
                        Text(String(first).uppercased(with: Locale(identifier: "tr_TR")))
                            .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.42))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .accessibilityLabel("Profil fotoğrafı")
    }
}

/// Wraps any label in a photo picker that sets the profile photo.
struct ProfilePhotoPicker<Label: View>: View {
    @Environment(ProfileStore.self) private var profile
    @State private var item: PhotosPickerItem?
    private let label: () -> Label

    init(@ViewBuilder label: @escaping () -> Label) {
        self.label = label
    }

    var body: some View {
        PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
            label()
        }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run { profile.setImage(img) }
                }
                await MainActor.run { item = nil }
            }
        }
    }
}

struct ProfileSection: View {
    @Environment(ProfileStore.self) private var profile

    var body: some View {
        @Bindable var profile = profile
        Section {
            HStack(spacing: 16) {
                ProfilePhotoPicker {
                    AvatarView(size: 64)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.loz)
                                .font(.title3)
                                .offset(x: 2, y: 2)
                        }
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Adın", text: $profile.name)
                        .font(.title3.weight(.semibold))
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                    ProfilePhotoPicker {
                        Text(profile.image == nil ? "Fotoğraf seç" : "Fotoğrafı değiştir")
                            .font(.subheadline)
                    }
                }
            }
            .padding(.vertical, 4)
            if profile.image != nil {
                Button("Fotoğrafı kaldır", role: .destructive) {
                    profile.setImage(nil)
                }
            }
        } header: {
            Text("Profil")
        } footer: {
            Text("Adın selamlamada ve sabah bildiriminde kullanılır. Fotoğraf yalnızca bu telefonda saklanır.")
        }
    }
}
