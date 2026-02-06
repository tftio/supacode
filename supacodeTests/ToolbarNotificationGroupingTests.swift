import Foundation
import IdentifiedCollections
import Testing

@testable import supacode

@MainActor
struct ToolbarNotificationGroupingTests {
  @Test func groupsNotificationsByRepositoryAndWorktreeInDisplayOrder() {
    let repoAPath = "/tmp/repo-a"
    let repoBPath = "/tmp/repo-b"

    let repoAMain = makeWorktree(id: repoAPath, name: "main", repoRoot: repoAPath)
    let repoAOne = makeWorktree(id: "\(repoAPath)/one", name: "one", repoRoot: repoAPath)
    let repoATwo = makeWorktree(id: "\(repoAPath)/two", name: "two", repoRoot: repoAPath)

    let repoBMain = makeWorktree(id: repoBPath, name: "main", repoRoot: repoBPath)
    let repoBOne = makeWorktree(id: "\(repoBPath)/one", name: "one", repoRoot: repoBPath)

    let repoA = makeRepository(id: repoAPath, name: "Repo A", worktrees: [repoAMain, repoAOne, repoATwo])
    let repoB = makeRepository(id: repoBPath, name: "Repo B", worktrees: [repoBMain, repoBOne])

    var state = RepositoriesFeature.State(repositories: [repoA, repoB])
    state.repositoryRoots = [repoA.rootURL, repoB.rootURL]
    state.repositoryOrderIDs = [repoB.id, repoA.id]
    state.worktreeOrderByRepository[repoA.id] = [repoATwo.id, repoAOne.id]

    let manager = WorktreeTerminalManager(runtime: GhosttyRuntime())
    manager.state(for: repoAOne).notifications = [
      WorktreeTerminalNotification(surfaceId: UUID(), title: "A1", body: "done", isRead: true)
    ]
    manager.state(for: repoATwo).notifications = [
      WorktreeTerminalNotification(surfaceId: UUID(), title: "A2", body: "done")
    ]
    manager.state(for: repoBOne).notifications = [
      WorktreeTerminalNotification(surfaceId: UUID(), title: "B1", body: "done", isRead: true)
    ]

    let groups = state.toolbarNotificationGroups(terminalManager: manager)

    #expect(groups.map(\.id) == [repoB.id, repoA.id])
    #expect(groups[0].worktrees.map(\.id) == [repoBOne.id])
    #expect(groups[1].worktrees.map(\.id) == [repoATwo.id, repoAOne.id])
    #expect(groups[1].unseenWorktreeCount == 1)
  }

  @Test func omitsArchivedAndEmptyNotificationGroups() {
    let repoAPath = "/tmp/repo-a"
    let repoBPath = "/tmp/repo-b"

    let repoAMain = makeWorktree(id: repoAPath, name: "main", repoRoot: repoAPath)
    let repoAArchived = makeWorktree(id: "\(repoAPath)/archived", name: "archived", repoRoot: repoAPath)
    let repoBMain = makeWorktree(id: repoBPath, name: "main", repoRoot: repoBPath)
    let repoBEmpty = makeWorktree(id: "\(repoBPath)/empty", name: "empty", repoRoot: repoBPath)

    let repoA = makeRepository(id: repoAPath, name: "Repo A", worktrees: [repoAMain, repoAArchived])
    let repoB = makeRepository(id: repoBPath, name: "Repo B", worktrees: [repoBMain, repoBEmpty])

    var state = RepositoriesFeature.State(repositories: [repoA, repoB])
    state.repositoryRoots = [repoA.rootURL, repoB.rootURL]
    state.archivedWorktreeIDs = [repoAArchived.id]

    let manager = WorktreeTerminalManager(runtime: GhosttyRuntime())
    manager.state(for: repoAArchived).notifications = [
      WorktreeTerminalNotification(surfaceId: UUID(), title: "Archived", body: "hidden")
    ]

    let groups = state.toolbarNotificationGroups(terminalManager: manager)

    #expect(groups.isEmpty)
  }

  private func makeWorktree(
    id: String,
    name: String,
    repoRoot: String
  ) -> Worktree {
    Worktree(
      id: id,
      name: name,
      detail: "detail",
      workingDirectory: URL(fileURLWithPath: id),
      repositoryRootURL: URL(fileURLWithPath: repoRoot)
    )
  }

  private func makeRepository(
    id: String,
    name: String,
    worktrees: [Worktree]
  ) -> Repository {
    Repository(
      id: id,
      rootURL: URL(fileURLWithPath: id),
      name: name,
      worktrees: IdentifiedArray(uniqueElements: worktrees)
    )
  }
}
