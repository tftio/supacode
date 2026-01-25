import SwiftUI

struct WorktreeRow: View {
  let name: String
  let isPinned: Bool
  let isMainWorktree: Bool
  let isLoading: Bool
  let taskStatus: WorktreeTaskStatus?
  let shortcutHint: String?

  var body: some View {
    let showsSpinner = isLoading || taskStatus == .running
    HStack(alignment: .center) {
      ZStack {
        Image(systemName: "arrow.triangle.branch")
          .font(.caption)
          .foregroundStyle(.secondary)
          .opacity(showsSpinner ? 0 : 1)
          .accessibilityHidden(true)
        if showsSpinner {
          ProgressView()
            .controlSize(.small)
        }
      }
      Text(name)
      Spacer(minLength: 8)
      if let shortcutHint {
        ShortcutHintView(text: shortcutHint, color: .secondary)
      }
      if isMainWorktree {
        Image(systemName: "star.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
      if isPinned {
        Image(systemName: "pin.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
    }
  }
}
