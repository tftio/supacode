import Foundation

nonisolated struct SettingsStore {
  let settingsURL: URL

  init(settingsURL: URL = SupacodePaths.settingsURL) {
    self.settingsURL = settingsURL
  }

  func load() -> GlobalSettings {
    if let data = try? Data(contentsOf: settingsURL),
      let settings = try? JSONDecoder().decode(GlobalSettings.self, from: data)
    {
      return settings
    }
    let defaults = GlobalSettings.default
    save(defaults)
    return defaults
  }

  func save(_ settings: GlobalSettings) {
    do {
      let directory = settingsURL.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(settings)
      try data.write(to: settingsURL, options: [.atomic])
    } catch {
    }
  }
}
