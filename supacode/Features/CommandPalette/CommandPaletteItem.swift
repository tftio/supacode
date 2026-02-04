struct CommandPaletteItem: Identifiable, Equatable {
  let id: String
  let title: String
  let subtitle: String?
  let kind: Kind

  enum Kind: Equatable {
    case checkForUpdates
    case openRepository
    case worktreeSelect(Worktree.ID)
    case openSettings
    case newWorktree
    case removeWorktree(Worktree.ID, Repository.ID)
    case archiveWorktree(Worktree.ID, Repository.ID)
    case refreshWorktrees
  }

  var isGlobal: Bool {
    switch kind {
    case .checkForUpdates, .openRepository, .openSettings, .newWorktree, .refreshWorktrees:
      return true
    case .worktreeSelect, .removeWorktree, .archiveWorktree:
      return false
    }
  }
}
