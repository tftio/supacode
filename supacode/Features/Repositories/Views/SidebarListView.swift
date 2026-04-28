import AppKit
import ComposableArchitecture
import OrderedCollections
import Sharing
import SupacodeSettingsShared
import SwiftUI

struct SidebarListView: View {
  @Bindable var store: StoreOf<RepositoriesFeature>
  let terminalManager: WorktreeTerminalManager
  @FocusState private var isSidebarFocused: Bool

  var body: some View {
    let state = store.state
    let expandedRepoIDs = state.expandedRepositoryIDs
    let hotkeyRows = state.orderedSidebarItems(includingRepositoryIDs: expandedRepoIDs)
    let orderedRoots = state.orderedRepositoryRoots()
    let selectedWorktreeIDs = state.sidebarSelectedWorktreeIDs
    let currentSelections = state.sidebarSelections
    let selection = Binding<Set<SidebarSelection>>(
      get: { currentSelections },
      set: { newValue in
        guard newValue != currentSelections else { return }
        store.send(.selectionChanged(newValue))
      },
    )
    let repositoriesByID = Dictionary(uniqueKeysWithValues: store.repositories.map { ($0.id, $0) })
    let pendingSidebarReveal = state.pendingSidebarReveal

    return ScrollViewReader { scrollProxy in
      List(selection: selection) {
        if !state.isInitialLoadComplete, store.repositories.isEmpty {
          SidebarPlaceholderView()
        } else if orderedRoots.isEmpty {
          ForEach(store.repositories) { repository in
            SidebarRootView(
              repository: repository,
              hotkeyRows: hotkeyRows,
              selectedWorktreeIDs: selectedWorktreeIDs,
              store: store,
              terminalManager: terminalManager,
            )
          }
        } else {
          ForEach(sidebarGroups(from: orderedRoots), id: \.id) { groupRow in
            SidebarGroupHeaderView(
              groupID: groupRow.id,
              group: groupRow.group,
              repositoryCount: groupRow.rows.count,
              store: store,
            )
            if !groupRow.group.collapsed {
              ForEach(groupRow.rows, id: \.repositoryID) { row in
                if let failureMessage = state.loadFailuresByID[row.repositoryID] {
                  SidebarFailedRepositoryRow(
                    rootURL: row.rootURL,
                    failureMessage: failureMessage,
                    store: store,
                  )
                } else if let repository = repositoriesByID[row.repositoryID] {
                  SidebarRootView(
                    repository: repository,
                    hotkeyRows: hotkeyRows,
                    selectedWorktreeIDs: selectedWorktreeIDs,
                    store: store,
                    terminalManager: terminalManager,
                  )
                }
              }
              .onMove { offsets, destination in
                store.send(.repositoriesMovedInGroup(groupRow.id, offsets, destination))
              }
            }
          }
        }
      }
      .listStyle(.sidebar)
      .focused($isSidebarFocused)
      .frame(minWidth: 220)
      .dropDestination(for: URL.self) { urls, _ in
        let fileURLs = urls.filter(\.isFileURL)
        guard !fileURLs.isEmpty else { return false }
        store.send(.openRepositories(fileURLs))
        return true
      }
      .onKeyPress { keyPress in
        guard !keyPress.characters.isEmpty else { return .ignored }
        let navigationKeys: Set<KeyEquivalent> = [
          .upArrow, .downArrow, .leftArrow, .rightArrow,
          .home, .end, .pageUp, .pageDown,
        ]
        guard !navigationKeys.contains(keyPress.key) else { return .ignored }
        let hasCommandModifier = keyPress.modifiers.contains(.command)
        if hasCommandModifier { return .ignored }
        guard let worktreeID = store.selectedWorktreeID,
          state.sidebarSelectedWorktreeIDs.count == 1,
          state.sidebarSelectedWorktreeIDs.contains(worktreeID),
          let terminalState = terminalManager.stateIfExists(for: worktreeID)
        else { return .ignored }
        terminalState.focusAndInsertText(keyPress.characters)
        return .handled
      }
      .task(id: pendingSidebarReveal?.id) {
        await revealPendingSidebarWorktree(pendingSidebarReveal, with: scrollProxy)
      }
    }
  }

  private func sidebarRootRows(from orderedRoots: [URL]) -> [SidebarRootRow] {
    orderedRoots.map { rootURL in
      SidebarRootRow(
        rootURL: rootURL,
        repositoryID: rootURL.standardizedFileURL.path(percentEncoded: false),
      )
    }
  }

