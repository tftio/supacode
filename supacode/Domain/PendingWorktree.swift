import Foundation

struct PendingWorktree: Identifiable, Hashable, Sendable {
  let id: String
  let repositoryID: Repository.ID
  let name: String
  let detail: String
  let targetName: String?
}
