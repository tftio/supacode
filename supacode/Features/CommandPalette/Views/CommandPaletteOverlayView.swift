import AppKit
import ComposableArchitecture
import Foundation
import SwiftUI

struct CommandPaletteOverlayView: View {
  @Bindable var store: StoreOf<CommandPaletteFeature>
  let items: [CommandPaletteItem]
  @FocusState private var isQueryFocused: Bool
  @State private var hoveredID: CommandPaletteItem.ID?

  var body: some View {
    let now = Date.now
    let filteredItems = CommandPaletteFeature.filterItems(
      items: items,
      query: store.query,
      recencyByID: store.recencyByItemID,
      now: now
    )
    ZStack {
      if store.isPresented {
        ZStack {
          Color.clear
            .contentShape(.rect)
            .onTapGesture {
              store.send(.setPresented(false))
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Dismiss Command Palette")

          GeometryReader { geometry in
            VStack {
              Spacer()

              CommandPaletteCard(
                query: $store.query,
                selectedIndex: $store.selectedIndex,
                items: filteredItems,
                hoveredID: $hoveredID,
                isQueryFocused: _isQueryFocused,
                onEvent: { event in
                  switch event {
                  case .exit:
                    store.send(.setPresented(false))
                  case .submit:
                    submitSelected(rows: filteredItems)
                  case .move(let direction):
                    moveSelection(direction, rows: filteredItems)
                  }
                },
                activate: { id in
                  activate(id, rows: filteredItems)
                }
              )
              .zIndex(1)
              .task {
                isQueryFocused = store.isPresented
              }

              Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
          }
        }
      }
    }
    .onChange(of: store.isPresented) { _, newValue in
      isQueryFocused = newValue
      if newValue {
        updateSelection(rows: filteredItems)
      } else {
        hoveredID = nil
      }
    }
    .onChange(of: store.query) { _, _ in
      resetSelection(rows: filteredItems)
    }
    .onChange(of: filteredItems) { _, newValue in
      updateSelection(rows: newValue)
    }
    .onChange(of: items) { _, newValue in
      store.send(.pruneRecency(newValue.map(\.id)))
    }
  }

  private func updateSelection(rows: [CommandPaletteItem]) {
    store.send(.updateSelection(itemsCount: rows.count))
  }

  private func resetSelection(rows: [CommandPaletteItem]) {
    store.send(.resetSelection(itemsCount: rows.count))
  }

  private func moveSelection(_ direction: MoveCommandDirection, rows: [CommandPaletteItem]) {
    switch direction {
    case .up:
      store.send(.moveSelection(.upSelection, itemsCount: rows.count))
    case .down:
      store.send(.moveSelection(.downSelection, itemsCount: rows.count))
    default:
      break
    }
  }

  private func submitSelected(rows: [CommandPaletteItem]) {
    let trimmed = store.query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !rows.isEmpty else { return }
    guard let selectedIndex = store.selectedIndex else {
      if trimmed.isEmpty {
        return
      }
      store.send(.activateItem(rows[0]))
      return
    }
    if rows.indices.contains(selectedIndex) {
      store.send(.activateItem(rows[selectedIndex]))
      return
    }
    store.send(.activateItem(rows[rows.count - 1]))
  }

  private func activate(_ id: CommandPaletteItem.ID, rows: [CommandPaletteItem]) {
    guard let item = rows.first(where: { $0.id == id }) else { return }
    store.send(.activateItem(item))
  }
}

private struct CommandPaletteCard: View {
  @Binding var query: String
  @Binding var selectedIndex: Int?
  let items: [CommandPaletteItem]
  @Binding var hoveredID: CommandPaletteItem.ID?
  let isQueryFocused: FocusState<Bool>
  let onEvent: (CommandPaletteKeyboardEvent) -> Void
  let activate: (CommandPaletteItem.ID) -> Void

  private var backgroundColor: Color {
    Color(nsColor: .windowBackgroundColor)
  }

  private var colorScheme: ColorScheme {
    NSColor.windowBackgroundColor.isLightColor ? .light : .dark
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      CommandPaletteQuery(query: $query, isTextFieldFocused: isQueryFocused) { event in
        onEvent(event)
      }

      Divider()

      CommandPaletteShortcutHandler(items: Array(items.prefix(5))) { id in
        activate(id)
      }

      CommandPaletteList(
        rows: items,
        selectedIndex: $selectedIndex,
        hoveredID: $hoveredID
      ) { id in
        activate(id)
      }
    }
    .frame(maxWidth: 500)
    .background(
      ZStack {
        Rectangle().fill(.ultraThinMaterial)
        Rectangle()
          .fill(backgroundColor)
          .blendMode(.color)
      }
      .compositingGroup()
    )
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color(nsColor: .tertiaryLabelColor).opacity(0.75))
    )
    .shadow(radius: 32, x: 0, y: 12)
    .padding()
    .environment(\.colorScheme, colorScheme)
  }
}

