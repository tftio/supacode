import AppKit
import SwiftUI

@MainActor
@Observable
final class CommandKeyObserver {
  var isPressed: Bool
  private var monitor: Any?
  private var didBecomeActiveObserver: NSObjectProtocol?
  private var didResignActiveObserver: NSObjectProtocol?

  init() {
    isPressed = NSEvent.modifierFlags.contains(.command)
    monitor = nil
    didBecomeActiveObserver = nil
    didResignActiveObserver = nil
    configureObservers()
  }

  private func configureObservers() {
    monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      MainActor.assumeIsolated {
        self?.isPressed = event.modifierFlags.contains(.command)
      }
      return event
    }
    let center = NotificationCenter.default
    didBecomeActiveObserver = center.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.isPressed = NSEvent.modifierFlags.contains(.command)
      }
    }
    didResignActiveObserver = center.addObserver(
      forName: NSApplication.didResignActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.isPressed = false
      }
    }
  }
}
