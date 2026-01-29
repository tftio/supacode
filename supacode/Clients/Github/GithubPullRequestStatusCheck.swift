import Foundation

nonisolated struct GithubPullRequestStatusCheck: Decodable, Equatable, Hashable {
  let status: String?
  let conclusion: String?
  let state: String?
}

nonisolated struct GithubPullRequestStatusCheckRollup: Decodable, Equatable, Hashable {
  let checks: [GithubPullRequestStatusCheck]

  init(from decoder: Decoder) throws {
    if let checks = try? [GithubPullRequestStatusCheck](from: decoder) {
      self.checks = checks
      return
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let checks = try? container.decode([GithubPullRequestStatusCheck].self, forKey: .contexts) {
      self.checks = checks
      return
    }
    if let contexts = try? container.decode(GithubPullRequestStatusCheckContexts.self, forKey: .contexts) {
      self.checks = contexts.nodes
      return
    }
    self.checks = []
  }

  private enum CodingKeys: String, CodingKey {
    case contexts
  }
}

nonisolated private struct GithubPullRequestStatusCheckContexts: Decodable, Equatable {
  let nodes: [GithubPullRequestStatusCheck]
}

nonisolated struct PullRequestCheckBreakdown: Equatable {
  let passed: Int
  let failed: Int
  let inProgress: Int
  let expected: Int
  let skipped: Int

  var total: Int {
    passed + failed + inProgress + expected + skipped
  }

  init(checks: [GithubPullRequestStatusCheck]) {
    var passed = 0
    var failed = 0
    var inProgress = 0
    var expected = 0
    var skipped = 0
    for check in checks {
      if let status = check.status, status.uppercased() != "COMPLETED" {
        inProgress += 1
        continue
      }
      if let state = check.state {
        switch state.uppercased() {
        case "SUCCESS":
          passed += 1
        case "FAILURE", "ERROR":
          failed += 1
        case "EXPECTED":
          expected += 1
        case "PENDING":
          inProgress += 1
        default:
          inProgress += 1
        }
        continue
      }
      if let conclusion = check.conclusion {
        switch conclusion.uppercased() {
        case "SUCCESS", "NEUTRAL":
          passed += 1
        case "CANCELLED", "SKIPPED":
          skipped += 1
        case "FAILURE", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE", "STALE":
          failed += 1
        default:
          inProgress += 1
        }
        continue
      }
      inProgress += 1
    }
    self.passed = passed
    self.failed = failed
    self.inProgress = inProgress
    self.expected = expected
    self.skipped = skipped
  }
}
