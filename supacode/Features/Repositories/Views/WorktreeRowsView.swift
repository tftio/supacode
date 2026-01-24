import ComposableArchitecture
import SwiftUI

struct WorktreeRowsView: View {
  let repository: Repository
  let isExpanded: Bool
  @Bindable var store: StoreOf<RepositoriesFeature>
  let terminalManager: WorktreeTerminalManager

  var body: some View {
    if isExpanded {
      let state = store.state
      let rows = state.worktreeRows(in: repository)
      let isRepositoryRemoving = state.isRemovingRepository(repository)
      ForEach(rows) { row in
        rowView(row, isRepositoryRemoving: isRepositoryRemoving)
      }
    }
  }

  @ViewBuilder
  private func rowView(_ row: WorktreeRowModel, isRepositoryRemoving: Bool) -> some View {
    let taskStatus = terminalManager.focusedTaskStatus(for: row.id)
    if row.isRemovable, let worktree = store.state.worktree(for: row.id), !isRepositoryRemoving {
      WorktreeRow(
        name: row.name,
        isPinned: row.isPinned,
        isMainWorktree: row.isMainWorktree,
        isLoading: row.isPending || row.isDeleting,
        taskStatus: taskStatus
      )
      .tag(SidebarSelection.worktree(row.id))
      .contextMenu {
        if row.isPinned {
          Button("Unpin") {
            store.send(.unpinWorktree(worktree.id))
          }
          .help("Unpin (no shortcut)")
        } else {
          Button("Pin to top") {
            store.send(.pinWorktree(worktree.id))
          }
          .help("Pin to top (no shortcut)")
        }
        Button("Remove") {
          store.send(.requestRemoveWorktree(worktree.id, repository.id))
        }
        .help(row.isMainWorktree ? "Main worktree can't be removed" : "Remove worktree (⌘⌫)")
        .disabled(row.isMainWorktree)
      }
    } else {
      WorktreeRow(
        name: row.name,
        isPinned: row.isPinned,
        isMainWorktree: row.isMainWorktree,
        isLoading: row.isPending || row.isDeleting,
        taskStatus: taskStatus
      )
      .tag(SidebarSelection.worktree(row.id))
      .disabled(isRepositoryRemoving)
    }
  }
}
