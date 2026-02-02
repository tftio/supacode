import SwiftUI

struct WorktreeLoadingView: View {
  let info: WorktreeLoadingInfo

  var body: some View {
    let actionLabel = info.state == .creating ? "Creating" : "Removing"
    let followup =
      info.state == .creating
      ? "We will open the terminal when it's ready."
      : "We will close the terminal when it's ready."
    VStack {
      ProgressView()
      Text(info.name)
        .ghosttyMonospaced(.headline)
      if let repositoryName = info.repositoryName {
        Text("\(actionLabel) worktree in \(repositoryName)")
          .ghosttyMonospaced(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        Text("\(actionLabel) worktree...")
          .ghosttyMonospaced(.subheadline)
          .foregroundStyle(.secondary)
      }
      Text(followup)
        .ghosttyMonospaced(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .multilineTextAlignment(.center)
  }
}
