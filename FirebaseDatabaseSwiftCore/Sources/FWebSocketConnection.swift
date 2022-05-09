//
//  FWebSocketConnection.swift
//  FWebSocketConnection
//
//  Created by Morten Bek Ditlevsen on 04/09/2021.
//

import Foundation
import NIOHTTP1

@objc public protocol FWebSocketDelegate: NSObjectProtocol {
    @objc func onMessage(_ fwebSocket: AnyObject, withMessage message: [String: Any])
    @objc func onDisconnect(_ fwebSocket: AnyObject, wasEverConnected: Bool)
}

private let kAppCheckTokenHeader = "X-Firebase-AppCheck"
private let kUserAgentHeader = "User-Agent"
private let kGoogleAppIDHeader = "X-Firebase-GMPID"

extension String {
    func split(by length: Int) -> [Substring] {
        var startIndex = self.startIndex
        var results = [Substring]()

        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            results.append(self[startIndex..<endIndex])
            startIndex = endIndex
        }

        return results
    }
}

public class FWebSocketConnection {
    var connectionId: NSNumber
    var totalFrames: Int
    var buffering: Bool {
        frame != nil
    }
    var dispatchQueue: DispatchQueue
    var frame: String?
    var everConnected: Bool
    var isClosed: Bool
    var keepAlive: Timer?
    var client: WebSocketClient?

    public weak var delegate: FWebSocketDelegate?
    public func open() {
        FFLog("I-RDB083002", "(wsc:\(self.connectionId)) FWebSocketConnection open)")
        assert(delegate != nil)
        everConnected = false
        do {
            try client?.open()
        } catch {
            print("ERROR connecting: \(error)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + kWebsocketConnectTimeout) { [weak self] in
            self?.closeIfNeverConnected()
        }
    }

    private func closeIfNeverConnected() {
        if !everConnected {
            FFLog("I-RDB083012", "(wsc:\(connectionId)) Websocket timed out on connect")
            client?.close()
        }
    }

    public func close() {
        FFLog("I-RDB083003", "(wsc:\(connectionId)) FWebSocketConnection is being closed.")
        isClosed = true
        client?.close()
    }

    public func start() {
        print("START")
    }

    private func resetKeepAlive() {
        guard let keepAlive = keepAlive else {
            return
        }

        let newTime = Date(timeIntervalSinceNow: kWebsocketKeepaliveInterval)
        // Calling setFireDate is actually kinda' expensive, so wait at least 5
        // seconds before updating it.
        if newTime.timeIntervalSince(keepAlive.fireDate) > 5 {
            FFLog("I-RDB083014", "(wsc:\(self.connectionId)) resetting keepalive, to \(newTime) ; old: \(keepAlive.fireDate)")
            keepAlive.fireDate = newTime
        }
    }

    public func send(_ dictionary: [String: Any]) {
        resetKeepAlive()

        guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: []) else {
            return
        }
        guard let string = String(data: data, encoding: .utf8) else {
            return
        }

        let chunks = string.split(by: kWebsocketMaxFrameSize)
        if chunks.count > 1 {
            client?.send(string: "\(chunks.count)")
        }
        for chunk in chunks {
            client?.send(string: chunk)
        }
    }

