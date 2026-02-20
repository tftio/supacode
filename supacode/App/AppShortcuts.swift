import SwiftUI

struct AppShortcut {
  let keyEquivalent: KeyEquivalent
  let modifiers: EventModifiers
  private let ghosttyKeyName: String

  init(key: Character, modifiers: EventModifiers) {
    self.keyEquivalent = KeyEquivalent(key)
    self.modifiers = modifiers
    self.ghosttyKeyName = String(key).lowercased()
  }

  init(keyEquivalent: KeyEquivalent, ghosttyKeyName: String, modifiers: EventModifiers) {
    self.keyEquivalent = keyEquivalent
    self.modifiers = modifiers
    self.ghosttyKeyName = ghosttyKeyName
  }

  var keyboardShortcut: KeyboardShortcut {
    KeyboardShortcut(keyEquivalent, modifiers: modifiers)
  }

  var ghosttyKeybind: String {
    let parts = ghosttyModifierParts + [ghosttyKeyName]
    return parts.joined(separator: "+")
  }

  var ghosttyUnbindArgument: String {
    "--keybind=\(ghosttyKeybind)=unbind"
  }

  var display: String {
    let parts = displayModifierParts + [keyEquivalent.display]
    return parts.joined()
  }

  var displaySymbols: [String] {
    display.map { String($0) }
  }

  private var ghosttyModifierParts: [String] {
    var parts: [String] = []
    if modifiers.contains(.control) { parts.append("ctrl") }
    if modifiers.contains(.option) { parts.append("alt") }
    if modifiers.contains(.shift) { parts.append("shift") }
    if modifiers.contains(.command) { parts.append("super") }
    return parts
  }

  private var displayModifierParts: [String] {
    var parts: [String] = []
    if modifiers.contains(.command) { parts.append("⌘") }
    if modifiers.contains(.shift) { parts.append("⇧") }
    if modifiers.contains(.option) { parts.append("⌥") }
    if modifiers.contains(.control) { parts.append("⌃") }
    return parts
  }
}

enum AppShortcuts {
  static let newWorktree = AppShortcut(key: "n", modifiers: .command)
  static let openSettings = AppShortcut(key: ",", modifiers: .command)
  static let openFinder = AppShortcut(key: "o", modifiers: .command)
  static let copyPath = AppShortcut(key: "c", modifiers: [.command, .shift])
  static let openRepository = AppShortcut(key: "o", modifiers: [.command, .shift])
  static let openPullRequest = AppShortcut(key: "g", modifiers: [.command, .control])
  static let toggleLeftSidebar = AppShortcut(key: "[", modifiers: .command)
  static let refreshWorktrees = AppShortcut(key: "r", modifiers: [.command, .shift])
  static let runScript = AppShortcut(key: "r", modifiers: .command)
  static let stopRunScript = AppShortcut(key: ".", modifiers: .command)
  static let checkForUpdates = AppShortcut(key: "u", modifiers: .command)
  static let archivedWorktrees = AppShortcut(key: "a", modifiers: [.command, .control])
  static let selectNextWorktree = AppShortcut(
    keyEquivalent: .downArrow, ghosttyKeyName: "arrow_down", modifiers: [.command, .control]
  )
  static let selectPreviousWorktree = AppShortcut(
    keyEquivalent: .upArrow, ghosttyKeyName: "arrow_up", modifiers: [.command, .control]
  )
  static let selectWorktree1 = AppShortcut(key: "1", modifiers: .command)
  static let selectWorktree2 = AppShortcut(key: "2", modifiers: .command)
  static let selectWorktree3 = AppShortcut(key: "3", modifiers: .command)
  static let selectWorktree4 = AppShortcut(key: "4", modifiers: .command)
  static let selectWorktree5 = AppShortcut(key: "5", modifiers: .command)
  static let selectWorktree6 = AppShortcut(key: "6", modifiers: .command)
  static let selectWorktree7 = AppShortcut(key: "7", modifiers: .command)
  static let selectWorktree8 = AppShortcut(key: "8", modifiers: .command)
  static let selectWorktree9 = AppShortcut(key: "9", modifiers: .command)
  static let selectWorktree0 = AppShortcut(key: "0", modifiers: .command)
  static let worktreeSelection: [AppShortcut] = [
    selectWorktree1,
    selectWorktree2,
    selectWorktree3,
    selectWorktree4,
    selectWorktree5,
    selectWorktree6,
    selectWorktree7,
    selectWorktree8,
    selectWorktree9,
    selectWorktree0,
  ]

  static let tabSelectionGhosttyKeybindArguments: [String] = [
    "--keybind=ctrl+1=goto_tab:1",
    "--keybind=ctrl+2=goto_tab:2",
    "--keybind=ctrl+3=goto_tab:3",
    "--keybind=ctrl+4=goto_tab:4",
    "--keybind=ctrl+5=goto_tab:5",
    "--keybind=ctrl+6=goto_tab:6",
    "--keybind=ctrl+7=goto_tab:7",
    "--keybind=ctrl+8=goto_tab:8",
    "--keybind=ctrl+9=goto_tab:9",
    "--keybind=ctrl+0=goto_tab:10",
  ]

  static var ghosttyCLIKeybindArguments: [String] {
    all.map(\.ghosttyUnbindArgument) + tabSelectionGhosttyKeybindArguments
  }

  static let all: [AppShortcut] = [
    newWorktree,
    openSettings,
    openFinder,
    copyPath,
    openRepository,
    openPullRequest,
    toggleLeftSidebar,
    refreshWorktrees,
    runScript,
    stopRunScript,
    checkForUpdates,
    archivedWorktrees,
    selectNextWorktree,
    selectPreviousWorktree,
    selectWorktree1,
    selectWorktree2,
    selectWorktree3,
    selectWorktree4,
    selectWorktree5,
    selectWorktree6,
    selectWorktree7,
    selectWorktree8,
    selectWorktree9,
    selectWorktree0,
  ]
}
