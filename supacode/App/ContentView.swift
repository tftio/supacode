//
//  ContentView.swift
//  supacode
//
//  Created by khoi on 20/1/26.
//

import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @Bindable var store: StoreOf<AppFeature>
  @Bindable var repositoriesStore: StoreOf<RepositoriesFeature>
  let terminalManager: WorktreeTerminalManager
  @Environment(\.scenePhase) private var scenePhase
  @State private var leftSidebarVisibility: NavigationSplitViewVisibility = .all

  init(store: StoreOf<AppFeature>, terminalManager: WorktreeTerminalManager) {
    self.store = store
    repositoriesStore = store.scope(state: \.repositories, action: \.repositories)
    self.terminalManager = terminalManager
  }

  var body: some View {
    Group {
      if store.repositories.isInitialLoadComplete {
        NavigationSplitView(columnVisibility: $leftSidebarVisibility) {
          SidebarView(store: repositoriesStore, terminalManager: terminalManager)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
          WorktreeDetailView(store: store, terminalManager: terminalManager)
        }
        .navigationSplitViewStyle(.automatic)
      } else {
        AppLoadingView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.background)
      }
    }
    .task {
      store.send(.task)
    }
    .onChange(of: scenePhase) { _, newValue in
      store.send(.scenePhaseChanged(newValue))
    }
    .fileImporter(
      isPresented: $repositoriesStore.isOpenPanelPresented.sending(\.setOpenPanelPresented),
      allowedContentTypes: [.folder],
      allowsMultipleSelection: true
    ) { result in
      switch result {
      case .success(let urls):
        store.send(.repositories(.openRepositories(urls)))
      case .failure:
        store.send(
          .repositories(
            .presentAlert(
              title: "Unable to open folders",
              message: "Supacode could not read the selected folders."
            )
          )
        )
      }
    }
    .alert(store: repositoriesStore.scope(state: \.$alert, action: \.alert))
    .alert(store: store.scope(state: \.$alert, action: \.alert))
    .focusedSceneValue(\.toggleLeftSidebarAction, toggleLeftSidebar)
    .overlay {
      CommandPaletteOverlayView(
        store: store.scope(state: \.commandPalette, action: \.commandPalette),
        rows: commandPaletteRows(from: store.repositories)
      )
    }
    .background(WindowTabbingDisabler())
  }

  private func toggleLeftSidebar() {
    withAnimation(.easeOut(duration: 0.2)) {
      leftSidebarVisibility = leftSidebarVisibility == .detailOnly ? .all : .detailOnly
    }
  }

  private func commandPaletteRows(
    from repositories: RepositoriesFeature.State
  ) -> [CommandPaletteWorktreeRow] {
    repositories.orderedWorktreeRows().compactMap { row in
      guard !row.isPending, !row.isDeleting else { return nil }
      let repositoryName = repositories.repositoryName(for: row.repositoryID) ?? "Repository"
      let title = "\(repositoryName) / \(row.name)"
      let trimmedDetail = row.detail.trimmingCharacters(in: .whitespacesAndNewlines)
      let subtitle = trimmedDetail.isEmpty ? nil : trimmedDetail
      return CommandPaletteWorktreeRow(id: row.id, title: title, subtitle: subtitle)
    }
  }
}