private enum CommandPaletteKeyboardEvent: Equatable {
  case exit
  case submit
  case move(MoveCommandDirection)
}

private struct CommandPaletteQuery: View {
  @Binding var query: String
  var onEvent: ((CommandPaletteKeyboardEvent) -> Void)?
  @FocusState private var isTextFieldFocused: Bool

  init(
    query: Binding<String>,
    isTextFieldFocused: FocusState<Bool>,
    onEvent: ((CommandPaletteKeyboardEvent) -> Void)? = nil
  ) {
    _query = query
    self.onEvent = onEvent
    _isTextFieldFocused = isTextFieldFocused
  }

  var body: some View {
    ZStack {
      Group {
        Button {
          onEvent?(.move(.up))
        } label: {
          Color.clear
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.upArrow, modifiers: [])
        Button {
          onEvent?(.move(.down))
        } label: {
          Color.clear
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.downArrow, modifiers: [])

        Button {
          onEvent?(.move(.up))
        } label: {
          Color.clear
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.init("p"), modifiers: [.control])
        Button {
          onEvent?(.move(.down))
        } label: {
          Color.clear
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.init("n"), modifiers: [.control])
      }
      .frame(width: 0, height: 0)
      .accessibilityHidden(true)

      TextField("Execute a command…", text: $query)
        .padding()
        .font(.system(size: 20, weight: .light))
        .frame(height: 48)
        .textFieldStyle(.plain)
        .focused($isTextFieldFocused)
        .onChange(of: isTextFieldFocused) { _, focused in
          if !focused {
            onEvent?(.exit)
          }
        }
        .onExitCommand { onEvent?(.exit) }
        .onMoveCommand { onEvent?(.move($0)) }
        .onSubmit { onEvent?(.submit) }
    }
  }
}

private struct CommandPaletteList: View {
  let rows: [CommandPaletteItem]
  @Binding var selectedIndex: Int?
  @Binding var hoveredID: CommandPaletteItem.ID?
  let activate: (CommandPaletteItem.ID) -> Void

  var body: some View {
    if rows.isEmpty {
      EmptyView()
    } else {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.1.id) { index, row in
              CommandPaletteRowView(
                row: row,
                shortcutIndex: index < 5 ? index : nil,
                isSelected: isRowSelected(index: index),
                hoveredID: $hoveredID
              ) {
                activate(row.id)
              }
              .id(row.id)
            }
          }
          .padding(10)
        }
        .frame(maxHeight: 200)
        .onChange(of: selectedIndex) { _, newValue in
          guard let selectedIndex = newValue, rows.indices.contains(selectedIndex) else { return }
          proxy.scrollTo(rows[selectedIndex].id)
        }
      }
    }
  }

  private func isRowSelected(index: Int) -> Bool {
    guard let selectedIndex else { return false }
    if selectedIndex < rows.count {
      return selectedIndex == index
    }
    return index == rows.count - 1
  }
}

private struct CommandPaletteRowView: View {
  let row: CommandPaletteItem
  let shortcutIndex: Int?
  let isSelected: Bool
  @Binding var hoveredID: CommandPaletteItem.ID?
  let activate: () -> Void

  private var badge: String? {
    switch row.kind {
    case .checkForUpdates, .openRepository, .openSettings, .newWorktree, .refreshWorktrees,
      .openPullRequest, .markPullRequestReady, .mergePullRequest, .copyCiFailureLogs,
      .rerunFailedJobs, .openFailingCheckDetails, .worktreeSelect:
      return nil
    case .removeWorktree:
      return "Remove"
    case .archiveWorktree:
      return "Archive"
    }
  }

  private var leadingIcon: String? {
    switch row.kind {
    case .checkForUpdates:
      return "arrow.down.circle"
    case .openRepository:
      return "folder"
    case .openSettings:
      return "gearshape"
    case .newWorktree:
      return "plus"
    case .refreshWorktrees:
      return "arrow.clockwise"
    case .openPullRequest:
      return "arrow.up.right.square"
    case .markPullRequestReady:
      return "checkmark.seal"
    case .mergePullRequest:
      return "arrow.merge"
    case .copyCiFailureLogs:
      return "doc.on.doc"
    case .rerunFailedJobs:
      return "arrow.counterclockwise"
    case .openFailingCheckDetails:
      return "exclamationmark.triangle"
    case .worktreeSelect:
      return nil
    case .removeWorktree:
      return "trash"
    case .archiveWorktree:
      return "archivebox"
    }
  }

