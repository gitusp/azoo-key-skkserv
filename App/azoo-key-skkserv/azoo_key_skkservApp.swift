// SPDX-License-Identifier: MIT

import SwiftUI
import Logging
import LoggingOSLog

@main
struct azoo_key_skkservApp: App {
    init() {
        LoggingSystem.bootstrap(LoggingOSLog.init)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 320, height: 220)
        }
        .windowResizability(.contentSize)
    }
}
