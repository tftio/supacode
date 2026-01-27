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
        if let indicatorColor = indicatorColor {
          Image(systemName: "circle.fill")
            .foregroundStyle(indicatorColor)
        }
        Text(model.label)
      }
    }
    .buttonStyle(.plain)
    .font(.caption)
    .monospaced()
    .help("Open pull request on GitHub")
  }

  private var indicatorColor: Color? {
    switch model.indicatorState {
    case .passed, .ignored:
      return .green
    case .pending:
      return .yellow
    case .failed:
      return .red
    case .none:
      return nil
    }
  }
}

struct PullRequestStatusModel: Equatable {
  let label: String
  let url: URL?
  let indicatorState: PullRequestCheckState?

  init(label: String, url: URL?, indicatorState: PullRequestCheckState?) {
    self.label = label
    self.url = url
    self.indicatorState = indicatorState
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
      self.indicatorState = nil
      return
    }
    let isDraft = snapshot.pullRequestIsDraft
    let prefix = "PR #\(number)\(isDraft ? " (Drafted)" : "") ↗ - "
    let checks = snapshot.pullRequestStatusChecks
    if checks.isEmpty {
      self.label = prefix + "Checks unavailable"
      self.url = url
      self.indicatorState = nil
      return
    }
    let summary = PullRequestCheckSummary(checks: checks)
    if summary.failed > 0 {
      self.label = prefix + "\(summary.failed)/\(summary.total) checks failed"
      self.url = url
      self.indicatorState = .failed
      return
    }
    if summary.pending > 0 {
      self.label = prefix + "\(summary.pending) checks pending"
      self.url = url
      self.indicatorState = .pending
      return
    }
    if summary.ignored > 0 {
      self.label = prefix + "\(summary.ignored) checks skipped"
      self.url = url
      self.indicatorState = .ignored
      return
    }
    self.label = prefix + "All checks passed"
    self.url = url
    self.indicatorState = .passed
  }

  static func shouldDisplay(state: String?, number: Int?) -> Bool {
    guard number != nil else {
      return false
    }
    return state?.uppercased() != "CLOSED"
  }
}
