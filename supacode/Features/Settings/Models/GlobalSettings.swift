nonisolated struct GlobalSettings: Codable, Equatable, Sendable {
  var appearanceMode: AppearanceMode
  var updatesAutomaticallyCheckForUpdates: Bool
  var updatesAutomaticallyDownloadUpdates: Bool

  static let `default` = GlobalSettings(
    appearanceMode: .system,
    updatesAutomaticallyCheckForUpdates: true,
    updatesAutomaticallyDownloadUpdates: false
  )
}
