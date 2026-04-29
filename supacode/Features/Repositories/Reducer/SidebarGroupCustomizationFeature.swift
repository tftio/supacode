import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
struct SidebarGroupCustomizationFeature {
  @ObservableState
  struct State: Equatable {
    let groupID: SidebarState.Group.Identifier
    let isNew: Bool
    var title: String
    var color: RepositoryColor?
    var customColor: Color
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case selectColor(RepositoryColor?)
    case cancelButtonTapped
    case saveButtonTapped
    case delegate(Delegate)
  }

  @CasePathable
  enum Delegate: Equatable {
    case cancel
    case save(groupID: SidebarState.Group.Identifier, isNew: Bool, title: String, color: RepositoryColor?)
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding(\.customColor):
        if let custom = RepositoryColor.custom(from: state.customColor) {
          state.color = custom
        }
        return .none

      case .binding:
        return .none

      case .selectColor(let color):
        state.color = color
        if let color {
          state.customColor = color.color
        }
        return .none

      case .cancelButtonTapped:
        return .send(.delegate(.cancel))

      case .saveButtonTapped:
        let trimmed = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmed.isEmpty ? SidebarState.defaultGroupTitle : trimmed
        return .send(
          .delegate(
            .save(
              groupID: state.groupID,
              isNew: state.isNew,
              title: resolvedTitle,
              color: state.color,
            )
          )
        )

      case .delegate:
        return .none
      }
    }
  }
}
