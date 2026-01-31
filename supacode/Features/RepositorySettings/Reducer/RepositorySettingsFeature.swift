import ComposableArchitecture
import Foundation

@Reducer
struct RepositorySettingsFeature {
  @ObservableState
  struct State: Equatable {
    var rootURL: URL
    var settings: RepositorySettings
    var branchOptions: [String] = []
    var defaultWorktreeBaseRef = "origin/main"
  }

  enum Action: Equatable {
    case task
    case settingsLoaded(RepositorySettings)
    case branchDataLoaded([String], defaultBaseRef: String)
    case setSetupScript(String)
    case setRunScript(String)
    case setWorktreeBaseRef(String)
    case setCopyIgnoredOnWorktreeCreate(Bool)
    case setCopyUntrackedOnWorktreeCreate(Bool)
    case delegate(Delegate)
  }

  enum Delegate: Equatable {
    case settingsChanged(URL)
  }

  @Dependency(\.repositorySettingsClient) private var repositorySettingsClient
  @Dependency(\.gitClient) private var gitClient

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        let rootURL = state.rootURL
        let repositorySettingsClient = repositorySettingsClient
        let gitClient = gitClient
        return .run { send in
          let settings = repositorySettingsClient.load(rootURL)
          await send(.settingsLoaded(settings))
          let branches: [String]
          do {
            branches = try await gitClient.branchRefs(rootURL)
          } catch {
            let rootPath = rootURL.path(percentEncoded: false)
            print(
              "Repository settings branch refs failed for \(rootPath): "
                + error.localizedDescription
            )
            branches = []
          }
          let defaultBaseRef: String
          do {
            defaultBaseRef = try await gitClient.defaultRemoteBranchRef(rootURL) ?? "HEAD"
          } catch {
            let rootPath = rootURL.path(percentEncoded: false)
            print(
              "Repository settings default base ref failed for \(rootPath): "
                + error.localizedDescription
            )
            defaultBaseRef = "HEAD"
          }
          await send(.branchDataLoaded(branches, defaultBaseRef: defaultBaseRef))
        }

      case .settingsLoaded(let settings):
        state.settings = settings
        return .none

      case .branchDataLoaded(let branches, let defaultBaseRef):
        state.defaultWorktreeBaseRef = defaultBaseRef
        var options = branches
        if !options.contains(defaultBaseRef) {
          options.append(defaultBaseRef)
        }
        let selected = state.settings.worktreeBaseRef
        if !selected.isEmpty, !options.contains(selected) {
          options.append(selected)
        }
        state.branchOptions = options
        return .none

      case .setSetupScript(let script):
        state.settings.setupScript = script
        let settings = state.settings
        let rootURL = state.rootURL
        let repositorySettingsClient = repositorySettingsClient
        return .run { send in
          repositorySettingsClient.save(settings, rootURL)
          await send(.delegate(.settingsChanged(rootURL)))
        }

      case .setRunScript(let script):
        state.settings.runScript = script
        let settings = state.settings
        let rootURL = state.rootURL
        let repositorySettingsClient = repositorySettingsClient
        return .run { send in
          repositorySettingsClient.save(settings, rootURL)
          await send(.delegate(.settingsChanged(rootURL)))
        }

      case .setWorktreeBaseRef(let ref):
        state.settings.worktreeBaseRef = ref
        let settings = state.settings
        let rootURL = state.rootURL
        let repositorySettingsClient = repositorySettingsClient
        return .run { send in
          repositorySettingsClient.save(settings, rootURL)
          await send(.delegate(.settingsChanged(rootURL)))
        }

      case .setCopyIgnoredOnWorktreeCreate(let isEnabled):
        state.settings.copyIgnoredOnWorktreeCreate = isEnabled
        let settings = state.settings
        let rootURL = state.rootURL
        let repositorySettingsClient = repositorySettingsClient
        return .run { send in
          repositorySettingsClient.save(settings, rootURL)
          await send(.delegate(.settingsChanged(rootURL)))
        }

      case .setCopyUntrackedOnWorktreeCreate(let isEnabled):
        state.settings.copyUntrackedOnWorktreeCreate = isEnabled
        let settings = state.settings
        let rootURL = state.rootURL
        let repositorySettingsClient = repositorySettingsClient
        return .run { send in
          repositorySettingsClient.save(settings, rootURL)
          await send(.delegate(.settingsChanged(rootURL)))
        }

      case .delegate:
        return .none
      }
    }
  }
}
