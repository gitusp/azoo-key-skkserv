// SPDX-License-Identifier: MIT

import Core
import Logging
import SwiftUI

class AppState: ObservableObject {
    @AppStorage("host") var host: String = "127.0.0.1"
    @AppStorage("port") var port: Int = 1178
    @AppStorage("incomingCharset") var incomingCharset: IncomingCharset = .utf8
    @AppStorage("startServerAtLaunch") var startServerAtLaunch: Bool = false
    @AppStorage("inferenceLimit") var inferenceLimit: Int = 3

    @Published var running: Bool = false
    @Published var showingAlert: Bool = false
    @Published var errorMessage: String = ""

    @Published private var serverTask: Task<Void, Error>? = nil
    @Published private var server: SKKServer? = nil

    private let logger = Logger(label: "io.github.gitusp.azoo-key-skkserv")
}

extension AppState {
    /**
      * SKKServerを起動する。
      * `serverTask`にTaskを入れておき`cancel()`でサーバーを停止できる。
      *
      * NOTE: `startServer`が`AppState`のextensionであるべきなのかどうかとは思ったが、
      * ひとまず`running`や`serverTask`へのアクセスしやすさを優先してここに実装した。
      */
    @MainActor
    func startServer() {
        running = true
        serverTask = Task {
            do {
                if server == nil {
                    let version =
                        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                        ?? "Unknown"
                    server = SKKServer(version: version, logger: logger)
                    server?.prepare()
                }
                try await server!.run(
                    host: host, port: port, incomingCharset: incomingCharset.stringEncoding, inferenceLimit: inferenceLimit)
            } catch is CancellationError {
                // キャンセルが正常に完了した
                logger.notice("Server task was cancelled.")
            } catch {
                // キャンセル以外のエラーが発生した場合はアラートを表示する
                logger.error("Server task error: \(error)")
                errorMessage = error.localizedDescription
                showingAlert = true
            }
            running = false
            serverTask = nil
        }
    }

    func cancel() {
        serverTask?.cancel()
    }
}
