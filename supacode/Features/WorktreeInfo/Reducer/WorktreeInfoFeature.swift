import ComposableArchitecture
import Foundation

@Reducer
struct WorktreeInfoFeature {
  @ObservableState
  struct State: Equatable {
    var worktree: Worktree?
    var snapshot: WorktreeInfoSnapshot?
    var status: WorktreeInfoStatus = .idle
    var nextRefresh: Date?
    var cachedSnapshots: [Worktree.ID: WorktreeInfoSnapshot] = [:]
    var cachedNextRefreshDates: [Worktree.ID: Date] = [:]
    var cachedPullRequest: GithubPullRequest?
  }

  enum Action: Equatable {
    case task
    case worktreeChanged(Worktree?, cachedPullRequest: GithubPullRequest?)
    case cachedPullRequestUpdated(Worktree.ID, GithubPullRequest?)
    case refresh
    case refreshFinished(Result<WorktreeInfoSnapshot, WorktreeInfoError>)
    case timerTick
    case appBecameActive
  }

  @Dependency(\.githubCLI) private var githubCLI
  @Dependency(\.continuousClock) private var clock

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        return .none

      case .worktreeChanged(let worktree, let cachedPullRequest):
        state.worktree = worktree
        state.cachedPullRequest = cachedPullRequest
        if let worktree {
          if let cachedSnapshot = state.cachedSnapshots[worktree.id] {
            if let cachedPullRequest {
              state.snapshot = snapshotByReplacingPullRequest(
                snapshot: cachedSnapshot,
                pullRequest: cachedPullRequest
              )
            } else {
              state.snapshot = snapshotByReplacingPullRequest(
                snapshot: cachedSnapshot,
                pullRequest: nil
              )
            }
          } else if let cachedPullRequest {
            state.snapshot = snapshotFromCachedPullRequest(
              worktree: worktree,
              pullRequest: cachedPullRequest
            )
          } else {
            state.snapshot = nil
          }
          state.nextRefresh = state.cachedNextRefreshDates[worktree.id]
          state.status = state.snapshot == nil ? .loading : .idle
        } else {
          state.snapshot = nil
          state.nextRefresh = nil
          state.status = .idle
        }
        if worktree == nil {
          return .merge(
            .cancel(id: WorktreeInfoCancelID.refresh),
            .cancel(id: WorktreeInfoCancelID.timer)
          )
        }
        return .merge(
          .cancel(id: WorktreeInfoCancelID.refresh),
          timerEffect(),
          .send(.refresh)
        )

      case .cachedPullRequestUpdated(let worktreeID, let pullRequest):
        if let cachedSnapshot = state.cachedSnapshots[worktreeID] {
          state.cachedSnapshots[worktreeID] = snapshotByReplacingPullRequest(
            snapshot: cachedSnapshot,
            pullRequest: pullRequest
          )
        }
        guard state.worktree?.id == worktreeID else { return .none }
        state.cachedPullRequest = pullRequest
        if let snapshot = state.snapshot {
          let updatedSnapshot = snapshotByReplacingPullRequest(
            snapshot: snapshot,
            pullRequest: pullRequest
          )
          state.snapshot = updatedSnapshot
          state.cachedSnapshots[worktreeID] = updatedSnapshot
        } else if let worktree = state.worktree, let pullRequest {
          let updatedSnapshot = snapshotFromCachedPullRequest(
            worktree: worktree,
            pullRequest: pullRequest
          )
          state.snapshot = updatedSnapshot
          state.cachedSnapshots[worktreeID] = updatedSnapshot
        }
        return .none

      case .refresh:
        guard let worktree = state.worktree else { return .none }
        state.status = .loading
        let githubCLI = githubCLI
        let cachedPullRequest = state.cachedPullRequest
        return .run { send in
          let result: Result<WorktreeInfoSnapshot, WorktreeInfoError> = await Result {
            try await loadWorktreeInfoSnapshot(
              worktree: worktree,
              cachedPullRequest: cachedPullRequest,
              githubCLI: githubCLI
            )
          }.mapError { error in
            if let githubError = error as? GithubCLIError {
              return .githubFailure(githubError.localizedDescription)
            }
            return .gitFailure(error.localizedDescription)
          }
          await send(.refreshFinished(result))
        }
        .cancellable(id: WorktreeInfoCancelID.refresh, cancelInFlight: true)

