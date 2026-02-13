import SwiftUI

struct WorktreeLoadingView: View {
  let info: WorktreeLoadingInfo

  var body: some View {
    let actionLabel = info.state == .creating ? "Creating" : "Removing"
    let statusTitle =
      info.statusTitle
      ?? {
        if let repositoryName = info.repositoryName {
          return "\(actionLabel) worktree in \(repositoryName)"
        }
        return "\(actionLabel) worktree..."
      }()
    let followup =
      info.state == .creating
      ? "We will open the terminal when it's ready."
      : "We will close the terminal when it's ready."
    VStack {
      ProgressView()
      Text(info.name)
        .font(.headline)
      Text(statusTitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      if let statusDetail = info.statusDetail, !statusDetail.isEmpty {
        Text(statusDetail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Text(followup)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .multilineTextAlignment(.center)
  }
}
