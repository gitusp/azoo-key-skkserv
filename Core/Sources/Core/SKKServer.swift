// SPDX-License-Identifier: MIT

import Foundation
import NIOCore
import NIOPosix
import KanaKanjiConverterModuleWithDefaultDictionary
import Logging

private func createZenzaiMode(inferenceLimit: Int) -> ConvertRequestOptions.ZenzaiMode {
    return .on(
        weight: Bundle.module.url(forResource: "zenz-v1", withExtension: "gguf")!,
        inferenceLimit: inferenceLimit,
        personalizationMode: nil,
        versionDependentMode: .v1
    )
}

private func createConvertOption(inferenceLimit: Int, version: String, requireJapanesePrediction: Bool = false) -> ConvertRequestOptions {
    return ConvertRequestOptions(
        // 日本語予測変換
        requireJapanesePrediction: requireJapanesePrediction,
        // 英語予測変換
        requireEnglishPrediction: false,
        // 入力言語
        keyboardLanguage: .ja_JP,
        // 学習タイプ
        learningType: .nothing,
        // TODO: 扱いについて検討
        memoryDirectoryURL: URL(fileURLWithPath: ""),
        sharedContainerURL: URL(fileURLWithPath: ""),
        textReplacer: .withDefaultEmojiDictionary(),
        specialCandidateProviders: KanaKanjiConverter.defaultSpecialCandidateProviders,
        zenzaiMode: createZenzaiMode(inferenceLimit: inferenceLimit),
        metadata: .init(versionString: version)
    )
}

private func sanitizeYomi(yomi: String) -> String {
    return yomi.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacing(/([ぁ-ん])[a-z]$/) { matches in matches.1 }
}

@MainActor public struct SKKServer {
    let allocator = ByteBufferAllocator()
    let converter: KanaKanjiConverter
    let version: String
    let logger: Logger

    public init(version: String, logger: Logger) {
        self.version = version
        self.logger = logger
        // コンバータ初期化
        converter = KanaKanjiConverter.withDefaultDictionary()
    }

    public func prepare() {
        // HACK: ダミーリクエストを送信してモデルを先読みしておく
        var dummyComposingText = ComposingText()
        dummyComposingText.insertAtCursorPosition("もでるさきよみ", inputStyle: .direct)
        let convertOption = createConvertOption(inferenceLimit: 1, version: version)
        _ = converter.requestCandidates(dummyComposingText, options: convertOption)
    }

    /**
      * SKKServを起動する。
      *
      * Taskの中でrunServerを実行しTask.cancel()を呼び出すことでサーバーを停止できる。
      *
      * ```swift
      * // SKKServを起動
      * let task = Task {
      *     do {
      *         try await run()
      *     } catch is CancellationError {
      *         // タスクがキャンセルされたとき
      *     } catch {
      *         // その他のエラーが発生したとき
      *     }
      * }
      * // SKKServを停止
      * task.cancel()
      * ```
      */
    public func run(host: String = "127.0.0.1", port: Int = 1178, incomingCharset: String.Encoding = .utf8, inferenceLimit: Int = 1) async throws {
        let convertOption = createConvertOption(inferenceLimit: inferenceLimit, version: version)
        let predictionOption = createConvertOption(inferenceLimit: inferenceLimit, version: version, requireJapanesePrediction: true)

        // こちらのガイドを参考に実装した。
        // https://swiftonserver.com/using-swiftnio-channels/
        let server = try await ServerBootstrap(group: NIOSingletons.posixEventLoopGroup)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .bind(
                host: host,
                port: port
            ) { channel in
                channel.eventLoop.makeCompletedFuture {
                    return try NIOAsyncChannel(
                        wrappingChannelSynchronously: channel,
                        configuration: NIOAsyncChannel.Configuration(
                            inboundType: ByteBuffer.self,
                            outboundType: ByteBuffer.self
                        )
                    )
                }
            }
        logger.notice("Server started on port \(port) with incoming charset \(incomingCharset.rawValue).")

        try await withThrowingDiscardingTaskGroup { group in
            try await server.executeThenClose { clients in
                for try await client in clients {
                    group.addTask {
                        await handleClient(client: client, host: host, port: port, incomingCharset: incomingCharset, convertOption: convertOption, predictionOption: predictionOption)
                    }
                }
            }
        }
    }

