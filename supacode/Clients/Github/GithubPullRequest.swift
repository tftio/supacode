import Foundation

nonisolated struct GithubPullRequest: Decodable, Equatable, Hashable {
  let number: Int
  let title: String
  let state: String
  let isDraft: Bool
  let reviewDecision: String?
  let updatedAt: Date?
  let url: String
  let statusCheckRollup: GithubPullRequestStatusCheckRollup?
}