      case .refreshFinished(let result):
        switch result {
        case .success(let snapshot):
          state.snapshot = snapshot
          state.status = .idle
          let nextRefresh = Date().addingTimeInterval(60)
          state.nextRefresh = nextRefresh
          if let worktree = state.worktree {
            state.cachedSnapshots[worktree.id] = snapshot
            state.cachedNextRefreshDates[worktree.id] = nextRefresh
          }
        case .failure(let error):
          state.status = .failed(error.localizedDescription)
        }
        return .none

      case .timerTick:
        return .send(.refresh)

      case .appBecameActive:
        guard state.worktree != nil else { return .none }
        return .send(.refresh)
      }
    }
  }

  private func timerEffect() -> Effect<Action> {
    .run { send in
      while !Task.isCancelled {
        try await clock.sleep(for: .seconds(60))
        await send(.timerTick)
      }
    }
    .cancellable(id: WorktreeInfoCancelID.timer, cancelInFlight: true)
  }
}

nonisolated private func loadWorktreeInfoSnapshot(
  worktree: Worktree,
  cachedPullRequest: GithubPullRequest?,
  githubCLI: GithubCLIClient
) async throws -> WorktreeInfoSnapshot {
  let repoRoot = worktree.repositoryRootURL
  let repositoryName = repoRoot.lastPathComponent
  let repositoryPath = repoRoot.path(percentEncoded: false)
  let worktreeRoot = worktree.workingDirectory
  let worktreePath = worktreeRoot.path(percentEncoded: false)

  var githubError: String?
  var ciError: String?
  let githubAvailable = await githubCLI.isAvailable()
  if !githubAvailable {
    githubError = GithubCLIError.unavailable.errorDescription
  }

  var defaultBranchName: String?
  if githubAvailable {
    do {
      defaultBranchName = try await githubCLI.defaultBranch(repoRoot)
    } catch {
      githubError = "Not a GitHub repository"
    }
  }
  var workflowName: String?
  var workflowStatus: String?
  var workflowConclusion: String?
  var workflowUpdatedAt: Date?

  let cachedPullRequestInfo = pullRequestDetails(cachedPullRequest)
  var pullRequestNumber = cachedPullRequestInfo.number
  var pullRequestTitle = cachedPullRequestInfo.title
  var pullRequestURL = cachedPullRequestInfo.url
  var pullRequestState = cachedPullRequestInfo.state
  var pullRequestIsDraft = cachedPullRequestInfo.isDraft
  var pullRequestReviewDecision = cachedPullRequestInfo.reviewDecision
  var pullRequestUpdatedAt = cachedPullRequestInfo.updatedAt
  var pullRequestStatusChecks = cachedPullRequestInfo.statusChecks

  if cachedPullRequest == nil, githubAvailable {
    do {
      if let pullRequest = try await githubCLI.currentPullRequest(worktreeRoot) {
        let pullRequestInfo = pullRequestDetails(pullRequest)
        pullRequestNumber = pullRequestInfo.number
        pullRequestTitle = pullRequestInfo.title
        pullRequestURL = pullRequestInfo.url
        pullRequestState = pullRequestInfo.state
        pullRequestIsDraft = pullRequestInfo.isDraft
        pullRequestReviewDecision = pullRequestInfo.reviewDecision
        pullRequestUpdatedAt = pullRequestInfo.updatedAt
        pullRequestStatusChecks = pullRequestInfo.statusChecks
      }
    } catch {
      githubError = githubError ?? error.localizedDescription
    }
  }

  if githubAvailable, let defaultBranchName {
    do {
      if let run = try await githubCLI.latestRun(repoRoot, defaultBranchName) {
        workflowName = run.workflowName ?? run.name ?? run.displayTitle
        workflowStatus = run.status
        workflowConclusion = run.conclusion
        workflowUpdatedAt = run.updatedAt ?? run.createdAt
      }
    } catch {
      ciError = error.localizedDescription
    }
  }

  return WorktreeInfoSnapshot(
    repositoryName: repositoryName,
    repositoryPath: repositoryPath,
    worktreePath: worktreePath,
    defaultBranchName: defaultBranchName,
    pullRequestNumber: pullRequestNumber,
    pullRequestTitle: pullRequestTitle,
    pullRequestURL: pullRequestURL,
    pullRequestState: pullRequestState,
    pullRequestIsDraft: pullRequestIsDraft,
    pullRequestReviewDecision: pullRequestReviewDecision,
    pullRequestUpdatedAt: pullRequestUpdatedAt,
    pullRequestStatusChecks: pullRequestStatusChecks,
    workflowName: workflowName,
    workflowStatus: workflowStatus,
    workflowConclusion: workflowConclusion,
    workflowUpdatedAt: workflowUpdatedAt,
    githubError: githubError,
    ciError: ciError
  )
}

