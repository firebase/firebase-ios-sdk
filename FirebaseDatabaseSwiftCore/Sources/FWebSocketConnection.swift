//
//  FWebSocketConnection.swift
//  FWebSocketConnection
//
//  Created by Morten Bek Ditlevsen on 04/09/2021.
//

import Foundation
import NIOHTTP1

@objc public protocol FWebSocketDelegate: NSObjectProtocol {
    @objc func onMessage(_ fwebSocket: AnyObject, withMessage message: NSDictionary)
    @objc func onDisconnect(_ fwebSocket: AnyObject, wasEverConnected: Bool)
}

private let kAppCheckTokenHeader = "X-Firebase-AppCheck"
private let kUserAgentHeader = "User-Agent"
private let kGoogleAppIDHeader = "X-Firebase-GMPID"
private let kWebsocketProtocolVersion = "5"

@objc public class FWebSocketConnection: NSObject {
    var connectionId: NSNumber
    var totalFrames: Int
    var buffering: Bool
    var dispatchQueue: DispatchQueue
    var frame: String?
    var everConnected: Bool
    var isClosed: Bool
    var keepAlive: Timer?
    var client: WebSocketClient!

    @objc public weak var delegate: FWebSocketDelegate?
    @objc public func open() {
        print("OPEN")
        print("I-RDB083002", "(wsc:\(self.connectionId) FWebSocketConnection open.)")
        assert(delegate != nil)
        everConnected = false
        try! client.open()
    }
    @objc public func close() {
        print("CLOSE")
        client.close()
    }
    @objc public func start() {
        print("START")

    }
    @objc public func send(_ dictionary: NSDictionary) {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: []) else {
            return
        }
        client.send(data: data)
    }

    @objc public init(with connectionURL: String,
                      andQueue queue: DispatchQueue,
                      googleAppID: String,
                      appCheckToken: String,
                      userAgent: String) {
        self.everConnected = false
        self.isClosed = false
        self.connectionId =  NSNumber(value: 404)//[FUtilities LUIDGenerator];
        self.totalFrames = 0
        self.dispatchQueue = queue
        self.buffering = false
        self.frame = nil

        print("I-RDB083001", "(wsc: \(connectionId)) Connecting to:\(connectionURL) as \(userAgent))")

        let url = URL(string: connectionURL)!

        let headers = createHeaders(with: connectionURL,
                                    userAgent: userAgent,
                                    googleAppID: googleAppID,
                                    appCheckToken: appCheckToken)

        super.init()

        self.client = WebSocketClient(url: url,
                                      headers: headers,
                                      onMessage: { [weak self] message in
            guard let self = self else { return }
            self.delegate?.onMessage(self, withMessage: message as NSDictionary)
        }, onClose: { [weak self] in
            guard let self = self else { return }
            self.delegate?.onDisconnect(self, wasEverConnected: self.everConnected)
        })
    }
}

private  func createHeaders(with url: String,
                            userAgent: String,
                            googleAppID: String,
                            appCheckToken: String) -> HTTPHeaders {

    var headers = HTTPHeaders()
    headers.add(name: kAppCheckTokenHeader, value: appCheckToken)
    headers.add(name: kUserAgentHeader, value: userAgent)
    headers.add(name: kGoogleAppIDHeader, value: googleAppID)
    return headers
}

@objc public enum FDisconnectReason: Int {
    case DISCONNECT_REASON_SERVER_RESET = 0
    case DISCONNECT_REASON_OTHER = 1
}

@objc public protocol FConnectionDelegate: NSObjectProtocol {
    @objc func onReady(_ fconnection: AnyObject,
                       atTime timestamp: NSNumber,
                       sessionID: String)

    @objc func onDataMessage(_ fconnection: AnyObject, withMessage message: NSDictionary)
    @objc func onDisconnect(_ fconnection: AnyObject, withReason reason: FDisconnectReason)
    @objc func onKill(_ fconnection: AnyObject, withReason: String)
}
