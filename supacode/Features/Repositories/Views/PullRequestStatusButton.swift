import SwiftUI

struct PullRequestStatusButton: View {
  let model: PullRequestStatusModel
  @Environment(\.openURL) private var openURL

  var body: some View {
    Button {
      if let url = model.url {
        openURL(url)
      }
    } label: {
      HStack {
        if let checkBreakdown = model.checkBreakdown {
          PullRequestChecksRingView(breakdown: checkBreakdown)
        }
        Text(model.label)
      }
    }
    .buttonStyle(.plain)
    .font(.caption)
    .monospaced()
    .help("Open pull request on GitHub")
  }

}

struct PullRequestStatusModel: Equatable {
  let label: String
  let url: URL?
  let checkBreakdown: PullRequestCheckBreakdown?

  init(label: String, url: URL?, checkBreakdown: PullRequestCheckBreakdown?) {
    self.label = label
    self.url = url
    self.checkBreakdown = checkBreakdown
  }

  init?(snapshot: WorktreeInfoSnapshot?) {
    guard
      let snapshot,
      let number = snapshot.pullRequestNumber,
      Self.shouldDisplay(state: snapshot.pullRequestState, number: number)
    else {
      return nil
    }
    let state = snapshot.pullRequestState?.uppercased()
    let url = snapshot.pullRequestURL.flatMap(URL.init(string:))
    if state == "MERGED" {
      self.label = "PR #\(number) - Merged"
      self.url = url
      self.checkBreakdown = nil
      return
    }
    let isDraft = snapshot.pullRequestIsDraft
    let prefix = "PR #\(number)\(isDraft ? " (Drafted)" : "") ↗ - "
    let checks = snapshot.pullRequestStatusChecks
    if checks.isEmpty {
      self.label = prefix + "Checks unavailable"
      self.url = url
      self.checkBreakdown = nil
      return
    }
    let breakdown = PullRequestCheckBreakdown(checks: checks)
    let checksLabel = breakdown.total == 1 ? "check" : "checks"
    var parts: [String] = []
    if breakdown.failed > 0 {
      parts.append("\(breakdown.failed) failed")
    }
    if breakdown.inProgress > 0 {
      parts.append("\(breakdown.inProgress) in progress")
    }
    if breakdown.skipped > 0 {
      parts.append("\(breakdown.skipped) skipped")
    }
    if breakdown.expected > 0 {
      parts.append("\(breakdown.expected) expected")
    }
    if breakdown.total > 0 {
      parts.append("\(breakdown.passed) successful")
    }
    self.label = prefix + parts.joined(separator: ", ") + " \(checksLabel)"
    self.url = url
    self.checkBreakdown = breakdown
  }

  static func shouldDisplay(state: String?, number: Int?) -> Bool {
    guard number != nil else {
      return false
    }
    return state?.uppercased() != "CLOSED"
  }
}
