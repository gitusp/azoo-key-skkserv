import Testing
import Foundation
import NIOCore
import NIOPosix
import Logging
@testable import Core

@Suite("SKKServer Version Test")
struct SKKServerVersionTest {

    @Test("SKKServerに接続し、バージョン情報を取得する")
    func testSKKServerVersion() async throws {
        let port = 11780 // テスト用のポート番号
        let server = await SKKServer(version: "test", logger: Logger(label: "test"))
        await server.prepare()

        let serverTask = Task {
            try await server.run(host: "127.0.0.1", port: port, incomingCharset: String.Encoding.utf8, inferenceLimit: 1)
        }

        // サーバーが起動するまで少し待つ
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒

        do {
            let group = NIOSingletons.posixEventLoopGroup
            let bootstrap = ClientBootstrap(group: group)

            let channel = try await bootstrap.connect(host: "127.0.0.1", port: port) { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(SKKServHandler())
                    return try NIOAsyncChannel(
                        wrappingChannelSynchronously: channel,
                        configuration: NIOAsyncChannel.Configuration(
                            inboundType: String.self,
                            outboundType: SKKServRequest.self
                        )
                    )
                }
            }

            try await channel.executeThenClose { inbound, outbound in
                try await outbound.write(.version)
                guard let response = try await inbound.first(where: { _ in true }) else {
                    Issue.record("応答を受信できません")
                    return
                }
                #expect(response == "azoo-key-skkserv/test", "応答が期待されるプレフィックスで始まっていません: \(response)")

                try await outbound.write(.end)
            }
        } catch {
            Issue.record("テスト中にエラーが発生しました: \(error)")
        }

        // サーバーを停止
        serverTask.cancel()

        // タスクの完了を待つ
        do {
            try await serverTask.value
        } catch is CancellationError {
            // キャンセルエラーは期待される
        }
    }
}

enum SKKServRequest {
    case end // "0"
    // case candidates(String) // "1<見出し語> "
    case version // "2"
    // case host // "3"
    // case completion // "4<見出し語> "

    var responseDelimiter: UInt8 {
        switch self {
        case .end:
            return 0
        case .version:
            return UInt8(ascii: " ")
        }
    }
}

enum SKKServHandlerError: Error {
    case invalidResponse
}

private final class SKKServHandler: ChannelDuplexHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = String
    typealias OutboundIn = SKKServRequest
    typealias OutboundOut = ByteBuffer

    var overflowBuffer : ByteBuffer? = nil
    var lastRequest: SKKServRequest? = nil

    // MARK: - Reading
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard let delimiter = lastRequest?.responseDelimiter else {
            context.fireErrorCaught(SKKServHandlerError.invalidResponse)
            return
        }
        var buffer = self.unwrapInboundIn(data)
        let readableBytes = buffer.readableBytesView

        if let index = readableBytes.firstIndex(of: delimiter), let message = buffer.readString(length: index) {
            context.fireChannelRead(wrapInboundOut(message))
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let request = unwrapOutboundIn(data)
        let allocator = context.channel.allocator
        var out = allocator.buffer(capacity: 1)
        switch request {
        case .end:
            out.writeString("0")
        case .version:
            out.writeString("2")
            break
        }
        lastRequest = request
        context.write(wrapOutboundOut(out), promise: promise)
    }
}
