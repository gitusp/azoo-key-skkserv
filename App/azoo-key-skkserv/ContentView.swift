// SPDX-License-Identifier: MIT

import SwiftUI
import Core
import Logging

struct ContentView: View {
    @AppStorage("host") var host: String = "127.0.0.1"
    @AppStorage("port") var port: Int = 1178
    @AppStorage("incomingCharset") var incomingCharset: IncomingCharset = .utf8
    @AppStorage("startServerAtLaunch") var startServerAtLaunch: Bool = false
    @AppStorage("inferenceLimit") var inferenceLimit: Int = 3
    @State var running: Bool = false
    @State var serverTask: Task<Void, Error>? = nil
    @State var showingAlert: Bool = false
    @State var errorMessage: String = ""
    let logger = Logger(label: "io.github.gitusp.azoo-key-skkserv")
    @State var server: SKKServer? = nil
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimum = 1
        formatter.maximum = 65535
        return formatter
    }()

    var body: some View {
        VStack {
            Form {
                TextField("Host", text: $host, prompt: Text("127.0.0.1"))
                    .disabled(running)
                TextField("Port", value: $port, formatter: formatter, prompt: Text("1178"))
                    .disabled(running)
                TextField("Inference Limit", value: $inferenceLimit, formatter: formatter, prompt: Text("1"))
                    .disabled(running)
                Picker("Incoming Charset", selection: $incomingCharset) {
                    ForEach(IncomingCharset.allCases, id: \.self) { charset in
                        Text(charset.rawValue).tag(charset)
                    }
                }
                .disabled(running)
                Toggle("Start Server At Launch", isOn: $startServerAtLaunch)
                Button("Start Server") {
                    startServer()
                }
                .disabled(running)
                Button("Stop Server") {
                    serverTask?.cancel()
                }
                .disabled(!running)
            }
        }
        .padding()
        .onAppear {
            if startServerAtLaunch {
                startServer()
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    func startServer() {
        running = true
        serverTask = Task {
            do {
                if server == nil {
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                    server = SKKServer(version: version, logger: logger)
                    server?.prepare()
                }
                try await server!.run(host: host, port: port, incomingCharset: incomingCharset.stringEncoding, inferenceLimit: inferenceLimit)
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
}

#Preview {
    ContentView()
        .frame(width: 320, height: 220)
}
