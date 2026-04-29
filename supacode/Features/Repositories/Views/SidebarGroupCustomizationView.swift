import AppKit
import ComposableArchitecture
import SwiftUI

struct SidebarGroupCustomizationView: View {
  @Bindable var store: StoreOf<SidebarGroupCustomizationFeature>
  @FocusState private var isTitleFocused: Bool

  var body: some View {
    Form {
      Section {
        TextField("Title", text: $store.title, prompt: Text(SidebarState.defaultGroupTitle))
          .focused($isTitleFocused)
          .onSubmit {
            store.send(.saveButtonTapped)
          }
        LabeledContent("Color") {
          GroupColorSwatchRowView(store: store)
        }
      } header: {
        Text(store.isNew ? "New Sidebar Group" : "Customize Sidebar Group")
        Text("Set the sidebar group title and tint.")
      }
      .headerProminence(.increased)
    }
    .formStyle(.grouped)
    .scrollBounceBehavior(.basedOnSize)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      HStack {
        Spacer()
        Button("Cancel") {
          store.send(.cancelButtonTapped)
        }
        .keyboardShortcut(.cancelAction)
        .help("Cancel (Esc)")
        Button("Save") {
          store.send(.saveButtonTapped)
        }
        .keyboardShortcut(.defaultAction)
        .help("Save (↩)")
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)
    }
    .frame(minWidth: 420)
    .task { isTitleFocused = true }
    .onDisappear {
      NSColorPanel.shared.orderOut(nil)
    }
  }
}

private struct GroupColorSwatchRowView: View {
  @Bindable var store: StoreOf<SidebarGroupCustomizationFeature>

  var body: some View {
    HStack(spacing: 8) {
      GroupDefaultSwatchButton(
        isSelected: store.color == nil,
        action: { store.send(.selectColor(nil)) }
      )
      ForEach(RepositoryColor.predefined, id: \.rawValue) { color in
        GroupColorSwatchButton(
          color: color,
          isSelected: store.color == color,
          action: { store.send(.selectColor(color)) }
        )
      }
      Divider()
        .frame(height: 18)
        .padding(.horizontal, 2)
      GroupCustomSwatchButton(
        isSelected: store.color?.isCustom == true,
        color: $store.customColor,
      )
    }
  }
}

private struct GroupDefaultSwatchButton: View {
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        Circle()
          .strokeBorder(.secondary, lineWidth: 1)
          .background(Circle().fill(.background))
        Path { path in
          path.move(to: CGPoint(x: 4, y: 20))
          path.addLine(to: CGPoint(x: 20, y: 4))
        }
        .stroke(.secondary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
      }
      .frame(width: 24, height: 24)
      .modifier(GroupSwatchSelectionRing(isSelected: isSelected))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Default")
    .help("Default")
  }
}

private struct GroupColorSwatchButton: View {
  let color: RepositoryColor
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Circle()
        .fill(color.color)
        .frame(width: 24, height: 24)
        .modifier(GroupSwatchSelectionRing(isSelected: isSelected))
    }
    .buttonStyle(.plain)
    .help(color.displayName)
  }
}

private struct GroupCustomSwatchButton: View {
  let isSelected: Bool
  @Binding var color: Color

  var body: some View {
    ZStack {
      ColorPicker("Custom Color", selection: $color, supportsOpacity: false)
        .labelsHidden()
        .opacity(0.02)
        .frame(width: 24, height: 24)
      Circle()
        .fill(
          AngularGradient(
            colors: [.red, .yellow, .green, .blue, .purple, .red],
            center: .center,
          )
        )
        .overlay {
          Circle()
            .fill(color)
            .padding(7)
        }
        .frame(width: 24, height: 24)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    .modifier(GroupSwatchSelectionRing(isSelected: isSelected))
    .help("Custom")
  }
}

private struct GroupSwatchSelectionRing: ViewModifier {
  let isSelected: Bool

  func body(content: Content) -> some View {
    content
      .overlay {
        Circle()
          .stroke(.tint, lineWidth: 2)
          .padding(-3)
          .opacity(isSelected ? 1 : 0)
      }
      .animation(.easeOut(duration: 0.15), value: isSelected)
  }
}
