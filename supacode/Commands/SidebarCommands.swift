import Sharing
import SwiftUI

struct SidebarCommands: Commands {
  @FocusedValue(\.toggleLeftSidebarAction) private var toggleLeftSidebarAction
  @Shared(.settingsFile) private var settingsFile
  @Shared(.appStorage("worktreeRowDisplayMode")) private var displayMode: WorktreeRowDisplayMode = .branchFirst
  @Shared(.appStorage("worktreeRowHideSubtitleOnMatch")) private var hideSubtitleOnMatch = true

  var body: some Commands {
    let toggleLeftSidebar = AppShortcuts.toggleLeftSidebar.effective(from: settingsFile.global.shortcutOverrides)
    CommandGroup(replacing: .sidebar) {
      Button("Toggle Left Sidebar", systemImage: "sidebar.leading") {
        toggleLeftSidebarAction?()
      }
      .appKeyboardShortcut(toggleLeftSidebar)
      .help("Toggle Left Sidebar (\(toggleLeftSidebar?.display ?? "none"))")
      .disabled(toggleLeftSidebarAction == nil)
      Section {
        Picker("Title and Subtitle", systemImage: "textformat", selection: Binding($displayMode)) {
          ForEach(WorktreeRowDisplayMode.allCases) { mode in
            Text(mode.label).tag(mode)
          }
        }
        Toggle("Hide Subtitle on Match", isOn: Binding($hideSubtitleOnMatch))
      }
    }
  }
}

private struct ToggleLeftSidebarActionKey: FocusedValueKey {
  typealias Value = () -> Void
}

extension FocusedValues {
  var toggleLeftSidebarAction: (() -> Void)? {
    get { self[ToggleLeftSidebarActionKey.self] }
    set { self[ToggleLeftSidebarActionKey.self] = newValue }
  }
}
