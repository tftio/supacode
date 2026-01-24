import ComposableArchitecture
import SwiftUI

struct SidebarListView: View {
  @Bindable var store: StoreOf<RepositoriesFeature>
  @Binding var expandedRepoIDs: Set<Repository.ID>
  let terminalManager: WorktreeTerminalManager

  var body: some View {
    let selection = Binding<SidebarSelection?>(
      get: { store.selectedWorktreeID.map(SidebarSelection.worktree) },
      set: { store.send(.selectWorktree($0?.worktreeID)) }
    )
    List(selection: selection) {
      ForEach(store.repositories) { repository in
        RepositorySectionView(
          repository: repository,
          expandedRepoIDs: $expandedRepoIDs,
          store: store,
          terminalManager: terminalManager
        )
      }
    }
    .listStyle(.sidebar)
    .frame(minWidth: 220)
    .onChange(of: store.repositories) { _, newValue in
      let current = Set(newValue.map(\.id))
      expandedRepoIDs.formUnion(current)
      expandedRepoIDs = expandedRepoIDs.intersection(current)
    }
    .onChange(of: store.pendingWorktrees) { _, newValue in
      let repositoryIDs = Set(newValue.map(\.repositoryID))
      expandedRepoIDs.formUnion(repositoryIDs)
    }
    .dropDestination(for: URL.self) { urls, _ in
      let fileURLs = urls.filter(\.isFileURL)
      guard !fileURLs.isEmpty else { return false }
      store.send(.openRepositories(fileURLs))
      return true
    }
  }
}
