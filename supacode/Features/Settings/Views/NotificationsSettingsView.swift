import ComposableArchitecture
import SwiftUI

struct NotificationsSettingsView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  var body: some View {
    VStack(alignment: .leading) {
      Form {
        Section("Notifications") {
          Toggle(
            "Show bell icon next to worktree",
            isOn: Binding(
              get: { store.inAppNotificationsEnabled },
              set: { store.send(.setInAppNotificationsEnabled($0)) }
            )
          )
          .help("Show bell icon next to worktree (no shortcut)")
          Toggle(
            "Play notification sound",
            isOn: Binding(
              get: { store.notificationSoundEnabled },
              set: { store.send(.setNotificationSoundEnabled($0)) }
            )
          )
          .help("Play a sound when a notification is received (no shortcut)")
        }
      }
      .formStyle(.grouped)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}
