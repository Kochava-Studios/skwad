import SwiftUI

struct AvatarView: View {
    let avatar: String?
    let size: CGFloat
    var font: Font = .largeTitle

    var body: some View {
        if let avatar = avatar, avatar.hasPrefix("data:image"),
           let image = avatarImage(from: avatar) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Text(avatar ?? "🤖")
                .font(font)
                .frame(width: size, height: size)
        }
    }

    private func avatarImage(from avatar: String) -> NSImage? {
        guard let commaIndex = avatar.firstIndex(of: ",") else { return nil }
        let base64String = String(avatar[avatar.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return NSImage(data: data)
    }
}

#Preview {
    HStack(spacing: 24) {
        AvatarView(avatar: "🤖", size: 40, font: .largeTitle)
        AvatarView(avatar: "🐱", size: 40, font: .largeTitle)
        AvatarView(avatar: nil, size: 40, font: .largeTitle)
        AvatarView(avatar: "🦊", size: 24, font: .title3)
        AvatarView(avatar: "🚀", size: 16, font: .body)
    }
    .padding()
}
