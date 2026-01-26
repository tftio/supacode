import ComposableArchitecture
import SwiftUI

struct WorktreeDetailView: View {
  @Bindable var store: StoreOf<AppFeature>
  let terminalManager: WorktreeTerminalManager
  @Environment(CommandKeyObserver.self) private var commandKeyObserver

  var body: some View {
    detailBody(state: store.state)
  }

  @ViewBuilder
  private func detailBody(state: AppFeature.State) -> some View {
    let repositories = state.repositories
    let selectedRow = repositories.selectedRow(for: repositories.selectedWorktreeID)
    let selectedWorktree = repositories.worktree(for: repositories.selectedWorktreeID)
    let loadingInfo = loadingInfo(for: selectedRow, repositories: repositories)
    let isOpenDisabled = selectedWorktree == nil || loadingInfo != nil
    let openActionSelection = state.openActionSelection
    let openSelectedWorktreeAction: (() -> Void)? = isOpenDisabled
      ? nil
      : { store.send(.openSelectedWorktree) }
    let newTerminalAction: (() -> Void)? = isOpenDisabled
      ? nil
      : { store.send(.newTerminal) }
    let closeTabAction: (() -> Void)? = isOpenDisabled
      ? nil
      : { store.send(.closeTab) }
    let closeSurfaceAction: (() -> Void)? = isOpenDisabled
      ? nil
      : { store.send(.closeSurface) }
    Group {
      if let loadingInfo {
        WorktreeLoadingView(info: loadingInfo)
      } else if let selectedWorktree {
        let shouldRunSetupScript = repositories.pendingSetupScriptWorktreeIDs.contains(selectedWorktree.id)
        WorktreeTerminalTabsView(
          worktree: selectedWorktree,
          manager: terminalManager,
          shouldRunSetupScript: shouldRunSetupScript,
          createTab: { store.send(.newTerminal) }
        )
        .id(selectedWorktree.id)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
          if shouldRunSetupScript {
            store.send(.repositories(.consumeSetupScript(selectedWorktree.id)))
          }
        }
      } else {
        EmptyStateView(store: store.scope(state: \.repositories, action: \.repositories))
      }
    }
    .navigationTitle(selectedWorktree?.name ?? loadingInfo?.name ?? "Supacode")
    .toolbar {
      openToolbar(
        isOpenDisabled: isOpenDisabled,
        openActionSelection: openActionSelection,
        showExtras: commandKeyObserver.isPressed
      )
    }
    .focusedSceneValue(\.newTerminalAction, newTerminalAction)
    .focusedSceneValue(\.closeTabAction, closeTabAction)
    .focusedSceneValue(\.closeSurfaceAction, closeSurfaceAction)
    .focusedSceneValue(\.openSelectedWorktreeAction, openSelectedWorktreeAction)
  }

  private func loadingInfo(
    for selectedRow: WorktreeRowModel?,
    repositories: RepositoriesFeature.State
  ) -> WorktreeLoadingInfo? {
    guard let selectedRow else { return nil }
    let repositoryName = repositories.repositoryName(for: selectedRow.repositoryID)
    if selectedRow.isDeleting {
      return WorktreeLoadingInfo(
        name: selectedRow.name,
        repositoryName: repositoryName,
        state: .removing
      )
    }
    if selectedRow.isPending {
      return WorktreeLoadingInfo(
        name: selectedRow.name,
        repositoryName: repositoryName,
        state: .creating
      )
    }
    return nil
  }

  @ToolbarContentBuilder
  private func openToolbar(
    isOpenDisabled: Bool,
    openActionSelection: OpenWorktreeAction,
    showExtras: Bool
  ) -> some ToolbarContent {
    if !isOpenDisabled {
      ToolbarItemGroup(placement: .primaryAction) {
        openMenu(openActionSelection: openActionSelection, showExtras: showExtras)
      }
    }
  }

  @ViewBuilder
  private func openMenu(openActionSelection: OpenWorktreeAction, showExtras: Bool) -> some View {
    HStack(spacing: 0) {
      Button {
        store.send(.openWorktree(openActionSelection))
      } label: {
        OpenWorktreeActionMenuLabelView(
          action: openActionSelection,
          shortcutHint: showExtras ? AppShortcuts.openFinder.display : nil
        )
      }
      .buttonStyle(.borderless)
      .padding(8)
      .help(openActionHelpText(for: openActionSelection, isDefault: true))

      Divider()
        .frame(height: 16)

      Menu {
        ForEach(OpenWorktreeAction.allCases) { action in
          let isDefault = action == openActionSelection
          Button {
            store.send(.openActionSelectionChanged(action))
            store.send(.openWorktree(action))
          } label: {
            OpenWorktreeActionMenuLabelView(action: action, shortcutHint: nil)
          }
          .buttonStyle(.plain)
          .help(openActionHelpText(for: action, isDefault: isDefault))
        }
      } label: {
        Image(systemName: "chevron.down")
          .font(.system(size: 8))
          .accessibilityLabel("Open in menu")
      }
      .buttonStyle(.borderless)
      .padding(8)
      .imageScale(.small)
      .menuIndicator(.hidden)
      .fixedSize()
      .help("Open in... (no shortcut)")
    }
  }

  private func openActionHelpText(for action: OpenWorktreeAction, isDefault: Bool) -> String {
    isDefault
      ? "\(action.title) (\(AppShortcuts.openFinder.display))"
      : action.title
  }
}
