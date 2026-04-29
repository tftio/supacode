public nonisolated enum WorktreeDirectoryNaming: String, Codable, CaseIterable, Equatable, Hashable, Identifiable,
  Sendable
{
  case preserveBranchPath
  case replaceSlashesWithUnderscores

  public var id: String { rawValue }

  public var label: String {
    switch self {
    case .preserveBranchPath:
      "Preserve branch path"
    case .replaceSlashesWithUnderscores:
      "Replace / with _"
    }
  }

  public var helpText: String {
    switch self {
    case .preserveBranchPath:
      "Use branch names as worktree directory names."
    case .replaceSlashesWithUnderscores:
      "Replace slashes in branch names so new worktrees are created as peer directories."
    }
  }

  public func worktreeName(for branchName: String) -> String {
    switch self {
    case .preserveBranchPath:
      branchName
    case .replaceSlashesWithUnderscores:
      branchName.replacing("/", with: "_")
    }
  }
}
