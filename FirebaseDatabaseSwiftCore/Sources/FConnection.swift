//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 14/09/2021.
//

import Foundation

@objc enum FConnectionState : Int {
    case connecting = 0
    case connected = 1
    case disconnected = 2
}

@objc public final class FConnection: NSObject, FWebSocketDelegate {
    @objc public weak var delegate: FConnectionDelegate?
    @objc var state: FConnectionState
    var conn: FWebSocketConnection?
    @objc let repoInfo: FRepoInfo

    @objc public init(
        with aRepoInfo: FRepoInfo,
        andDispatchQueue queue: DispatchQueue,
        googleAppID: String,
        lastSessionID: String?,
        appCheckToken: String?,
        userAgent: String
    ) {
        self.state = .connecting
        self.repoInfo = aRepoInfo
        let connectionURL = aRepoInfo.connectionURL(lastSessionID: lastSessionID)

        conn = FWebSocketConnection(with:
            connectionURL,
            andQueue: queue,
            googleAppID: googleAppID,
            appCheckToken: appCheckToken,
            userAgent: userAgent)

        super.init()

        conn?.delegate = self
    }

    // MARK: -
    // MARK: Public method implementation
    @objc public func open() {
        FFLog("I-RDB082001", "Calling open in FConnection")
        conn?.open()
    }

    @objc public func close(with reason: FDisconnectReason) {
        if state != .disconnected {
            FFLog("I-RDB082002", "Closing realtime connection.")
            state = .disconnected

            if let conn = conn {
                FFLog("I-RDB082003", "Calling close again.")
                conn.close()
                self.conn = nil
            }

            delegate?.onDisconnect(self, withReason: reason)
        }
    }

    @objc public func close() {
        close(with: .DISCONNECT_REASON_OTHER)
    }

    // XXX TODO: Verify that this works
    internal func sendRequestSwift(_ dataMsg: [String: Any?], sensitive: Bool) throws {
        // since this came from the persistent connection, wrap it in a data message
        // envelope
        let msg: [String: Any] = [
            kFWPRequestType: kFWPRequestTypeData,
            kFWPRequestDataPayload: dataMsg
        ]

        try sendData(msg, sensitive: sensitive)
    }


    @objc public func sendRequest(_ dataMsg: NSDictionary, sensitive: Bool) throws {
        // since this came from the persistent connection, wrap it in a data message
        // envelope
        let msg: [String: Any] = [
            kFWPRequestType: kFWPRequestTypeData,
            kFWPRequestDataPayload: dataMsg
        ]

        try sendData(msg, sensitive: sensitive)
    }

    func sendData(_ data: [String: Any], sensitive: Bool) throws {
        if state != .connected {
            /// TODO THROW
//            @throw [[NSException alloc]
//                initWithName:@"InvalidConnectionState"
//                      reason:@"Tried to send data on an unconnected FConnection"
//                    userInfo:nil];
        } else {
            if (sensitive) {
                FFLog("I-RDB082004", "Sending data (contents hidden)")
            } else {
                FFLog("I-RDB082005", "Sending: \(data)")
            }
            self.conn?.send(data)
        }

    }

    // MARK: -
    // MARK: Helpers

    // MARK: -
    // MARK: FWebSocketConnectinDelegate implementation

    // Corresponds to onConnectionLost in JS

    public func onDisconnect(
        _ fwebSocket: AnyObject,
        wasEverConnected everConnected: Bool
    ) {

        self.conn = nil;
        if (!everConnected && state == .connecting) {
            FFLog("I-RDB082006", "Realtime connection failed.")

            // Since we failed to connect at all, clear any cached entry for this
            // namespace in case the machine went away
            repoInfo.clearInternalHostCache()
        } else if (state == .connected) {
            FFLog("I-RDB082007", "Realtime connection lost.")
        }
        self.close()
    }

    // Corresponds to onMessageReceived in JS
    public func onMessage(
        _ fwebSocket: AnyObject,
        withMessage message: [String: Any]
    ) {
        if let rawMessageType = message[kFWPAsyncServerEnvelopeType] as? String {
            if rawMessageType == kFWPAsyncServerDataMessage, let data = message[kFWPAsyncServerEnvelopeData] as? NSDictionary {
                onDataMessage(data)
            } else if rawMessageType == kFWPAsyncServerControlMessage, let data = message[kFWPAsyncServerEnvelopeData] as? [String: Any] {
                onControl(data)
            } else {
                FFLog("I-RDB082008", "Unrecognized server packet type: \(rawMessageType)")
            }
        } else {
            FFLog("I-RDB082009", "Unrecognized raw server packet received: \(message)")
        }
    }

    public func onDataMessage(_ message: NSDictionary?) {
        guard let message = message else { return }
        // we don't do anything with data messages, just kick them up a level
        FFLog("I-RDB082010", "Got data message: \(message)")
        self.delegate?.onDataMessage(self, withMessage: message)
    }

    func onControl(_ message: [String: Any]) {
        FFLog("I-RDB082011", "Got control message: \(message)")
        let type = message[kFWPAsyncServerControlMessageType] as? String
        if type == kFWPAsyncServerControlMessageShutdown, let reason =
            message[kFWPAsyncServerControlMessageData] as? String
        {
            self.onConnectionShutdownWithReason(reason: reason)
        } else if type == kFWPAsyncServerControlMessageReset,
            let host =
                    message[kFWPAsyncServerControlMessageData] as? String {
            self.onReset(host: host)
        } else if type == kFWPAsyncServerHello, let handshakeData =
                    message[kFWPAsyncServerControlMessageData] as? [String: Any] {
            self.onHandshake(handshake: handshakeData)
        } else {
            FFLog("I-RDB082012",
                  "Unknown control message returned from server: \(message)")
        }
    }

    func onConnectionShutdownWithReason(reason: String) {
        FFLog("I-RDB082013",
              "Connection shutdown command received. Shutting down...")

        self.delegate?.onKill(self, withReason: reason)
        self.close()
    }

    func onReset(host: String) {
        FFLog(
            "I-RDB082015",
            "Got a reset; killing connection to: \(repoInfo.internalHost); Updating internalHost to: \(host)")
        self.repoInfo.internalHost = host

        // Explicitly close the connection with SERVER_RESET so calling code knows
        // to reconnect immediately.
        self.close(with: .DISCONNECT_REASON_SERVER_RESET)
    }

    func onHandshake(handshake: [String: Any]) {
        guard let conn = self.conn,
              let timestamp = handshake[kFWPAsyncServerHelloTimestamp] as? NSNumber,
              let host = handshake[kFWPAsyncServerHelloConnectedHost] as? String,
              let sessionID = handshake[kFWPAsyncServerHelloSession] as? String else {
                  // XXX TODO, log error?
                  return
              }

        self.repoInfo.internalHost = host

        if state == .connecting {
            self.conn?.start()
            self.onConnection(conn: conn, readyAtTime: timestamp, sessionID: sessionID)
        }
    }

    func onConnection(conn: FWebSocketConnection, readyAtTime time: NSNumber, sessionID: String) {
        FFLog("I-RDB082014", "Realtime connection established")
        state = .connected
        self.delegate?.onReady(conn, atTime: time, sessionID: sessionID)
    }

}
