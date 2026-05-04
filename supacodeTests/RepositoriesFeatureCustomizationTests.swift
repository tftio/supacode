import ComposableArchitecture
import Foundation
import IdentifiedCollections
import OrderedCollections
import SupacodeSettingsShared
import SwiftUI
import Testing

@testable import supacode

@MainActor
@Suite(.serialized)
struct RepositoriesFeatureCustomizationTests {
  private let repoID = "/tmp/customize-repo"

  private func makeInitialState(
    isGitRepository: Bool = true
  ) -> RepositoriesFeature.State {
    let worktree = Worktree(
      id: "\(repoID)/main",
      name: "main",
      detail: "detail",
      workingDirectory: URL(fileURLWithPath: repoID),
      repositoryRootURL: URL(fileURLWithPath: repoID),
    )
    let repository = Repository(
      id: repoID,
      rootURL: URL(fileURLWithPath: repoID),
      name: "customize-repo",
      worktrees: IdentifiedArray(uniqueElements: [worktree]),
      isGitRepository: isGitRepository,
    )
    var state = RepositoriesFeature.State()
    state.repositories = IdentifiedArray(uniqueElements: [repository])
    state.repositoryRoots = [repository.rootURL]
    return state
  }

  @Test func requestCustomizeRepositorySeedsPromptFromStoredSidebarSection() async {
    let initial = makeInitialState()
    initial.$sidebar.withLock { sidebar in
      sidebar.sections[self.repoID] = .init(
        title: "Pretty",
        color: .blue,
      )
    }
    let store = TestStore(initialState: initial) {
      RepositoriesFeature()
    }

    await store.send(.requestCustomizeRepository(repoID)) {
      $0.repositoryCustomization = RepositoryCustomizationFeature.State(
        repositoryID: self.repoID,
        defaultName: "customize-repo",
        title: "Pretty",
        color: .blue,
        customColor: RepositoryColor.blue.color,
      )
    }
  }

  @Test func requestCustomizeRepositoryNoOpsForFolderRepos() async {
    // Folder repos render through `SidebarFolderRow` and have no
    // section header to tint. The reducer must reject the request
    // even if a future deeplink or palette entry tries to invoke
    // it.
    let store = TestStore(initialState: makeInitialState(isGitRepository: false)) {
      RepositoriesFeature()
    }

    await store.send(.requestCustomizeRepository(repoID))
    // No state mutation expected — `repositoryCustomization` stays nil.
  }

  @Test func saveDelegatePersistsTitleAndColorToSidebar() async {
    var initial = makeInitialState()
    initial.repositoryCustomization = RepositoryCustomizationFeature.State(
      repositoryID: repoID,
      defaultName: "customize-repo",
      title: "",
      color: nil,
      customColor: .accentColor,
    )
    let store = TestStore(initialState: initial) {
      RepositoriesFeature()
    }

    await store.send(
      .repositoryCustomization(
        .presented(
          .delegate(
            .save(repositoryID: repoID, title: "Renamed", color: .red)
          )))
    ) {
      $0.repositoryCustomization = nil
      $0.$sidebar.withLock { sidebar in
        sidebar.sections[self.repoID, default: .init()].title = "Renamed"
        sidebar.sections[self.repoID, default: .init()].color = .red
      }
    }
  }

