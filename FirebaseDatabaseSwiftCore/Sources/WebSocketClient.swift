//
//  WebSocketClient.swift
//  WebSocketClient
//
//  Created by Morten Bek Ditlevsen on 09/09/2021.
//

import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import NIOSSL


final class WebSocketClient {
    private let webSocketHandler: WebSocketHandler
    private let openClosure: () throws -> Void
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    func open() throws {
        try openClosure()
    }

    func close() {
        webSocketHandler.context?.close(promise: nil)
    }

    func send(data: Data) {
        webSocketHandler.send(data: data)
    }

    init(url: URL,
         headers: HTTPHeaders,
         onMessage: @escaping (Dictionary<String, Any>) -> Void,
         onClose: @escaping () -> Void) {
        self.webSocketHandler = WebSocketHandler(onMessage: onMessage, onClose: onClose)

        let httpHandler = HTTPInitialRequestHandler(url: url, headers: headers)

        let configuration = TLSConfiguration.makeClientConfiguration()
        let sslContext = try! NIOSSLContext(configuration: configuration)

        let bootstrap = ClientBootstrap(group: group)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { [webSocketHandler] channel in
                let sslHandler =  try! NIOSSLClientHandler(context: sslContext, serverHostname: url.host!)

                let websocketUpgrader = NIOWebSocketClientUpgrader(upgradePipelineHandler: { (channel: Channel, _: HTTPResponseHead) in
                    channel.pipeline.addHandler(webSocketHandler)
                })

                let config: NIOHTTPClientUpgradeConfiguration = (
                    upgraders: [ websocketUpgrader ],
                    completionHandler: { _ in
                        channel.pipeline.removeHandler(httpHandler, promise: nil)
                })

                return channel.pipeline.addHandler(sslHandler).flatMap {
                    channel.pipeline.addHTTPClientHandlers(leftOverBytesStrategy: .forwardBytes,
                                                           withClientUpgrade: config)
                        .flatMap {
                        channel.pipeline.addHandler(httpHandler)
                    }
                }
        }
        self.openClosure = {
            let channel = try bootstrap.connect(host: url.host!, port: url.port ?? 443).wait()
            print("CHANNEL", channel)
        }
    }
}

private final class HTTPInitialRequestHandler: ChannelInboundHandler, RemovableChannelHandler {
    public typealias InboundIn = HTTPClientResponsePart
    public typealias OutboundOut = HTTPClientRequestPart

    public let url: URL
    private let extraHeaders: HTTPHeaders

    public init(url: URL, headers: HTTPHeaders) {
        self.url = url
        self.extraHeaders = headers
    }

    public func channelActive(context: ChannelHandlerContext) {
        print("Client connected to \(context.remoteAddress!)")

        // We are connected. It's time to send the message to the server to initialize the upgrade dance.
        var headers = HTTPHeaders()
        headers.add(name: "Host", value: "\(url.host ?? ""):\(url.port ?? 443)")
        headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
        headers.add(name: "Content-Length", value: "\(0)")
        headers.add(contentsOf: extraHeaders)

        let uri = url.path + (url.query.map { "?\($0)"} ?? "")

        let requestHead = HTTPRequestHead(version: .http1_1,
                                          method: .GET,
                                          uri: uri,
                                          headers: headers)

        context.write(self.wrapOutboundOut(.head(requestHead)), promise: nil)

        let body = HTTPClientRequestPart.body(.byteBuffer(ByteBuffer()))
        context.write(self.wrapOutboundOut(body), promise: nil)

        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {

        let clientResponse = self.unwrapInboundIn(data)

        print("Upgrade failed")

        switch clientResponse {
        case .head(let responseHead):
            print("Received status: \(responseHead.status)")
        case .body(let byteBuffer):
            let string = String(buffer: byteBuffer)
            print("Received: '\(string)' back from the server.")
        case .end:
            print("Closing channel.")
            context.close(promise: nil)
        }
    }

    public func handlerRemoved(context: ChannelHandlerContext) {
        print("HTTP handler removed.")
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)

        // As we are not really interested getting notified on success or failure
        // we just pass nil as promise to reduce allocations.
        context.close(promise: nil)
    }
}

// The web socket handler to be used once the upgrade has occurred.
// One added, it sends a ping-pong round trip with "Hello World" data.
// It also listens for any text frames from the server and prints them.

private final class WebSocketHandler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame

    var context: ChannelHandlerContext?
    private let onClose: () -> Void
    private let onMessage: (Dictionary<String, Any>) -> Void

    public init(onMessage: @escaping (Dictionary<String, Any>) -> Void,
                onClose: @escaping () -> Void) {
        self.onClose = onClose
        self.onMessage = onMessage
    }

    // This is being hit, channel active won't be called as it is already added.
    public func handlerAdded(context: ChannelHandlerContext) {
        self.context = context
        print("WebSocket handler added.")
    }

    func send(data: Data) {
        guard let context = context else {
            return
        }
        let stringData = String(data: data, encoding: .utf8) ?? ""
        print("SENDING", stringData)
        let send = {
            let buffer = context.channel.allocator.buffer(string: stringData)
            let frame = WebSocketFrame(fin: true, opcode: .text, maskKey: .random(), data: buffer)
            context.write(self.wrapOutboundOut(frame), promise: nil)
        }
        if !context.eventLoop.inEventLoop {
            context.eventLoop.execute(send)
        } else {
            send()
        }
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)

        switch frame.opcode {
        case .text:
            var byteBuffer = frame.unmaskedData
            let bytes = byteBuffer.readBytes(length: byteBuffer.readableBytes) ?? []
            let data = Data(bytes)
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> {
                print("Websocket: Received \(json)")
                onMessage(json)
//                delegate?.onMessage(self, withMessage: json as NSDictionary)
            }
        case .connectionClose:
            self.receivedClose(context: context, frame: frame)
        case .binary, .continuation, .ping, .pong:
            // We ignore these frames.
            break
        default:
            // Unknown frames are errors.
            self.closeOnError(context: context)
        }
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
        // Handle a received close frame. We're just going to close.
        print("Received Close instruction from server")
        context.close(promise: nil)
        onClose()
    }

    private func closeOnError(context: ChannelHandlerContext) {
        // We have hit an error, we want to close. We do that by sending a close frame and then
        // shutting down the write side of the connection. The server will respond with a close of its own.
        var data = context.channel.allocator.buffer(capacity: 2)
        data.write(webSocketErrorCode: .protocolError)
        let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
        context.write(self.wrapOutboundOut(frame)).whenComplete { (_: Result<Void, Error>) in
            context.close(mode: .output, promise: nil)
        }
        onClose()
    }
}
