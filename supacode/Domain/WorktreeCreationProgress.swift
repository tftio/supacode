nonisolated struct WorktreeCreationProgress: Hashable, Sendable {
  var stage: WorktreeCreationStage
  var worktreeName: String?
  var baseRef: String?
  var copyIgnored: Bool?
  var copyUntracked: Bool?

  init(
    stage: WorktreeCreationStage,
    worktreeName: String? = nil,
    baseRef: String? = nil,
    copyIgnored: Bool? = nil,
    copyUntracked: Bool? = nil
  ) {
    self.stage = stage
    self.worktreeName = worktreeName
    self.baseRef = baseRef
    self.copyIgnored = copyIgnored
    self.copyUntracked = copyUntracked
  }

  var titleText: String {
    if let worktreeName, !worktreeName.isEmpty {
      return "Creating \(worktreeName)"
    }
    return "Creating worktree"
  }

  var detailText: String {
    switch stage {
    case .loadingLocalBranches:
      return "Reading local branches"
    case .choosingWorktreeName:
      return "Choosing available worktree name"
    case .checkingRepositoryMode:
      return "Checking repository mode"
    case .resolvingBaseReference:
      return "Resolving base reference (\(baseRefDisplay))"
    case .creatingWorktree:
      let ignored = copyIgnored.map { $0 ? "on" : "off" } ?? "off"
      let untracked = copyUntracked.map { $0 ? "on" : "off" } ?? "off"
      return "Creating from \(baseRefDisplay) (copy ignored: \(ignored), copy untracked: \(untracked))"
    }
  }

  private var baseRefDisplay: String {
    guard let baseRef, !baseRef.isEmpty else {
      return "HEAD"
    }
    return baseRef
  }
}

nonisolated enum WorktreeCreationStage: Hashable, Sendable {
  case loadingLocalBranches
  case choosingWorktreeName
  case checkingRepositoryMode
  case resolvingBaseReference
  case creatingWorktree
}
