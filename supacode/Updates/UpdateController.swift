import Observation
import Sparkle

@MainActor
@Observable
final class UpdateController {
  private let updaterController: SPUStandardUpdaterController
  private let updater: SPUUpdater

  var automaticallyChecksForUpdates: Bool {
    get { updater.automaticallyChecksForUpdates }
    set { updater.automaticallyChecksForUpdates = newValue }
  }

  var automaticallyDownloadsUpdates: Bool {
    get { updater.automaticallyDownloadsUpdates }
    set { updater.automaticallyDownloadsUpdates = newValue }
  }

  init() {
    updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    updater = updaterController.updater
    if updater.automaticallyChecksForUpdates {
      updater.checkForUpdatesInBackground()
    }
  }

  func checkForUpdates() {
    updater.checkForUpdates()
  }
}
