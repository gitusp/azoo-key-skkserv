// SPDX-License-Identifier: MIT

import SwiftUI
import Core
import Logging

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimum = 1
        formatter.maximum = 65535
        return formatter
    }()

    var body: some View {
        VStack {
            Form {
                TextField("Host", text: $appState.host, prompt: Text("127.0.0.1"))
                    .disabled(appState.running)
                TextField("Port", value: $appState.port, formatter: formatter, prompt: Text("1178"))
                    .disabled(appState.running)
                TextField("Inference Limit", value: $appState.inferenceLimit, formatter: formatter, prompt: Text("1"))
                    .disabled(appState.running)
                Picker("Incoming Charset", selection: $appState.incomingCharset) {
                    ForEach(IncomingCharset.allCases, id: \.self) { charset in
                        Text(charset.rawValue).tag(charset)
                    }
                }
                .disabled(appState.running)
                Toggle("Start Server At Launch", isOn: $appState.startServerAtLaunch)
                Button("Start Server") {
                    appState.startServer()
                }
                .disabled(appState.running)
                Button("Stop Server") {
                    appState.cancel()
                }
                .disabled(!appState.running)
            }
        }
        .padding()
        .alert("Error", isPresented: $appState.showingAlert) {
            Button("OK") { }
        } message: {
            Text(appState.errorMessage)
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 320, height: 220)
}
