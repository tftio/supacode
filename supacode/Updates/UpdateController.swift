import Observation
import Sparkle

@MainActor
@Observable
final class UpdateController {
  private let updaterController: SPUStandardUpdaterController
  private let updater: SPUUpdater
  private let settings: SettingsModel

  var automaticallyChecksForUpdates: Bool {
    get { updater.automaticallyChecksForUpdates }
    set {
      updater.automaticallyChecksForUpdates = newValue
      settings.updatesAutomaticallyCheckForUpdates = newValue
    }
  }

  var automaticallyDownloadsUpdates: Bool {
    get { updater.automaticallyDownloadsUpdates }
    set {
      updater.automaticallyDownloadsUpdates = newValue
      settings.updatesAutomaticallyDownloadUpdates = newValue
    }
  }

  init(settings: SettingsModel) {
    self.settings = settings
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
    updater = updaterController.updater
    updater.automaticallyChecksForUpdates = settings.updatesAutomaticallyCheckForUpdates
    updater.automaticallyDownloadsUpdates = settings.updatesAutomaticallyDownloadUpdates
    if updater.automaticallyChecksForUpdates {
      updater.checkForUpdatesInBackground()
    }
  }

  func checkForUpdates() {
    updater.checkForUpdates()
  }
}
