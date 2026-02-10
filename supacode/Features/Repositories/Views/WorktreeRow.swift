import AppKit
import SwiftUI

struct WorktreeRow: View {
  let name: String
  let worktreeName: String
  let info: WorktreeInfoEntry?
  let showsPullRequestInfo: Bool
  let isHovered: Bool
  let isPinned: Bool
  let isMainWorktree: Bool
  let isLoading: Bool
  let taskStatus: WorktreeTaskStatus?
  let isRunScriptRunning: Bool
  let showsNotificationIndicator: Bool
  let notifications: [WorktreeTerminalNotification]
  let onFocusNotification: (WorktreeTerminalNotification) -> Void
  let shortcutHint: String?
  let pinAction: (() -> Void)?
  let archiveAction: (() -> Void)?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let showsSpinner = isLoading || taskStatus == .running
    let branchIconName = isMainWorktree ? "star.fill" : (isPinned ? "pin.fill" : "arrow.triangle.branch")
    let display = WorktreePullRequestDisplay(
      worktreeName: name,
      pullRequest: showsPullRequestInfo ? info?.pullRequest : nil
    )
    let displayAddedLines = info?.addedLines
    let displayRemovedLines = info?.removedLines
    let mergeReadiness = pullRequestMergeReadiness(for: display.pullRequest)
    let hasChangeCounts = displayAddedLines != nil && displayRemovedLines != nil
    let archiveShortcut = KeyboardShortcut(.delete, modifiers: .command).display
    let showsPullRequestTag = display.pullRequest != nil && display.pullRequestBadgeStyle != nil
    let nameColor = colorScheme == .dark ? Color.white : Color.primary
    let detailText = worktreeName.isEmpty ? name : worktreeName
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        ZStack {
          if showsNotificationIndicator {
            NotificationPopoverButton(
              notifications: notifications,
              onFocusNotification: onFocusNotification
            ) {
              Image(systemName: "bell.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel("Unread notifications")
            }
            .opacity(showsSpinner ? 0 : 1)
          } else {
            Image(systemName: branchIconName)
              .font(.caption)
              .foregroundStyle(.secondary)
              .opacity(showsSpinner ? 0 : 1)
              .accessibilityHidden(true)
          }
          if showsSpinner {
            ProgressView()
              .controlSize(.small)
          }
        }
        .frame(width: 16, height: 16)
        .alignmentGuide(.firstTextBaseline) { _ in
          bodyFont.ascender
        }
        Text(name)
          .font(.body)
          .foregroundStyle(nameColor)
          .lineLimit(1)
        Spacer(minLength: 4)
        if isRunScriptRunning {
          Image(systemName: "play.fill")
            .font(.caption)
            .foregroundStyle(.green)
            .help("Run script active")
            .accessibilityLabel("Run script active")
        }
        if hasChangeCounts, let displayAddedLines, let displayRemovedLines {
          WorktreeRowChangeCountView(
            addedLines: displayAddedLines,
            removedLines: displayRemovedLines
          )
        }
        if isHovered {
          Button {
            pinAction?()
          } label: {
            Image(systemName: isPinned ? "pin.slash" : "pin")
              .contentTransition(.symbolEffect(.replace))
              .accessibilityLabel(isPinned ? "Unpin worktree" : "Pin worktree")
          }
          .buttonStyle(.plain)
          .help(isPinned ? "Unpin" : "Pin to top")
          .disabled(pinAction == nil)
          Button {
            archiveAction?()
          } label: {
            Image(systemName: "archivebox")
              .accessibilityLabel("Archive worktree")
          }
          .buttonStyle(.plain)
          .help("Archive Worktree (\(archiveShortcut))")
          .disabled(archiveAction == nil)
        }
      }
      WorktreeRowInfoView(
        worktreeName: detailText,
        showsPullRequestTag: showsPullRequestTag,
        pullRequestNumber: display.pullRequest?.number,
        mergeReadiness: mergeReadiness,
        shortcutHint: shortcutHint
      )
      .padding(.leading, 22)
    }
    .padding(.horizontal, 2)
    .padding(.vertical, 4)
    .frame(maxWidth: .infinity, minHeight: worktreeRowHeight, alignment: .center)
  }

  private func pullRequestMergeReadiness(
    for pullRequest: GithubPullRequest?
  ) -> PullRequestMergeReadiness? {
    guard let pullRequest, pullRequest.state.uppercased() == "OPEN" else {
      return nil
    }
    return PullRequestMergeReadiness(pullRequest: pullRequest)
  }

  private var bodyFont: NSFont {
    NSFont.preferredFont(forTextStyle: .body)
  }

  private var worktreeRowHeight: CGFloat {
    56
  }
}

private struct WorktreeRowInfoView: View {
  let worktreeName: String
  let showsPullRequestTag: Bool
  let pullRequestNumber: Int?
  let mergeReadiness: PullRequestMergeReadiness?
  let shortcutHint: String?

  var body: some View {
    let summary = summaryText
    HStack(spacing: 4) {
      Text(summary)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
      Spacer(minLength: 0)
      if let shortcutHint {
        ShortcutHintView(text: shortcutHint, color: .secondary)
      }
    }
    .font(.caption)
    .frame(minHeight: 14)
  }

  private var summaryText: String {
    var segments: [String] = []
    if !worktreeName.isEmpty {
      segments.append(worktreeName)
    }
    if showsPullRequestTag, let pullRequestNumber {
      segments.append("PR #\(pullRequestNumber)")
    }
    if let mergeReadiness {
      segments.append(mergeReadiness.label)
    }
    return segments.joined(separator: " • ")
  }
}

private struct WorktreeRowChangeCountView: View {
  let addedLines: Int
  let removedLines: Int

  var body: some View {
    HStack(spacing: 4) {
      Text("+\(addedLines)")
        .foregroundStyle(.green)
      Text("-\(removedLines)")
        .foregroundStyle(.red)
    }
    .font(.caption)
    .lineLimit(1)
    .padding(.horizontal, 4)
    .padding(.vertical, 2)
    .overlay {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .stroke(.tertiary, lineWidth: 1)
    }
    .monospacedDigit()
  }
}
