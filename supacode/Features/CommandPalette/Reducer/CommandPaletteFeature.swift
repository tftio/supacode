import ComposableArchitecture

@Reducer
struct CommandPaletteFeature {
  @ObservableState
  struct State: Equatable {
    var isPresented = false
    var query = ""
    var selectedIndex: Int?
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case setPresented(Bool)
    case togglePresented
    case activateWorktree(Worktree.ID)
    case delegate(Delegate)
  }

  enum MoveDirection: Equatable {
    case up
    case down
  }

  enum Delegate: Equatable {
    case selectWorktree(Worktree.ID)
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .setPresented(let isPresented):
        state.isPresented = isPresented
        if isPresented {
          state.selectedIndex = nil
        } else {
          state.query = ""
          state.selectedIndex = nil
        }
        return .none

      case .togglePresented:
        state.isPresented.toggle()
        if state.isPresented {
          state.selectedIndex = nil
        } else {
          state.query = ""
          state.selectedIndex = nil
        }
        return .none

      case .activateWorktree(let id):
        state.isPresented = false
        state.query = ""
        state.selectedIndex = nil
        return .send(.delegate(.selectWorktree(id)))

      case .delegate:
        return .none
      }
    }
  }
}