  private func sidebarGroups(from orderedRoots: [URL]) -> [SidebarGroupRow] {
    let rows = sidebarRootRows(from: orderedRoots)
    let rowsByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.repositoryID, $0) })
    let sourceGroups: OrderedDictionary<SidebarState.Group.Identifier, SidebarState.Group>
    if store.state.sidebar.groups.isEmpty {
      sourceGroups = [
        SidebarState.defaultGroupID: .init(
          title: SidebarState.defaultGroupTitle,
          repositoryIDs: rows.map(\.repositoryID),
        )
      ]
    } else {
      sourceGroups = store.state.sidebar.groups
    }

    var seen: Set<Repository.ID> = []
    var groupRows: [SidebarGroupRow] = []
    for (groupID, group) in sourceGroups {
      let groupedRows = group.repositoryIDs.compactMap { repositoryID -> SidebarRootRow? in
        guard let row = rowsByID[repositoryID], seen.insert(repositoryID).inserted else {
          return nil
        }
        return row
      }
      groupRows.append(.init(id: groupID, group: group, rows: groupedRows))
    }

    let remainingRows = rows.filter { seen.insert($0.repositoryID).inserted }
    if !remainingRows.isEmpty {
      if let defaultIndex = groupRows.firstIndex(where: { $0.id == SidebarState.defaultGroupID }) {
        groupRows[defaultIndex].rows.append(contentsOf: remainingRows)
      } else {
        groupRows.append(
          .init(
            id: SidebarState.defaultGroupID,
            group: .init(
              title: SidebarState.defaultGroupTitle,
              repositoryIDs: remainingRows.map(\.repositoryID),
            ),
            rows: remainingRows,
          )
        )
      }
    }
    return groupRows.filter { !$0.rows.isEmpty }
  }

  @MainActor
  private func revealPendingSidebarWorktree(
    _ pendingSidebarReveal: RepositoriesFeature.PendingSidebarReveal?,
    with scrollProxy: ScrollViewProxy,
  ) async {
    guard let pendingSidebarReveal else { return }
    // Give SwiftUI time to materialize newly expanded section rows before scrolling.
    await Task.yield()
    await Task.yield()
    isSidebarFocused = true
    withAnimation(.easeOut(duration: 0.2)) {
      scrollProxy.scrollTo(pendingSidebarReveal.worktreeID, anchor: .center)
    }
    store.send(.consumePendingSidebarReveal(pendingSidebarReveal.id))
  }
}

private struct SidebarRootRow: Equatable {
  let rootURL: URL
  let repositoryID: Repository.ID
}

private struct SidebarGroupRow: Identifiable, Equatable {
  let id: SidebarState.Group.Identifier
  var group: SidebarState.Group
  var rows: [SidebarRootRow]
}

private struct SidebarGroupHeaderView: View {
  let groupID: SidebarState.Group.Identifier
  let group: SidebarState.Group
  let repositoryCount: Int
  let store: StoreOf<RepositoriesFeature>

  private var displayTitle: String {
    let trimmed = group.title.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? SidebarState.defaultGroupTitle : trimmed
  }

  var body: some View {
    Button {
      store.send(.sidebarGroupExpansionChanged(groupID, isExpanded: group.collapsed))
    } label: {
      HStack(spacing: 6) {
        Image(systemName: group.collapsed ? "chevron.right" : "chevron.down")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        if let color = group.color?.color {
          Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
        }
        Text(displayTitle)
          .font(.caption.weight(.semibold))
          .textCase(.uppercase)
          .foregroundStyle(group.color?.color ?? .secondary)
          .lineLimit(1)
        Spacer(minLength: 8)
        Text("\(repositoryCount)")
          .font(.caption2.monospaced())
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(group.collapsed ? "Expand group" : "Collapse group")
    .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 2, trailing: 8))
    .listRowBackground(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
  }
}

private struct SidebarRootView: View {
  let repository: Repository
  let hotkeyRows: [SidebarItemModel]
  let selectedWorktreeIDs: Set<Worktree.ID>
  @Bindable var store: StoreOf<RepositoriesFeature>
  let terminalManager: WorktreeTerminalManager

