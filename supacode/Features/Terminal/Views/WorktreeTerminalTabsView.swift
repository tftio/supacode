import Bonsplit
import SwiftUI

struct WorktreeTerminalTabsView: View {
  let worktree: Worktree
  let manager: WorktreeTerminalManager
  let shouldRunSetupScript: Bool
  let createTab: () -> Void
  @Environment(GhosttyShortcutManager.self) private var ghosttyShortcuts

  var body: some View {
    let state = manager.state(for: worktree) { shouldRunSetupScript }
    let newTabShortcut = ghosttyShortcuts.display(for: "new_tab")
    ZStack(alignment: .topLeading) {
      BonsplitView(
        controller: state.controller,
        content: { tab, _ in
          TerminalSplitTreeView(tree: state.splitTree(for: tab.id)) { operation in
            state.performSplitOperation(operation, in: tab.id)
          }
        },
        emptyPane: { _ in
          EmptyTerminalPaneView(message: "No terminals open")
        }
      )
      .overlay(alignment: .topTrailing) {
        Button("New Terminal", systemImage: "plus") {
          createTab()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help(helpText("New Terminal", shortcut: newTabShortcut))
        .frame(height: state.controller.configuration.appearance.tabBarHeight)
        .padding(.trailing)
      }
    }
    .onAppear {
      state.ensureInitialTab()
    }
  }

  private func helpText(_ title: String, shortcut: String?) -> String {
    guard let shortcut else { return "\(title) (no shortcut)" }
    return "\(title) (\(shortcut))"
  }
}
