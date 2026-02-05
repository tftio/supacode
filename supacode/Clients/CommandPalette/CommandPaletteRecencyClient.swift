import ComposableArchitecture
import Foundation
import Sharing

struct CommandPaletteRecencyClient {
  var load: @Sendable () async -> [CommandPaletteItem.ID: TimeInterval]
  var save: @Sendable ([CommandPaletteItem.ID: TimeInterval]) async -> Void
}

extension CommandPaletteRecencyClient: DependencyKey {
  static let liveValue: CommandPaletteRecencyClient = {
    CommandPaletteRecencyClient(
      load: {
        @Shared(.appStorage("commandPaletteItemRecency")) var recency: [String: Double] = [:]
        return recency
      },
      save: { updated in
        @Shared(.appStorage("commandPaletteItemRecency")) var recency: [String: Double] = [:]
        $recency.withLock {
          $0 = updated
        }
      }
    )
  }()

  static let testValue = CommandPaletteRecencyClient(
    load: { [:] },
    save: { _ in }
  )
}

extension DependencyValues {
  var commandPaletteRecency: CommandPaletteRecencyClient {
    get { self[CommandPaletteRecencyClient.self] }
    set { self[CommandPaletteRecencyClient.self] = newValue }
  }
}
