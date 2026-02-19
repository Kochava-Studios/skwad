import SwiftUI
import Sparkle

struct GeneralSettingsView: View {
  @ObservedObject private var settings = AppSettings.shared
  private let updater = UpdaterManager.shared.updater
  @State private var automaticallyChecksForUpdates: Bool = true

  private var appearanceFooter: String {
    AppearanceMode(rawValue: settings.appearanceMode)?.footerDescription ?? ""
  }

  var body: some View {
    Form {
      Section {
        Picker("Appearance", selection: $settings.appearanceMode) {
          ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
            Text(mode.displayName).tag(mode.rawValue)
          }
        }
      } header: {
        Text("Appearance")
      } footer: {
        Text(appearanceFooter)
          .foregroundColor(.secondary)
      }

      Section {
        Toggle("Restore agents on launch", isOn: $settings.restoreLayoutOnLaunch)
        Toggle("Keep running in menu bar when closed", isOn: $settings.keepInMenuBar)
      } header: {
        Text("Startup")
      } footer: {
        if settings.keepInMenuBar {
          Text("Closing the window or pressing ⌘Q will hide Skwad to the menu bar. Click the menu bar icon to show the window, Right-click to show the menu.")
            .foregroundColor(.secondary)
        }
      }

      Section {
        Toggle("Desktop notifications", isOn: $settings.desktopNotificationsEnabled)
      } header: {
        Text("Notifications")
      } footer: {
        Text("Show a macOS notification when an agent needs your attention (e.g. permission prompt).")
          .foregroundColor(.secondary)
      }

      Section {
        Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
          .onChange(of: automaticallyChecksForUpdates) { _, newValue in
            updater.automaticallyChecksForUpdates = newValue
          }
      } header: {
        Text("Updates")
      }

    }
    .formStyle(.grouped)
    .scrollDisabled(true)
    .padding()
    .onAppear {
      automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
    }
  }
}
