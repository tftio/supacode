//
//  supacodeApp.swift
//  supacode
//
//  Created by khoi on 20/1/26.
//

import GhosttyKit
import SwiftUI

@main
struct supacodeApp: App {
    @StateObject private var ghostty: GhosttyRuntime
    
    init() {
        if ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv) != GHOSTTY_SUCCESS {
                  preconditionFailure("ghostty_init failed")
              }
        _ghostty = StateObject(wrappedValue: GhosttyRuntime())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(runtime: ghostty)
        }
    }
}