  @Test func requestCreateSidebarGroupSeedsPromptWithGeneratedID() async {
    let store = TestStore(initialState: makeInitialState()) {
      RepositoriesFeature()
    } withDependencies: {
      $0.uuid = .constant(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    }

    await store.send(.requestCreateSidebarGroup) {
      $0.sidebarGroupCustomization = SidebarGroupCustomizationFeature.State(
        groupID: "group-00000000-0000-0000-0000-000000000001",
        isNew: true,
        title: "New Group",
        color: nil,
        customColor: .accentColor,
      )
    }
  }

  @Test func requestCustomizeSidebarGroupSeedsPromptFromStoredGroup() async {
    let initial = makeInitialState()
    initial.$sidebar.withLock { sidebar in
      sidebar.groups["work"] = .init(
        title: "Work",
        color: .blue,
        repositoryIDs: [self.repoID],
      )
    }
    let store = TestStore(initialState: initial) {
      RepositoriesFeature()
    }

    await store.send(.requestCustomizeSidebarGroup("work")) {
      $0.sidebarGroupCustomization = SidebarGroupCustomizationFeature.State(
        groupID: "work",
        isNew: false,
        title: "Work",
        color: .blue,
        customColor: RepositoryColor.blue.color,
      )
    }
  }

  @Test func requestCustomizeSyntheticDefaultSidebarGroupSeedsPrompt() async {
    let store = TestStore(initialState: makeInitialState()) {
      RepositoriesFeature()
    }

    await store.send(.requestCustomizeSidebarGroup(SidebarState.defaultGroupID)) {
      $0.sidebarGroupCustomization = SidebarGroupCustomizationFeature.State(
        groupID: SidebarState.defaultGroupID,
        isNew: false,
        title: SidebarState.defaultGroupTitle,
        color: nil,
        customColor: .accentColor,
      )
    }
  }

  @Test func saveNewSidebarGroupAppendsGroup() async {
    var initial = makeInitialState()
    initial.sidebarGroupCustomization = SidebarGroupCustomizationFeature.State(
      groupID: "group-1",
      isNew: true,
      title: "New Group",
      color: nil,
      customColor: .accentColor,
    )
    let store = TestStore(initialState: initial) {
      RepositoriesFeature()
    }

    await store.send(
      .sidebarGroupCustomization(
        .presented(
          .delegate(
            .save(groupID: "group-1", isNew: true, title: "Clients", color: .green)
          )))
    ) {
      $0.sidebarGroupCustomization = nil
      $0.$sidebar.withLock { sidebar in
        sidebar.groups["group-1"] = .init(
          title: "Clients",
          color: .green,
        )
      }
    }
  }

  @Test func saveExistingSidebarGroupUpdatesTitleAndColorOnly() async {
    var initial = makeInitialState()
    initial.$sidebar.withLock { sidebar in
      sidebar.groups["work"] = .init(
        title: "Work",
        color: .blue,
        repositoryIDs: [self.repoID],
      )
    }
    initial.sidebarGroupCustomization = SidebarGroupCustomizationFeature.State(
      groupID: "work",
      isNew: false,
      title: "Work",
      color: .blue,
      customColor: RepositoryColor.blue.color,
    )
    let store = TestStore(initialState: initial) {
      RepositoriesFeature()
    }

    await store.send(
      .sidebarGroupCustomization(
        .presented(
          .delegate(
            .save(groupID: "work", isNew: false, title: "Work Repos", color: .purple)
          )))
    ) {
      $0.sidebarGroupCustomization = nil
      $0.$sidebar.withLock { sidebar in
        sidebar.groups["work"]?.title = "Work Repos"
        sidebar.groups["work"]?.color = .purple
      }
    }

    #expect(store.state.sidebar.groups["work"]?.repositoryIDs == [repoID])
  }

  @Test func moveRepositoryToSidebarGroupRemovesItFromPreviousGroup() async {
    let initial = makeInitialState()
    initial.$sidebar.withLock { sidebar in
      sidebar.sections[self.repoID] = .init()
      sidebar.groups["work"] = .init(
        title: "Work",
        repositoryIDs: [self.repoID],
      )
      sidebar.groups["personal"] = .init(
        title: "Personal"
      )
    }
    let store = TestStore(initialState: initial) {
      RepositoriesFeature()
    }

    await store.send(.moveRepositoryToSidebarGroup(repositoryID: repoID, groupID: "personal")) {
      $0.$sidebar.withLock { sidebar in
        sidebar.groups["work"]?.repositoryIDs = []
        sidebar.groups["personal"]?.repositoryIDs = [self.repoID]
      }
    }
  }

  @Test func moveRepositoryToSyntheticDefaultSidebarGroupCreatesDefaultGroup() async {
    let initial = makeInitialState()
    initial.$sidebar.withLock { sidebar in
      sidebar.groups["work"] = .init(
        title: "Work",
        repositoryIDs: [self.repoID],
      )
    }
    let store = TestStore(initialState: initial) {
      RepositoriesFeature()
    }

    await store.send(.moveRepositoryToSidebarGroup(repositoryID: repoID, groupID: SidebarState.defaultGroupID)) {
      $0.$sidebar.withLock { sidebar in
        sidebar.groups["work"]?.repositoryIDs = []
        sidebar.groups[SidebarState.defaultGroupID] = .init(
          title: SidebarState.defaultGroupTitle,
          repositoryIDs: [self.repoID],
        )
      }
    }
  }

  @Test func requestDeleteSidebarGroupShowsConfirmationWithFallbackCopy() async {
    let initial = makeInitialState()
    initial.$sidebar.withLock { sidebar in
      sidebar.groups["work"] = .init(
        title: "Work",
        repositoryIDs: [self.repoID],
      )
    }
    let store = TestStore(initialState: initial) {
      RepositoriesFeature()
    }

    await store.send(.requestDeleteSidebarGroup("work")) {
      $0.alert = AlertState {
        TextState("Delete “Work”?")
      } actions: {
        ButtonState(role: .destructive, action: .confirmDeleteSidebarGroup("work")) {
          TextState("Delete Group")
        }
        ButtonState(role: .cancel) {
          TextState("Cancel")
        }
      } message: {
        TextState(
          "Its 1 repository will move to Repositories. Repository settings and worktree state will be preserved."
        )
      }
    }
  }

  @Test func requestDeleteDefaultSidebarGroupNoOps() async {
    let initial = makeInitialState()
    let store = TestStore(initialState: initial) {
      RepositoriesFeature()
    }

    await store.send(.requestDeleteSidebarGroup(SidebarState.defaultGroupID))
  }

  @Test func confirmDeleteSidebarGroupMovesContentsToDefaultGroup() async {
    var initial = makeInitialState()
    initial.alert = AlertState {
      TextState("Delete “Work”?")
    }
    initial.$sidebar.withLock { sidebar in
      sidebar.sections[self.repoID] = .init(
        title: "Pretty",
        color: .blue,
      )
      sidebar.groups["work"] = .init(
        title: "Work",
        repositoryIDs: [self.repoID],
      )
    }
    let store = TestStore(initialState: initial) {
      RepositoriesFeature()
    }

    await store.send(.alert(.presented(.confirmDeleteSidebarGroup("work")))) {
      $0.alert = nil
      $0.$sidebar.withLock { sidebar in
        sidebar.groups.removeValue(forKey: "work")
        sidebar.groups[SidebarState.defaultGroupID] = .init(
          title: SidebarState.defaultGroupTitle,
          repositoryIDs: [self.repoID],
        )
      }
    }

    #expect(store.state.sidebar.sections[repoID]?.title == "Pretty")
    #expect(store.state.sidebar.sections[repoID]?.color == .blue)
  }

  @Test func confirmDeleteEmptySidebarGroupDoesNotMaterializeDefaultGroup() async {
    let initial = makeInitialState()
    initial.$sidebar.withLock { sidebar in
      sidebar.groups["empty"] = .init(title: "Empty")
    }
    let store = TestStore(initialState: initial) {
      RepositoriesFeature()
    }

    await store.send(.alert(.presented(.confirmDeleteSidebarGroup("empty")))) {
      $0.alert = nil
      $0.$sidebar.withLock { sidebar in
        _ = sidebar.groups.removeValue(forKey: "empty")
      }
    }
  }

  @Test func explicitRemovalDropsCustomizationFromSidebar() async {
    // `preserveOrphanSections` keeps customized tombstones across
    // transient drops (filesystem flutter), but an explicit "Remove
    // Repository" must purge `sidebar.sections[id]` so re-adding the
    // same path doesn't silently restore the user's old title /
    // color.
    let initial = makeInitialState()
    initial.$sidebar.withLock { sidebar in
      sidebar.sections[self.repoID] = .init(
        title: "Pretty",
        color: .blue,
      )
    }
    let store = TestStore(initialState: initial) {
      RepositoriesFeature()
    } withDependencies: {
      $0.repositoryPersistence.saveRoots = { _ in }
      $0.repositoryPersistence.pruneRepositoryConfigs = { _ in }
      $0.analyticsClient.capture = { _, _ in }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.repositoriesRemoved([repoID], selectionWasRemoved: false))
    await store.skipReceivedActions()

    #expect(store.state.sidebar.sections[repoID] == nil)
  }

  @Test func cancelDelegateClearsPresentedState() async {
    var initial = makeInitialState()
    initial.repositoryCustomization = RepositoryCustomizationFeature.State(
      repositoryID: repoID,
      defaultName: "customize-repo",
      title: "",
      color: nil,
      customColor: .accentColor,
    )
    let store = TestStore(initialState: initial) {
      RepositoriesFeature()
    }

    await store.send(
      .repositoryCustomization(.presented(.delegate(.cancel)))
    ) {
      $0.repositoryCustomization = nil
    }
  }
}