  var body: some View {
    if repository.isGitRepository {
      SidebarSectionView(
        repository: repository,
        hotkeyRows: hotkeyRows,
        selectedWorktreeIDs: selectedWorktreeIDs,
        store: store,
        terminalManager: terminalManager,
      )
    } else {
      // Folder repos render a single flat row so the group-level
      // `.onMove` can reorder them alongside git sections.
      // `SidebarItemsView`'s nested ForEach-of-groups-of-rows would
      // hide the folder from that drag handler.
      Section {
        SidebarFolderRow(
          repository: repository,
          selectedWorktreeIDs: selectedWorktreeIDs,
          store: store,
          terminalManager: terminalManager,
        )
      } header: {
        EmptyView()
      }
    }
  }
}

private struct SidebarSectionView: View {
  let repository: Repository
  let hotkeyRows: [SidebarItemModel]
  let selectedWorktreeIDs: Set<Worktree.ID>
  @Bindable var store: StoreOf<RepositoriesFeature>
  let terminalManager: WorktreeTerminalManager
  var body: some View {
    let isRemovingRepository = store.state.isRemovingRepository(repository)
    let section = store.state.sidebar.sections[repository.id]
    Section(isExpanded: repositoryExpansionBinding) {
      SidebarItemsView(
        repository: repository,
        hotkeyRows: hotkeyRows,
        selectedWorktreeIDs: selectedWorktreeIDs,
        store: store,
        terminalManager: terminalManager,
      )
    } header: {
      RepoSectionHeaderView(
        name: repository.name,
        customTitle: section?.title,
        color: section?.color,
        isRemoving: isRemovingRepository,
      )
    }
    .sectionActions {
      SidebarSectionActionsView(
        repositoryID: repository.id,
        isRemovingRepository: isRemovingRepository,
        store: store,
      )
    }
  }

  private var repositoryExpansionBinding: Binding<Bool> {
    Binding(
      get: { store.state.isRepositoryExpanded(repository.id) },
      set: { isExpanded in
        store.send(.repositoryExpansionChanged(repository.id, isExpanded: isExpanded))
      },
    )
  }
}

private struct SidebarSectionActionsView: View {
  let repositoryID: Repository.ID
  let isRemovingRepository: Bool
  let store: StoreOf<RepositoriesFeature>

  var body: some View {
    Menu {
      Button("Customize Repository…", systemImage: "paintbrush") {
        store.send(.requestCustomizeRepository(repositoryID))
      }
      .help("Customize sidebar title and color")
      .disabled(isRemovingRepository)
      Button("Repository Settings…", systemImage: "gear") {
        store.send(.openRepositorySettings(repositoryID))
      }
      .help("Repository Settings")
      Divider()
      Button("Remove Repository…", systemImage: "folder.badge.minus", role: .destructive) {
        store.send(.requestDeleteRepository(repositoryID))
      }
      .help("Remove Repository")
      .disabled(isRemovingRepository)
    } label: {
      Image(systemName: "ellipsis")
        .accessibilityLabel("Options")
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
    }
    .menuStyle(.button)
    .menuIndicator(.hidden)
    .buttonStyle(.plain)
    .foregroundStyle(.secondary)

    Button {
      store.send(.createRandomWorktreeInRepository(repositoryID))
    } label: {
      Image(systemName: "plus")
        .accessibilityLabel("New Worktree")
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isRemovingRepository)
    .foregroundStyle(.secondary)
    .help("New Worktree")
    .padding(.trailing, 4)
  }
}

private struct SidebarFailedRepositoryRow: View {
  let rootURL: URL
  let failureMessage: String
  let store: StoreOf<RepositoriesFeature>

  var body: some View {
    let standardizedRootURL = rootURL.standardizedFileURL
    let name = Repository.name(for: standardizedRootURL)
    let path = standardizedRootURL.path(percentEncoded: false)

    FailedRepositoryRow(
      name: name,
      path: path,
      showFailure: {
        let message = "\(path)\n\n\(failureMessage)"
        store.send(.presentAlert(title: "Unable to load \(name)", message: message))
      },
      removeRepository: {
        store.send(.removeFailedRepository(path))
      },
    )
    .padding(.horizontal, 12)
  }
}

// MARK: - Sidebar placeholder.

private struct SidebarPlaceholderView: View {
  var body: some View {
    ForEach(0..<2, id: \.self) { section in
      Section {
        ForEach(0..<3, id: \.self) { _ in
          Label {
            VStack(alignment: .leading, spacing: 2) {
              Text("placeholder-branch")
                .font(.body)
                .lineLimit(1)
                .redacted(reason: .placeholder)
                .shimmer(isActive: true)
              Text("placeholder")
                .font(.footnote)
                .lineLimit(1)
                .redacted(reason: .placeholder)
                .shimmer(isActive: true)
            }
          } icon: {
            Image(systemName: "arrow.triangle.branch")
              .accessibilityHidden(true)
              .foregroundStyle(.secondary)
              .redacted(reason: .placeholder)
              .shimmer(isActive: true)
          }
        }
      } header: {
        Text(section == 0 ? "repository" : "second-repo")
          .foregroundStyle(.secondary)
          .redacted(reason: .placeholder)
          .shimmer(isActive: true)
      }
    }
  }
}