    func handleClient(client: NIOAsyncChannel<ByteBuffer, ByteBuffer>, host: String, port: Int, incomingCharset: String.Encoding, convertOption: ConvertRequestOptions, predictionOption: ConvertRequestOptions) async {
        // クライアントが先にソケットを閉じている状態でソケットへの書き込みを行ったりすると例外が発生し、
        // そのあとの接続でinboundMessagesからメッセージが取得できなくなってしまう。
        // それを防ぐため例外をキャッチする必要がある。
        do {
            try await client.executeThenClose { inboundMessages, outbound in
                for try await inboundMessage in inboundMessages {
                    if let bytes = inboundMessage.getBytes(at: 0, length: inboundMessage.readableBytes),
                       let message = String(bytes: bytes, encoding: incomingCharset) {
                        let opcode = message.prefix(1)

                        switch (opcode) {
                        case "0":
                            return
                        case "1":
                            let yomi = sanitizeYomi(yomi: String(message.suffix(message.count - 1)))
                            var composingText = ComposingText()
                            composingText.insertAtCursorPosition(yomi, inputStyle: .direct)
                            let results = converter.requestCandidates(composingText, options: convertOption)
                            let excludeTexts = yomi.applyingTransform(.hiraganaToKatakana, reverse: false)
                                .map { katakana in katakana != yomi ? Set([yomi, katakana]) : Set([yomi]) }
                                ?? Set([yomi])
                            let candidates = results.mainResults
                                // 読み全文に対応するもの以外・読みと完全一致するもの・読みのカタカナ版と一致するものは除去
                                .filter({ result in result.rubyCount == yomi.count && !excludeTexts.contains(result.text) })
                            let content = candidates.count == 0
                            ? "4\n"
                            : "1/"
                            + candidates.map({ result in result.text }).joined(by: "/")
                            + "/\n"
                            try await outbound.write(allocator.buffer(string: content))
                        case "2":
                            try await outbound.write(allocator.buffer(string: "azoo-key-skkserv/" + version + " "))
                        case "3":
                            let hostname = Host.current().localizedName ?? ""
                            try await outbound.write(allocator.buffer(string: "\(hostname)/\(host):\(port) "))
                        case "4":
                            let yomi = sanitizeYomi(yomi: String(message.suffix(message.count - 1)))
                            var composingText = ComposingText()
                            composingText.insertAtCursorPosition(yomi, inputStyle: .direct)
                            let results = converter.requestCandidates(composingText, options: predictionOption)
                            var seen = Set<String>()
                            let candidates = results.mainResults
                                // 読み全文以下の文字長の候補・result.dataが複数の候補は除外
                                .filter({ result in result.data.count == 1 && result.rubyCount > yomi.count })
                                // ひらがなに変換(できないものは除外)
                                .compactMap({ result in result.data.map({ d in d.ruby }).joined().applyingTransform(.hiraganaToKatakana, reverse: true)})
                                // 重複を除去(最初の出現を保持)
                                .filter({ seen.insert($0).inserted })
                            let content = candidates.count == 0
                            ? "4\n"
                            : "1/"
                            + candidates.joined(by: "/")
                            + "/\n"
                            try await outbound.write(allocator.buffer(string: content))
                        default:
                            logger.warning("Unsupported opcode: \(opcode)")
                            break
                        }
                    }
                }
            }
            logger.notice("Connection is closed")
        } catch {
            logger.warning("Hit error: \(error)")
        }
    }
}