  private var emphasis: Bool {
    switch row.kind {
    case .checkForUpdates, .openRepository, .openSettings, .newWorktree, .refreshWorktrees,
      .openPullRequest, .markPullRequestReady, .mergePullRequest, .copyCiFailureLogs,
      .rerunFailedJobs, .openFailingCheckDetails:
      return true
    case .worktreeSelect, .removeWorktree, .archiveWorktree:
      return false
    }
  }

  private var explicitShortcutSymbols: [String]? {
    row.appShortcutSymbols
  }

  var body: some View {
    Button(action: activate) {
      HStack(spacing: 8) {
        if let leadingIcon {
          Image(systemName: leadingIcon)
            .foregroundStyle(emphasis ? .primary : .secondary)
            .font(.system(size: 14, weight: .medium))
            .frame(width: 16, height: 16, alignment: .center)
            .accessibilityHidden(true)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(row.title)
            .fontWeight(emphasis ? .medium : .regular)

          if let subtitle = row.subtitle {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        if let badge, !badge.isEmpty {
          Text(badge)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
              Capsule().fill(Color(nsColor: .quaternaryLabelColor))
            )
            .foregroundStyle(.secondary)
        }

        if let explicitShortcutSymbols {
          ShortcutSymbolsView(symbols: explicitShortcutSymbols)
            .foregroundStyle(.secondary)
        } else if let shortcutIndex {
          ShortcutSymbolsView(symbols: commandPaletteShortcutSymbols(for: shortcutIndex))
            .foregroundStyle(.secondary)
        }
      }
      .padding(8)
      .contentShape(Rectangle())
      .background(rowBackground)
      .cornerRadius(5)
    }
    .buttonStyle(.plain)
    .help(helpText)
    .onHover { hovering in
      hoveredID = hovering ? row.id : nil
    }
  }

  private var rowBackground: some View {
    Group {
      if isSelected {
        Color(nsColor: .selectedContentBackgroundColor)
      } else if hoveredID == row.id {
        Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
      } else {
        Color.clear
      }
    }
  }

  private var helpText: String {
    let base: String
    switch row.kind {
    case .worktreeSelect:
      base = "Switch to \(row.title)"
    case .checkForUpdates:
      base = "Check for Updates"
    case .openRepository:
      base = "Open Repository"
    case .openSettings:
      base = "Open Settings"
    case .newWorktree:
      base = "New Worktree"
    case .refreshWorktrees:
      base = "Refresh Worktrees"
    case .removeWorktree:
      base = "Remove \(row.title)"
    case .archiveWorktree:
      base = "Archive \(row.title)"
    case .openPullRequest:
      base = "Open pull request on GitHub"
    case .markPullRequestReady:
      base = "Mark pull request ready for review"
    case .mergePullRequest:
      base = "Merge pull request"
    case .copyCiFailureLogs:
      base = "Copy CI failure logs"
    case .rerunFailedJobs:
      base = "Re-run failed jobs"
    case .openFailingCheckDetails:
      base = "Open failing check details"
    }
    if let explicitShortcutLabel {
      return "\(base) (\(explicitShortcutLabel))"
    }
    if let shortcutIndex {
      return "\(base) (\(commandPaletteShortcutLabel(for: shortcutIndex)))"
    }
    return base
  }

  private var explicitShortcutLabel: String? {
    row.appShortcutLabel
  }
}

private struct ShortcutSymbolsView: View {
  let symbols: [String]

  var body: some View {
    HStack(spacing: 1) {
      ForEach(symbols, id: \.self) { symbol in
        Text(symbol)
          .frame(minWidth: 13)
      }
    }
  }
}

private struct CommandPaletteShortcutHandler: View {
  let items: [CommandPaletteItem]
  let activate: (CommandPaletteItem.ID) -> Void

  var body: some View {
    Group {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        shortcutButton(index: index, itemID: item.id)
      }
    }
    .frame(width: 0, height: 0)
    .accessibilityHidden(true)
  }

  private func shortcutButton(index: Int, itemID: CommandPaletteItem.ID) -> some View {
    Button {
      activate(itemID)
    } label: {
      Color.clear
    }
    .buttonStyle(.plain)
    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
  }
}

private func commandPaletteShortcutSymbols(for index: Int) -> [String] {
  ["⌘", "\(index + 1)"]
}

private func commandPaletteShortcutLabel(for index: Int) -> String {
  "Cmd+\(index + 1)"
}

extension NSColor {
  fileprivate var isLightColor: Bool {
    luminance > 0.5
  }

  fileprivate var luminance: Double {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    guard let rgb = usingColorSpace(.sRGB) else { return 0 }
    rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return (0.299 * red) + (0.587 * green) + (0.114 * blue)
  }
}
