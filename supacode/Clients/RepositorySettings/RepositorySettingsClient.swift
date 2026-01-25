import ComposableArchitecture
import Foundation

nonisolated struct RepositorySettingsClient: Sendable {
  var load: @Sendable (URL) -> RepositorySettings
  var save: @Sendable (_ settings: RepositorySettings, _ rootURL: URL) -> Void
}

nonisolated extension RepositorySettingsClient: DependencyKey {
  static let liveValue = RepositorySettingsClient(
    load: { RepositorySettingsStorage().load(for: $0) },
    save: { settings, url in
      RepositorySettingsStorage().save(settings, for: url)
    }
  )
  static let testValue = RepositorySettingsClient(
    load: { _ in .default },
    save: { _, _ in }
  )
}

extension DependencyValues {
  nonisolated var repositorySettingsClient: RepositorySettingsClient {
    get { self[RepositorySettingsClient.self] }
    set { self[RepositorySettingsClient.self] = newValue }
  }
}
