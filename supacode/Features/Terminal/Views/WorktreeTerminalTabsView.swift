import AppKit
import OSLog
import SwiftUI

private let logger = Logger(
  subsystem: Bundle.main.bundleIdentifier!,
  category: "TabsView"
)

struct WorktreeTerminalTabsView: View {
  let worktree: Worktree
  let manager: WorktreeTerminalManager
  let shouldRunSetupScript: Bool
  let forceAutoFocus: Bool
  let createTab: () -> Void

  var body: some View {
    let state = manager.state(for: worktree) { shouldRunSetupScript }
    VStack(spacing: 0) {
      TerminalTabBarView(
        manager: state.tabManager,
        createTab: createTab,
        closeTab: { tabId in
          state.closeTab(tabId)
        },
        closeOthers: { tabId in
          state.closeOtherTabs(keeping: tabId)
        },
        closeToRight: { tabId in
          state.closeTabsToRight(of: tabId)
        },
        closeAll: {
          state.closeAllTabs()
        }
      )
      if let selectedId = state.tabManager.selectedTabId {
        TerminalTabContentStack(tabs: state.tabManager.tabs, selectedTabId: selectedId) { tabId in
          TerminalSplitTreeView(tree: state.splitTree(for: tabId)) { operation in
            state.performSplitOperation(operation, in: tabId)
          }
        }
      } else {
        EmptyTerminalPaneView(message: "No terminals open")
      }
    }
    .background(
      WindowFocusObserverView { isKey in
        logger.debug("[WindowFocusObserver] isKey=\(isKey)")
        state.syncFocus(windowIsKey: isKey)
      }
    )
    .onAppear {
      state.ensureInitialTab(focusing: false)
      if shouldAutoFocusTerminal {
        state.focusSelectedTab()
      }
    }
    .onChange(of: state.tabManager.selectedTabId) { _, newTabId in
      let autoFocus = shouldAutoFocusTerminal
      let firstResponder = NSApp.keyWindow?.firstResponder
      let frDesc =
        (firstResponder as? GhosttySurfaceView)?.shortId ?? String(describing: type(of: firstResponder))
      logger.debug(
        "[onChange selectedTabId] newTabId=\(newTabId.map { String($0.rawValue.uuidString.prefix(6)) } ?? "nil") autoFocus=\(autoFocus) firstResponder=\(frDesc)"
      )
      if autoFocus {
        state.focusSelectedTab()
      }
      state.syncFocus(windowIsKey: NSApp.keyWindow?.isKeyWindow ?? false)
    }
  }

  private var shouldAutoFocusTerminal: Bool {
    if forceAutoFocus {
      return true
    }
    guard let responder = NSApp.keyWindow?.firstResponder else { return true }
    return !(responder is NSTableView) && !(responder is NSOutlineView)
  }
}
