import ComposableArchitecture
import SwiftUI

struct RepositorySectionView: View {
  let repository: Repository
  @Binding var expandedRepoIDs: Set<Repository.ID>
  @Bindable var store: StoreOf<RepositoriesFeature>
  let terminalManager: WorktreeTerminalManager
  @Environment(\.colorScheme) private var colorScheme
  @State private var isHovering = false

  var body: some View {
    let state = store.state
    let isExpanded = expandedRepoIDs.contains(repository.id)
    let isRemovingRepository = state.isRemovingRepository(repository)
    let isExpandedBinding = Binding(
      get: { expandedRepoIDs.contains(repository.id) },
      set: { isExpanded in
        guard !isRemovingRepository else { return }
        withAnimation(.easeOut(duration: 0.2)) {
          if isExpanded {
            expandedRepoIDs.insert(repository.id)
          } else {
            expandedRepoIDs.remove(repository.id)
          }
        }
      }
    )
    let openRepoSettings = {
      _ = store.send(.openRepositorySettings(repository.id))
    }

    Section {
      WorktreeRowsView(
        repository: repository,
        isExpanded: isExpanded,
        store: store,
        terminalManager: terminalManager
      )
    } header: {
      DisclosureGroup(isExpanded: isExpandedBinding) {
        EmptyView()
      } label: {
        HStack {
          RepoHeaderRow(
            name: repository.name,
            isRemoving: isRemovingRepository
          )
          .frame(maxWidth: .infinity, alignment: .leading)
          if isRemovingRepository {
            ProgressView()
              .controlSize(.small)
          }
          if isHovering {
            Menu {
              Button("Repo Settings") {
                openRepoSettings()
              }
              .help("Repo Settings ")
              Button("Remove Repository") {
                store.send(.requestRemoveRepository(repository.id))
              }
              .help("Remove repository ")
              .disabled(isRemovingRepository)
            } label: {
              Label("Repository options", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Repository options ")
            .disabled(isRemovingRepository)
            Button {
              store.send(.createRandomWorktreeInRepository(repository.id))
            } label: {
              Label("New Worktree", systemImage: "plus")
                .labelStyle(.iconOnly)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("New Worktree (\(AppShortcuts.newWorktree.display))")
            .disabled(isRemovingRepository)
          }
        }
        .contentShape(.rect)
      }
      .onHover { isHovering = $0 }
      .contextMenu {
        Button("Repo Settings") {
          openRepoSettings()
        }
        .help("Repo Settings ")
        Button("Remove Repository") {
          store.send(.requestRemoveRepository(repository.id))
        }
        .help("Remove repository ")
        .disabled(isRemovingRepository)
      }
      .contentShape(.dragPreview, .rect)
      .environment(\.colorScheme, colorScheme)
      .preferredColorScheme(colorScheme)
      .listRowInsets(EdgeInsets())
    }
  }
}
