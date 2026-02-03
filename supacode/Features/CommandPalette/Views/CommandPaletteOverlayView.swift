import ComposableArchitecture
import SwiftUI

private typealias MoveDirection = CommandPaletteFeature.MoveDirection

struct CommandPaletteOverlayView: View {
  @Bindable var store: StoreOf<CommandPaletteFeature>
  let rows: [CommandPaletteWorktreeRow]
  @FocusState private var isQueryFocused: Bool
  @State private var hoveredID: Worktree.ID?

  var body: some View {
    if store.isPresented {
      ZStack(alignment: .top) {
        Button {
          store.send(.setPresented(false))
        } label: {
          Color.clear
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .accessibilityHidden(true)

        CommandPaletteCard(
          query: $store.query,
          selectedIndex: $store.selectedIndex,
          rows: rows,
          hoveredID: $hoveredID,
          isQueryFocused: $isQueryFocused,
          dismiss: {
            store.send(.setPresented(false))
          }
        ) { id in
          store.send(.activateWorktree(id))
        }
        .padding()
      }
      .ignoresSafeArea()
      .onChange(of: store.isPresented) { _, newValue in
        isQueryFocused = newValue
      }
      .task {
        isQueryFocused = true
      }
    }
  }
}

private struct CommandPaletteCard: View {
  @Binding var query: String
  @Binding var selectedIndex: Int?
  let rows: [CommandPaletteWorktreeRow]
  @Binding var hoveredID: Worktree.ID?
  @FocusState.Binding var isQueryFocused: Bool
  let dismiss: () -> Void
  let activate: (Worktree.ID) -> Void

  private var filteredRows: [CommandPaletteWorktreeRow] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else { return rows }
    return rows.filter { $0.title.localizedStandardContains(trimmedQuery) }
  }

  var body: some View {
    let filteredRows = filteredRows
    VStack {
      CommandPaletteQueryField(query: $query, isQueryFocused: _isQueryFocused) { event in
        switch event {
        case .exit:
          dismiss()

        case .submit:
          activateSelected(in: filteredRows)

        case .move(let direction):
          moveSelection(direction, count: filteredRows.count)
        }
      }
      .onChange(of: query) { _, newValue in
        if newValue.isEmpty {
          if selectedIndex == 0 {
            selectedIndex = nil
          }
        } else if selectedIndex == nil, !filteredRows.isEmpty {
          selectedIndex = 0
        }
      }
      .onChange(of: filteredRows.count) { _, newValue in
        if newValue == 0 {
          selectedIndex = nil
        } else if let selectedIndex, selectedIndex >= newValue {
          self.selectedIndex = newValue - 1
        }
      }

      Divider()

      CommandPaletteShortcutHandler(count: min(5, filteredRows.count)) { index in
        guard filteredRows.indices.contains(index) else { return }
        activate(filteredRows[index].id)
      }

      CommandPaletteList(
        rows: filteredRows,
        selectedIndex: $selectedIndex,
        hoveredID: $hoveredID
      ) { id in
        activate(id)
      }
    }
    .frame(maxWidth: 520)
    .background(.regularMaterial)
    .clipShape(.rect(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(.quaternary, lineWidth: 1)
    )
    .shadow(radius: 24)
  }

  private func moveSelection(_ direction: MoveDirection, count: Int) {
    guard count > 0 else {
      selectedIndex = nil
      return
    }
    let maxIndex = count - 1
    switch direction {
    case .up:
      if let selectedIndex {
        self.selectedIndex = selectedIndex == 0 ? maxIndex : selectedIndex - 1
      } else {
        selectedIndex = maxIndex
      }
    case .down:
      if let selectedIndex {
        self.selectedIndex = selectedIndex == maxIndex ? 0 : selectedIndex + 1
      } else {
        selectedIndex = 0
      }
    }
  }

  private func activateSelected(in rows: [CommandPaletteWorktreeRow]) {
    guard let selectedIndex else { return }
    if rows.indices.contains(selectedIndex) {
      activate(rows[selectedIndex].id)
    } else if let last = rows.last {
      activate(last.id)
    }
  }

}

private struct CommandPaletteQueryField: View {
  @Binding var query: String
  @FocusState.Binding var isQueryFocused: Bool
  var onEvent: (CommandPaletteKeyboardEvent) -> Void

