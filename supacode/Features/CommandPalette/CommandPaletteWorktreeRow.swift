import Foundation

struct CommandPaletteWorktreeRow: Identifiable, Equatable {
  let id: Worktree.ID
  let title: String
  let subtitle: String?
}
