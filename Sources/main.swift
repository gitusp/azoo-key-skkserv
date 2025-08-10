import Foundation
import ArgumentParser
import Core
import Logging

LoggingSystem.bootstrap(StreamLogHandler.standardError)
let logger = Logger(label: "io.github.gitusp.azoo-key-skkserv")

let version = "0.2.0"

struct AzooKeySkkserv: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A SKK server powered by AzooKeyKanaKanjiConverter",
        version: version
    )

    @Option(help: "The network port number to use.")
    var port: Int = 1178

    @Option(help: "The expected incoming character set.")
    var incomingCharset: IncomingCharset = .utf8

    @Option(help: "Maximum number of inferences for AI-based conversion.")
    var inferenceLimit: Int = 3

    func run() throws {
        Task {
            do {
                try await runServer(context: self)
            } catch let error {
                logger.error("An error occurred: \(error)")
                abort()
            }
        }

        dispatchMain()
    }
}

AzooKeySkkserv.main()

// 文字コードオプション
enum IncomingCharset: String, ExpressibleByArgument, CaseIterable {
    case utf8 = "UTF-8"
    case eucjp = "EUC-JP"

    static var defaultCompletionKind: CompletionKind {
        .list(IncomingCharset.allCases.map { $0.rawValue })
    }

    var stringEncoding: String.Encoding {
        switch self {
            case .utf8: return .utf8
            case .eucjp: return .japaneseEUC
        }
    }
}

func runServer(context: AzooKeySkkserv) async throws {
    let server = await SKKServer(version: version, logger: logger)
    await server.prepare()
    try await server.run(host: "127.0.0.1", port: context.port, incomingCharset: context.incomingCharset.stringEncoding, inferenceLimit: context.inferenceLimit)
}