    public init(with connectionURL: String,
                      andQueue queue: DispatchQueue,
                      googleAppID: String,
                      appCheckToken: String?,
                      userAgent: String) {
        self.everConnected = false
        self.isClosed = false
        self.connectionId =  NSNumber(value: 404)//[FUtilities LUIDGenerator];
        self.totalFrames = 0
        self.dispatchQueue = queue
        self.frame = nil

        FFLog("I-RDB083001", "(wsc: \(connectionId)) Connecting to:\(connectionURL) as \(userAgent))")

        let url = URL(string: connectionURL)!

        let headers = createHeaders(with: connectionURL,
                                    userAgent: userAgent,
                                    googleAppID: googleAppID,
                                    appCheckToken: appCheckToken)

        self.client = WebSocketClient(url: url,
                                      headers: headers,
                                      onOpen: { [weak self] in

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                FFLog("I-RDB083008", "(wsc:\(self.connectionId)) webSocketDidOpen")
                self.everConnected = true

                self.keepAlive = Timer.scheduledTimer(withTimeInterval: kWebsocketKeepaliveInterval, repeats: true, block: { [weak self] timer in
                    guard let self = self else { return }
                    if !self.isClosed {
                        FFLog("I-RDB083004", "(wsc:\(self.connectionId)) nop")
                        // Note: the backend is expecting a string "0" here, not any special
                        // ping/pong from build in websocket APIs.
                        self.client?.send(string: "0")
                    } else {
                        FFLog("I-RDB083005",
                              "(wsc:\(self.connectionId) No more websocket; invalidating nop timer.")
                        timer.invalidate()
                    }
                })
                FFLog("I-RDB083009", "(wsc:\(self.connectionId) nop timer kicked off")
            }
        }, onMessage: { [weak self] message in
            guard let self = self else { return }
            self.handleIncomingFrame(message)
        }, onClose: { [weak self] in
            guard let self = self else { return }
            self.onClose()
        })
    }

    private func shutdown() {
        isClosed = true
        self.delegate?.onDisconnect(self, wasEverConnected: self.everConnected)
    }

    private func onClose() {
        if !isClosed {
            FFLog("I-RDB083013", "Websocket is closing itself")
            self.shutdown()
        }
        client = nil
        if keepAlive?.isValid ?? false {
            keepAlive?.invalidate()
        }
    }

    private func appendFrame(_ message: String) {
        let combined = (frame ?? "") + message
        frame = combined
        totalFrames -= 1

        if totalFrames == 0 {
            // Call delegate and pass an immutable version of the frame
            let data = Data(combined.utf8)
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("Websocket: Received \(json)")
                #warning("TEMPORARY WORKAROUND FOR GETTING CALLBACK ON MAIN QUEUE")
                DispatchQueue.main.async {
                    self.delegate?.onMessage(self, withMessage: json)
                }
            }

            frame = nil
            FFLog("I-RDB083007",
                  "(wsc:\(connectionId)) handleIncomingFrame sending complete frame: \(totalFrames)")
        }
    }

    private func handleNewFrameCount(_ count: Int) {
        totalFrames = count
        frame = ""
        FFLog("I-RDB083006", "(wsc:\(connectionId)) handleNewFrameCount: \(count)")
    }

    private func extractFrameCount(_ message: String) -> String? {
        if message.count <= 4 {
            let frameCount = Int(message) ?? 0
            if frameCount > 0 {
                handleNewFrameCount(frameCount)
                return nil
            }
        }
        handleNewFrameCount(1)
        return message
    }

    private func handleIncomingFrame(_ message: String) {
        resetKeepAlive()
        if buffering {
            appendFrame(message)
        } else {
            if let remaining = extractFrameCount(message) {
                appendFrame(remaining)
            }
        }
    }
}

private  func createHeaders(with url: String,
                            userAgent: String,
                            googleAppID: String,
                            appCheckToken: String?) -> HTTPHeaders {

    var headers = HTTPHeaders()
    if let appCheckToken = appCheckToken {
        headers.add(name: kAppCheckTokenHeader, value: appCheckToken)
    }
    headers.add(name: kUserAgentHeader, value: userAgent)
    headers.add(name: kGoogleAppIDHeader, value: googleAppID)
    return headers
}

@objc public enum FDisconnectReason: Int {
    case DISCONNECT_REASON_SERVER_RESET = 0
    case DISCONNECT_REASON_OTHER = 1

    var description: String {
        switch self {
        case .DISCONNECT_REASON_OTHER:
            return "other"
        case .DISCONNECT_REASON_SERVER_RESET:
            return "server_reset"
        }
    }
}

@objc public protocol FConnectionDelegate: NSObjectProtocol {
    @objc func onReady(_ fconnection: AnyObject,
                       atTime timestamp: NSNumber,
                       sessionID: String)

    @objc func onDataMessage(_ fconnection: AnyObject, withMessage message: NSDictionary)
    @objc func onDisconnect(_ fconnection: AnyObject, withReason reason: FDisconnectReason)
    @objc func onKill(_ fconnection: AnyObject, withReason: String)
}
