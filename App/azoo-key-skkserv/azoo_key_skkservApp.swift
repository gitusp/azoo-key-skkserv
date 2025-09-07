// SPDX-License-Identifier: MIT

import SwiftUI
import Logging
import LoggingOSLog

@main
struct azoo_key_skkservApp: App {
    @ObservedObject var appState = AppState()

    init() {
        LoggingSystem.bootstrap(LoggingOSLog.init)
        if appState.startServerAtLaunch {
            appState.startServer()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 320, height: 220)
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}
