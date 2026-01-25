//
//  supacodeApp.swift
//  supacode
//
//  Created by khoi on 20/1/26.
//

import Foundation
import GhosttyKit
import SwiftUI
import ComposableArchitecture

private enum GhosttyCLI {
  static let argv: [UnsafeMutablePointer<CChar>?] = {
    var args: [UnsafeMutablePointer<CChar>?] = []
    let executable = CommandLine.arguments.first ?? "supacode"
    args.append(strdup(executable))
    for shortcut in AppShortcuts.all {
      args.append(strdup("--keybind=\(shortcut.ghosttyKeybind)=unbind"))
    }
    args.append(nil)
    return args
  }()
}

@main
@MainActor
struct SupacodeApp: App {
  @State private var ghostty: GhosttyRuntime
  @State private var ghosttyShortcuts: GhosttyShortcutManager
  @State private var terminalManager: WorktreeTerminalManager
  @State private var commandKeyObserver: CommandKeyObserver
  @State private var store: StoreOf<AppFeature>

  @MainActor init() {
    if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("ghostty") {
      setenv("GHOSTTY_RESOURCES_DIR", resourceURL.path, 1)
    }
    GhosttyCLI.argv.withUnsafeBufferPointer { buffer in
      let argc = UInt(max(0, buffer.count - 1))
      let argv = UnsafeMutablePointer(mutating: buffer.baseAddress)
      if ghostty_init(argc, argv) != GHOSTTY_SUCCESS {
        preconditionFailure("ghostty_init failed")
      }
    }
    let runtime = GhosttyRuntime()
    _ghostty = State(initialValue: runtime)
    _ghosttyShortcuts = State(initialValue: GhosttyShortcutManager(runtime: runtime))
    let initialSettings = SettingsStorage().load()
    let terminalManager = WorktreeTerminalManager(runtime: runtime)
    _terminalManager = State(initialValue: terminalManager)
    _commandKeyObserver = State(initialValue: CommandKeyObserver())
    _store = State(
      initialValue: Store(initialState: AppFeature.State(settings: SettingsFeature.State(settings: initialSettings))) {
        AppFeature()
      } withDependencies: { values in
        values.terminalClient = TerminalClient(
          createTab: { worktree in
            terminalManager.createTab(in: worktree)
          },
          closeFocusedTab: { worktree in
            terminalManager.closeFocusedTab(in: worktree)
          },
          closeFocusedSurface: { worktree in
            terminalManager.closeFocusedSurface(in: worktree)
          },
          prune: { ids in
            terminalManager.prune(keeping: ids)
          }
        )
      }
    )
  }

  var body: some Scene {
    WindowGroup {
      ContentView(store: store, terminalManager: terminalManager)
        .environment(ghosttyShortcuts)
        .environment(commandKeyObserver)
        .preferredColorScheme(store.settings.appearanceMode.colorScheme)
    }
    .environment(ghosttyShortcuts)
    .environment(commandKeyObserver)
    .commands {
      WorktreeCommands(store: store.scope(state: \.repositories, action: \.repositories))
      SidebarCommands()
      TerminalCommands(ghosttyShortcuts: ghosttyShortcuts)
      UpdateCommands(store: store.scope(state: \.updates, action: \.updates))
    }
    WindowGroup("Repo Settings", id: WindowIdentifiers.repoSettings, for: Repository.ID.self) { $repositoryID in
      if let repositoryID {
        let rootURL = URL(fileURLWithPath: repositoryID)
        RepositorySettingsView(
          store: Store(initialState: RepositorySettingsFeature.State(rootURL: rootURL)) {
            RepositorySettingsFeature()
          }
        )
      } else {
        Text("Select a repository to edit settings.")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scenePadding()
      }
    }
    .environment(ghosttyShortcuts)
    .environment(commandKeyObserver)
    Settings {
      SettingsView(store: store)
        .environment(ghosttyShortcuts)
        .environment(commandKeyObserver)
    }
    .environment(ghosttyShortcuts)
    .environment(commandKeyObserver)
  }
}