  enum CommandPaletteKeyboardEvent: Equatable {
    case exit
    case submit
    case move(MoveDirection)
  }

  var body: some View {
    ZStack {
      TextField("Search worktrees...", text: $query)
        .textFieldStyle(.plain)
        .padding()
        .font(.title3)
        .focused($isQueryFocused)
        .onChange(of: isQueryFocused) { _, newValue in
          if !newValue {
            onEvent(.exit)
          }
        }
        .onExitCommand { onEvent(.exit) }
        .onMoveCommand {
          switch $0 {
          case .up:
            onEvent(.move(.up))
          case .down:
            onEvent(.move(.down))
          default:
            break
          }
        }
        .onSubmit { onEvent(.submit) }
    }
  }
}

private struct CommandPaletteList: View {
  let rows: [CommandPaletteWorktreeRow]
  @Binding var selectedIndex: Int?
  @Binding var hoveredID: Worktree.ID?
  let activate: (Worktree.ID) -> Void

  var body: some View {
    if rows.isEmpty {
      Text("No matches")
        .foregroundStyle(.secondary)
        .padding()
    } else {
      ScrollViewReader { proxy in
        ScrollView {
          VStack {
            ForEach(rows.enumerated(), id: \.element.id) { index, row in
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
          .padding()
        }
        .frame(maxHeight: 240)
        .scrollIndicators(.hidden)
        .onChange(of: selectedIndex) { _, _ in
          guard let selectedIndex, rows.indices.contains(selectedIndex) else { return }
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
  let row: CommandPaletteWorktreeRow
  let shortcutIndex: Int?
  let isSelected: Bool
  @Binding var hoveredID: Worktree.ID?
  let activate: () -> Void

  var body: some View {
    Button(action: activate) {
      HStack {
        VStack(alignment: .leading) {
          Text(row.title)
            .foregroundStyle(.primary)
          if let subtitle = row.subtitle, !subtitle.isEmpty {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        if let shortcutIndex {
          ShortcutHintView(
            text: commandPaletteShortcutDisplay(for: shortcutIndex),
            color: .secondary
          )
          .monospaced()
        }
      }
      .padding()
      .background(rowBackground)
      .clipShape(.rect(cornerRadius: 8, style: .continuous))
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
        Color.accentColor.opacity(0.2)
      } else if hoveredID == row.id {
        Color.secondary.opacity(0.15)
      } else {
        Color.clear
      }
    }
  }

  private var helpText: String {
    if let shortcutIndex {
      return "Switch to \(row.title) (\(commandPaletteShortcutDisplay(for: shortcutIndex)))"
    }
    return "Switch to \(row.title)"
  }
}

private struct CommandPaletteShortcutHandler: View {
  let count: Int
  let activate: (Int) -> Void

  var body: some View {
    Group {
      if count >= 1 {
        shortcutButton(index: 0)
      }
      if count >= 2 {
        shortcutButton(index: 1)
      }
      if count >= 3 {
        shortcutButton(index: 2)
      }
      if count >= 4 {
        shortcutButton(index: 3)
      }
      if count >= 5 {
        shortcutButton(index: 4)
      }
    }
    .frame(width: 0, height: 0)
    .accessibilityHidden(true)
  }

  private func shortcutButton(index: Int) -> some View {
    Button {
      activate(index)
    } label: {
      Color.clear
    }
    .buttonStyle(.plain)
    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
  }
}

private func commandPaletteShortcutDisplay(for index: Int) -> String {
  "Cmd+\(index + 1)"
}
