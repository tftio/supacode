import SwiftUI

struct TerminalTabBarTrailingAccessories: View {
  let createTab: () -> Void

  @Environment(GhosttyShortcutManager.self)
  private var ghosttyShortcuts
  @Environment(CommandKeyObserver.self)
  private var commandKeyObserver

  var body: some View {
    Button {
      createTab()
    } label: {
      if commandKeyObserver.isPressed {
        HStack(spacing: TerminalTabBarMetrics.contentSpacing) {
          Text("New Tab")
            .font(.caption)
          if let shortcut = ghosttyShortcuts.display(for: "new_tab") {
            ShortcutHintView(text: shortcut, color: TerminalTabBarColors.inactiveText)
          }
        }
      } else {
        Label("New Tab", systemImage: "plus")
          .labelStyle(.iconOnly)
      }
    }
    .buttonStyle(.borderless)
    .help(helpText("New Tab", shortcut: ghosttyShortcuts.display(for: "new_tab")))
    .frame(height: TerminalTabBarMetrics.barHeight)
    .padding(.trailing, 8)
  }

  private func helpText(_ title: String, shortcut: String?) -> String {
    guard let shortcut else { return title }
    return "\(title) (\(shortcut))"
  }
}
