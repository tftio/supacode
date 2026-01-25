struct WorktreeLoadingInfo: Hashable, Sendable {
  let name: String
  let repositoryName: String?
  let state: WorktreeLoadingState
}
