import AppKit
import ComposableArchitecture

nonisolated struct WorkspaceClient: Sendable {
  var open: @MainActor @Sendable (
    _ action: OpenWorktreeAction,
    _ worktree: Worktree,
    _ onError: @escaping @MainActor @Sendable (OpenActionError) -> Void
  ) -> Void
}

nonisolated extension WorkspaceClient: DependencyKey {
  static let liveValue = WorkspaceClient { action, worktree, onError in
    action.perform(with: worktree) { error in
      onError(error)
    }
  }

  static let testValue = WorkspaceClient { _, _, _ in }
}

extension DependencyValues {
  nonisolated var workspaceClient: WorkspaceClient {
    get { self[WorkspaceClient.self] }
    set { self[WorkspaceClient.self] = newValue }
  }
}
