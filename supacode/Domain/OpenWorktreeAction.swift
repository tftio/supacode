import AppKit

enum OpenWorktreeAction: CaseIterable, Identifiable {
  case finder
  case cursor
  case zed
  case ghostty

  var id: String { title }

  var title: String {
    switch self {
    case .finder: "Open Finder"
    case .cursor: "Cursor"
    case .zed: "Zed"
    case .ghostty: "Ghostty"
    }
  }

  var labelTitle: String {
    switch self {
    case .finder: "Finder"
    case .cursor, .zed, .ghostty: title
    }
  }

  var appIcon: NSImage? {
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    else { return nil }
    return NSWorkspace.shared.icon(forFile: appURL.path)
  }

  var settingsID: String {
    switch self {
    case .finder: "finder"
    case .cursor: "cursor"
    case .zed: "zed"
    case .ghostty: "ghostty"
    }
  }

  var bundleIdentifier: String {
    switch self {
    case .finder: "com.apple.finder"
    case .cursor: "com.todesktop.230313mzl4w4u92"
    case .zed: "dev.zed.Zed"
    case .ghostty: "com.mitchellh.ghostty"
    }
  }

  static func fromSettingsID(_ settingsID: String?) -> OpenWorktreeAction {
    switch settingsID {
    case OpenWorktreeAction.finder.settingsID: .finder
    case OpenWorktreeAction.cursor.settingsID: .cursor
    case OpenWorktreeAction.zed.settingsID: .zed
    case OpenWorktreeAction.ghostty.settingsID: .ghostty
    default: .finder
    }
  }

  func perform(with worktree: Worktree, onError: @escaping (OpenActionError) -> Void) {
    switch self {
    case .finder:
      NSWorkspace.shared.activateFileViewerSelecting([worktree.workingDirectory])
    case .cursor, .zed, .ghostty:
      guard
        let appURL = NSWorkspace.shared.urlForApplication(
          withBundleIdentifier: bundleIdentifier
        )
      else {
        onError(
          OpenActionError(
            title: "\(title) not found",
            message: "Install \(title) to open this worktree."
          )
        )
        return
      }
      let configuration = NSWorkspace.OpenConfiguration()
      NSWorkspace.shared.open(
        [worktree.workingDirectory],
        withApplicationAt: appURL,
        configuration: configuration
      ) { _, error in
        guard let error else { return }
        Task { @MainActor in
          onError(
            OpenActionError(
              title: "Unable to open in \(self.title)",
              message: error.localizedDescription
            )
          )
        }
      }
    }
  }
}
