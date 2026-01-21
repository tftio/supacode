nonisolated struct GlobalSettings: Codable, Equatable {
  var appearanceMode: AppearanceMode

  static let `default` = GlobalSettings(appearanceMode: .system)
}
