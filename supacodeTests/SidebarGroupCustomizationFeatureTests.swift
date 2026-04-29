import ComposableArchitecture
import SwiftUI
import Testing

@testable import supacode

@MainActor
@Suite(.serialized)
struct SidebarGroupCustomizationFeatureTests {
  private func makeState(
    title: String = "Work",
    color: RepositoryColor? = nil,
    isNew: Bool = false
  ) -> SidebarGroupCustomizationFeature.State {
    SidebarGroupCustomizationFeature.State(
      groupID: "work",
      isNew: isNew,
      title: title,
      color: color,
      customColor: color?.color ?? .accentColor,
    )
  }

  @Test func saveTrimsTitleAndForwardsValues() async {
    let store = TestStore(initialState: makeState(title: "  Work Repos  ", color: .blue)) {
      SidebarGroupCustomizationFeature()
    }

    await store.send(.saveButtonTapped)
    await store.receive(
      .delegate(
        .save(groupID: "work", isNew: false, title: "Work Repos", color: .blue),
      ))
  }

  @Test func saveUsesFallbackTitleWhenEmpty() async {
    let store = TestStore(initialState: makeState(title: "  ")) {
      SidebarGroupCustomizationFeature()
    }

    await store.send(.saveButtonTapped)
    await store.receive(
      .delegate(
        .save(groupID: "work", isNew: false, title: SidebarState.defaultGroupTitle, color: nil),
      ))
  }

  @Test func selectColorMirrorsCustomColor() async {
    let store = TestStore(initialState: makeState()) {
      SidebarGroupCustomizationFeature()
    }

    await store.send(.selectColor(.purple)) {
      $0.color = .purple
      $0.customColor = RepositoryColor.purple.color
    }
  }

  @Test func cancelDelegatesCancel() async {
    let store = TestStore(initialState: makeState()) {
      SidebarGroupCustomizationFeature()
    }

    await store.send(.cancelButtonTapped)
    await store.receive(.delegate(.cancel))
  }
}