nonisolated private func snapshotFromCachedPullRequest(
  worktree: Worktree,
  pullRequest: GithubPullRequest
) -> WorktreeInfoSnapshot {
  let repoRoot = worktree.repositoryRootURL
  let repositoryName = repoRoot.lastPathComponent
  let repositoryPath = repoRoot.path(percentEncoded: false)
  let worktreePath = worktree.workingDirectory.path(percentEncoded: false)
  let pullRequestInfo = pullRequestDetails(pullRequest)

  return WorktreeInfoSnapshot(
    repositoryName: repositoryName,
    repositoryPath: repositoryPath,
    worktreePath: worktreePath,
    defaultBranchName: nil,
    pullRequestNumber: pullRequestInfo.number,
    pullRequestTitle: pullRequestInfo.title,
    pullRequestURL: pullRequestInfo.url,
    pullRequestState: pullRequestInfo.state,
    pullRequestIsDraft: pullRequestInfo.isDraft,
    pullRequestReviewDecision: pullRequestInfo.reviewDecision,
    pullRequestUpdatedAt: pullRequestInfo.updatedAt,
    pullRequestStatusChecks: pullRequestInfo.statusChecks,
    workflowName: nil,
    workflowStatus: nil,
    workflowConclusion: nil,
    workflowUpdatedAt: nil,
    githubError: nil,
    ciError: nil
  )
}

nonisolated private func snapshotByReplacingPullRequest(
  snapshot: WorktreeInfoSnapshot,
  pullRequest: GithubPullRequest?
) -> WorktreeInfoSnapshot {
  let pullRequestInfo = pullRequestDetails(pullRequest)

  return WorktreeInfoSnapshot(
    repositoryName: snapshot.repositoryName,
    repositoryPath: snapshot.repositoryPath,
    worktreePath: snapshot.worktreePath,
    defaultBranchName: snapshot.defaultBranchName,
    pullRequestNumber: pullRequestInfo.number,
    pullRequestTitle: pullRequestInfo.title,
    pullRequestURL: pullRequestInfo.url,
    pullRequestState: pullRequestInfo.state,
    pullRequestIsDraft: pullRequestInfo.isDraft,
    pullRequestReviewDecision: pullRequestInfo.reviewDecision,
    pullRequestUpdatedAt: pullRequestInfo.updatedAt,
    pullRequestStatusChecks: pullRequestInfo.statusChecks,
    workflowName: snapshot.workflowName,
    workflowStatus: snapshot.workflowStatus,
    workflowConclusion: snapshot.workflowConclusion,
    workflowUpdatedAt: snapshot.workflowUpdatedAt,
    githubError: snapshot.githubError,
    ciError: snapshot.ciError
  )
}

private struct PullRequestDetails: Equatable {
  let number: Int?
  let title: String?
  let url: String?
  let state: String?
  let isDraft: Bool
  let reviewDecision: String?
  let updatedAt: Date?
  let statusChecks: [GithubPullRequestStatusCheck]
}

nonisolated private func pullRequestDetails(
  _ pullRequest: GithubPullRequest?
) -> PullRequestDetails {
  guard let pullRequest else {
    return PullRequestDetails(
      number: nil,
      title: nil,
      url: nil,
      state: nil,
      isDraft: false,
      reviewDecision: nil,
      updatedAt: nil,
      statusChecks: []
    )
  }

  return PullRequestDetails(
    number: pullRequest.number,
    title: pullRequest.title,
    url: pullRequest.url,
    state: pullRequest.state,
    isDraft: pullRequest.isDraft,
    reviewDecision: pullRequest.reviewDecision,
    updatedAt: pullRequest.updatedAt,
    statusChecks: pullRequest.statusCheckRollup?.checks ?? []
  )
}
