import ComposableArchitecture
import Sparkle

nonisolated struct UpdaterClient: @unchecked Sendable {
  var configure: @MainActor (_ checks: Bool, _ downloads: Bool, _ checkInBackground: Bool) -> Void
  var checkForUpdates: @MainActor () -> Void
}

@MainActor
private enum SparkleUpdater {
  static let controller = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
  )
  static var updater: SPUUpdater { controller.updater }
}

nonisolated extension UpdaterClient: DependencyKey {
  static let liveValue = UpdaterClient(
    configure: { checks, downloads, checkInBackground in
      let updater = SparkleUpdater.updater
      updater.automaticallyChecksForUpdates = checks
      updater.automaticallyDownloadsUpdates = downloads
      if checkInBackground, checks {
        updater.checkForUpdatesInBackground()
      }
    },
    checkForUpdates: {
      SparkleUpdater.updater.checkForUpdates()
    }
  )

  static let testValue = UpdaterClient(
    configure: { _, _, _ in },
    checkForUpdates: { }
  )
}

extension DependencyValues {
  nonisolated var updaterClient: UpdaterClient {
    get { self[UpdaterClient.self] }
    set { self[UpdaterClient.self] = newValue }
  }
}
