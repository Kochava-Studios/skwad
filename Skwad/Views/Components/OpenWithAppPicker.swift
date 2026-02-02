import SwiftUI

struct OpenWithAppPicker: View {
    let label: String
    @Binding var selection: String
    var iconSize: CGFloat = 18

    var body: some View {
        LabeledContent(label) {
            Picker("", selection: $selection) {
                Text("None").tag("")
                ForEach(availableOpenWithApps) { app in
                    OpenWithAppPickerContent(app: app, iconSize: iconSize)
                        .tag(app.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .font(.body)
        }
    }
}

struct OpenWithAppPickerContent: View {
    let app: OpenWithApp
    var iconSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 8) {
            iconView
            Text(" " + app.name)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = app.icon, let image = NSImage(named: icon) {
            let scaledImage = image.scalePreservingAspectRatio(
                targetSize: NSSize(width: iconSize, height: iconSize)
            )
            Image(nsImage: scaledImage)
        } else if let systemIcon = app.systemIcon {
            Image(systemName: systemIcon)
                .font(.system(size: iconSize))
                .frame(width: iconSize, height: iconSize)
        }
    }
}

#Preview {
    @Previewable @State var selection = "vscode"
    Form {
        OpenWithAppPicker(label: "Default Open With", selection: $selection)
    }
    .formStyle(.grouped)
    .frame(width: 400)
}
