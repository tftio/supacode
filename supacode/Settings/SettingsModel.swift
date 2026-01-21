import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsModel {
  private let store: SettingsStore
  private var settings: GlobalSettings

  var appearanceMode: AppearanceMode {
    get {
      settings.appearanceMode
    }
    set {
      settings.appearanceMode = newValue
      store.save(settings)
    }
  }

  var preferredColorScheme: ColorScheme? {
    appearanceMode.colorScheme
  }

  init(store: SettingsStore = SettingsStore()) {
    self.store = store
    settings = store.load()
  }
}
