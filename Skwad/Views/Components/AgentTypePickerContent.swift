import SwiftUI

struct AgentTypePickerContent: View {
    let agent: AgentCommandOption
    var iconSize: CGFloat = 6

    var body: some View {
        HStack(spacing: 8) {
            iconView
            Text(" " + agent.name)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = agent.icon, let image = NSImage(named: icon) {
            let scaledImage = image.scalePreservingAspectRatio(
                targetSize: NSSize(width: iconSize, height: iconSize)
            )
            Image(nsImage: scaledImage)
        } else if let systemIcon = agent.systemIcon {
            Image(systemName: systemIcon)
                .font(.system(size: iconSize))
                .frame(width: iconSize, height: iconSize)
        }
    }
}
