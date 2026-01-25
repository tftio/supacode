import ComposableArchitecture
import Foundation

nonisolated struct RepositoryPersistenceClient: Sendable {
  var loadRoots: @Sendable () -> [String]
  var saveRoots: @Sendable ([String]) -> Void
  var loadPinnedWorktreeIDs: @Sendable () -> [Worktree.ID]
  var savePinnedWorktreeIDs: @Sendable ([Worktree.ID]) -> Void
}

nonisolated extension RepositoryPersistenceClient: DependencyKey {
  static let liveValue: RepositoryPersistenceClient = {
    let rootsKey = "repositories.roots"
    let pinnedKey = "repositories.worktrees.pinned"
    return RepositoryPersistenceClient(
      loadRoots: {
        guard let data = UserDefaults.standard.data(forKey: rootsKey) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
      },
      saveRoots: { roots in
        guard let data = try? JSONEncoder().encode(roots) else { return }
        UserDefaults.standard.set(data, forKey: rootsKey)
      },
      loadPinnedWorktreeIDs: {
        guard let data = UserDefaults.standard.data(forKey: pinnedKey) else { return [] }
        return (try? JSONDecoder().decode([Worktree.ID].self, from: data)) ?? []
      },
      savePinnedWorktreeIDs: { ids in
        guard let data = try? JSONEncoder().encode(ids) else { return }
        UserDefaults.standard.set(data, forKey: pinnedKey)
      }
    )
  }()
  static let testValue = RepositoryPersistenceClient(
    loadRoots: { [] },
    saveRoots: { _ in },
    loadPinnedWorktreeIDs: { [] },
    savePinnedWorktreeIDs: { _ in }
  )
}

extension DependencyValues {
  nonisolated var repositoryPersistence: RepositoryPersistenceClient {
    get { self[RepositoryPersistenceClient.self] }
    set { self[RepositoryPersistenceClient.self] = newValue }
  }
}
