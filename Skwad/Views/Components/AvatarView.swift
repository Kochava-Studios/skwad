import SwiftUI

struct AvatarView: View {
    let avatar: String?
    let size: CGFloat
    var font: Font = .largeTitle

    var body: some View {
        if let avatar = avatar, AvatarUtils.isDataURI(avatar),
           let image = AvatarUtils.parseImage(avatar) {
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
