import ComposableArchitecture
import Sparkle
import SupacodeSettingsShared

struct UpdaterClient {
  var configure: @MainActor @Sendable (_ checks: Bool, _ downloads: Bool, _ checkInBackground: Bool) -> Void
  var setUpdateChannel: @MainActor @Sendable (UpdateChannel) -> Void
  var checkForUpdates: @MainActor @Sendable () -> Void
}

@MainActor
class SparkleUpdateDelegate: NSObject, SPUUpdaterDelegate {
  var updateChannel: UpdateChannel = .stable

  nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
    MainActor.assumeIsolated {
      switch updateChannel {
      case .stable:
        []
      case .tip:
        ["tip"]
      }
    }
  }
}

extension UpdaterClient: DependencyKey {
  // Sparkle disabled in this build: liveValue is a no-op so the
  // SPUStandardUpdaterController is never constructed and no
  // network checks fire.
  static let liveValue = UpdaterClient(
    configure: { _, _, _ in },
    setUpdateChannel: { _ in },
    checkForUpdates: {},
  )

  static let testValue = UpdaterClient(
    configure: { _, _, _ in },
    setUpdateChannel: { _ in },
    checkForUpdates: {},
  )
}

extension DependencyValues {
  var updaterClient: UpdaterClient {
    get { self[UpdaterClient.self] }
    set { self[UpdaterClient.self] = newValue }
  }
}
