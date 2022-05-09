//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 13/04/2022.
//

import Foundation

#if !os(watchOS)
import SystemConfiguration
#endif
#if os(iOS) || os(tvOS)
import UIKit
#endif

@objc public class FOutstandingQuery: NSObject {
    fileprivate init(query: FQuerySpec, tagId: Int?, syncTreeHash: FSyncTreeHash, onComplete: ((String) -> Void)?) {
        self.query = query
        self.tagId = tagId
        self.syncTreeHash = syncTreeHash
        self.onComplete = onComplete
    }

    let query: FQuerySpec
    let tagId: Int?
    let syncTreeHash: FSyncTreeHash
    let onComplete: ((String) -> Void)?
}

fileprivate class FOutstandingPut {
    fileprivate init(action: String, request: [String : Any], onComplete: ((String, String?) -> Void)?, sent: Bool) {
        self.action = action
        self.request = request
        self.onComplete = onComplete
        self.sent = sent
    }

    let action: String
    let request: [String : Any]
    let onComplete: ((String, String?) -> Void)?
    var sent: Bool
}

fileprivate class FOutstandingGet {
    fileprivate init(request: [String : Any], onComplete: @escaping (String, Any, String?) -> Void, sent: Bool) {
        self.request = request
        self.onComplete = onComplete
        self.sent = sent
    }

    let request: [String : Any]
    let onComplete: (String, Any, String?) -> Void
    var sent: Bool
}

enum ConnectionState {
    case disconnected
    case gettingToken
    case connecting
    case authenticating
    case connected
}

public protocol FPersistentConnectionDelegate: AnyObject {
    func onDataUpdate(_ fpconnection: FPersistentConnection,
                      forPath pathString: String,
                      message: Any,
                      isMerge: Bool,
                      tagId: Int?)

    func onRangeMerge(_ ranges: [FRangeMerge],
                      forPath pathString: String,
                      tagId: Int?)

    func onConnect(_ fpconnection: FPersistentConnection)

    func onDisconnect(_ fpconnection: FPersistentConnection)

    func onServerInfoUpdate(_ fpconnection: FPersistentConnection, updates: [String: Any])
}

typealias OnDisconnectTuple = (pathString: String,
                               action: String,
                               data: Any,
                               onComplete: (String, String?) -> Void)

typealias PutToAckTuple = (block: ((String, String) -> Void),
                           status: String,
                           errorReason: String)

@objc public class FPersistentConnection: NSObject, FConnectionDelegate {
    var connectionState: ConnectionState
    var firstConnection: Bool
    var reconnectDelay: TimeInterval
    var lastConnectionAttemptTime: TimeInterval
    var lastConnectionEstablishedTime: TimeInterval

#if !os(watchOS)
    var reachability: SCNetworkReachability?
#endif

    var realtime: FConnection?
    private var listens: [FQuerySpec: FOutstandingQuery]
    private var outstandingPuts: [Int: FOutstandingPut]
    private var outstandingGets: [Int: FOutstandingGet]
    var onDisconnectQueue: [OnDisconnectTuple]
    let repoInfo: FRepoInfo
    let putCounter: FAtomicNumber
    let getCounter: FAtomicNumber
    let requestNumber: FAtomicNumber
    var requestCBHash: [Int: ([String: Any]?) -> Void]
    let config: DatabaseConfig
    var unackedListentsCount: Int
    var putsToAck: [PutToAckTuple]
    let dispatchQueue: DispatchQueue
    var lastSessionID: String?
    var interruptReasons: Set<String>
    let retryHelper: FIRRetryHelper
    let contextProvider: DatabaseConnectionContextProviderProtocol
    var authToken: String?
    var forceTokenRefreshes: Bool
    var currentFetchTokenAttempt: Int

    /*
     PUBLIC
     */
    weak var delegate: FPersistentConnectionDelegate?
    @objc public var pauseWrites: Bool

    @objc public init(repoInfo: FRepoInfo, dispatchQueue: DispatchQueue, config: DatabaseConfig) {
        self.lastConnectionEstablishedTime = 0
        self.lastConnectionAttemptTime = 0
        self.forceTokenRefreshes = false
        self.currentFetchTokenAttempt = 0
        self.pauseWrites = false
        self.config = config
        self.repoInfo = repoInfo
        self.dispatchQueue = dispatchQueue
        self.contextProvider = config.contextProvider
        assert(config.contextProvider != nil, "Expected auth token provider")
        self.interruptReasons = []
        self.listens = [:]
        self.outstandingGets = [:]
        self.outstandingPuts = [:]
        self.onDisconnectQueue = []
        self.putCounter = FAtomicNumber()
        self.getCounter = FAtomicNumber()
        self.requestNumber = FAtomicNumber()
        self.requestCBHash = [:]
        self.unackedListentsCount = 0
        self.putsToAck = []
        self.connectionState = .disconnected
        self.firstConnection = true
        self.reconnectDelay = kPersistentConnReconnectMinDelay
        self.retryHelper = FIRRetryHelper(dispatchQueue: dispatchQueue,
                                          minRetryDelayAfterFailure: kPersistentConnReconnectMinDelay,
                                          maxRetryDelay: kPersistentConnReconnectMaxDelay,
                                          retryExponent: kPersistentConnReconnectMultiplier,
                                          jitterFactor: 0.7)

        super.init()
        setupNotifications()
        // Make sure we don't actually connect until open is called
        interruptForReason(kFInterruptReasonWaitingForOpen)
        // nb: The reason establishConnection isn't called here like the JS version
        // is because callers need to set the delegate first. The ctor can be
        // modified to accept the delegate but that deviates from normal ios
        // conventions. After the delegate has been set, the caller is responsible
        // for calling establishConnection:
    }

    deinit {
#if !os(watchOS)
        if let reachability = reachability {
            // Unschedule the notifications
            SCNetworkReachabilitySetDispatchQueue(reachability, nil)
        }
#endif
    }

    // MARK: -
    // MARK: Public methods

    @objc public func open() {
        resumeForReason(kFInterruptReasonWaitingForOpen)
    }

    @objc public static var userAgent: String {
        var systemVersion: String = ""
        var deviceName: String = ""
        var hasUIDeviceClass = false

        // Targetted compilation is ONLY for testing. UIKit is weak-linked in actual
        // release build.
#if os(iOS) || os(tvOS)
        systemVersion = UIDevice.current.systemVersion
        deviceName = UIDevice.current.model
        hasUIDeviceClass = true
#endif
        if !hasUIDeviceClass {
            /// XXX TODO: Boring to convert
//            NSDictionary *systemVersionDictionary = [NSDictionary
//                                                     dictionaryWithContentsOfFile:
//                                                        @"/System/Library/CoreServices/SystemVersion.plist"];
//            systemVersion =
//            [systemVersionDictionary objectForKey:@"ProductVersion"];
//            deviceName = [systemVersionDictionary objectForKey:@"ProductName"];
        }
        var bundleIdentifier = Bundle.main.bundleIdentifier ?? "-"

        // Sanitize '/'s in deviceName and bundleIdentifier for stats
        deviceName = FStringUtilitiesSwift.sanitizedForUserAgent(deviceName)
        bundleIdentifier = FStringUtilities.sanitizedForUserAgent(bundleIdentifier)

        // Firebase/5/<semver>_<build date>_<git hash>/<os version>/{device model /
        // os (Mac OS X, iPhone, etc.}_<bundle id>
        let ua = "Firebase/\(kWebsocketProtocolVersion)/\(Database.buildVersion)/\(systemVersion)/\(deviceName)_\(bundleIdentifier)"
        return ua
    }

    @objc public var userAgent: String {
        FPersistentConnection.userAgent
    }

    // XXX TODO: the type described below doesn't seem right
    /**
     * Note that the listens dictionary has a type of Map[String (pathString),
     * Map[FQueryParams, FOutstandingQuery]]
     *
     * This means, for each path we care about, there are sets of queryParams that
     * correspond to an FOutstandingQuery object. There can be multiple sets at a
     * path since we overlap listens for a short time while adding or removing a
     * query from a location in the tree.
     */
    public func listen(_ query: FQuerySpec,
                             tagId: Int?,
                             hash: FSyncTreeHash,
                             onComplete: @escaping (String) -> Void) {
        FFLog("I-RDB034001", "Listen called for \(query)")
        assert(self.listens[query] == nil,
               "listen() called twice for the same query")
        assert(query.isDefault || !query.loadsAllData,
               "listen called for non-default but complete query")
        let outstanding = FOutstandingQuery(query: query, tagId: tagId, syncTreeHash: hash, onComplete: onComplete)
        listens[query] = outstanding
        if connected {
            sendListen(outstanding)
        }
    }

    @objc public func listen(_ query: FQuerySpec,
                             tagId: Int,
                             hash: FSyncTreeHash,
                             onComplete: @escaping (String) -> Void) {
        listen(query, tagId: tagId, hash: hash, onComplete: onComplete)
    }

    @objc public func putData(_ data: Any,
                              forPath pathString: String,
                              withHash hash: String?,
                              withCallback onComplete: @escaping (String, String?) -> Void) {
        putInternal(data,
                    forAction: kFWPRequestActionPut,
                    forPath: pathString,
                    withHash: hash,
                    withCallback: onComplete)
    }

    @objc public func mergeData(_ data: Any,
                              forPath pathString: String,
                              withCallback onComplete: @escaping (String, String?) -> Void) {
        putInternal(data,
                    forAction: kFWPRequestActionMerge,
                    forPath: pathString,
                    withHash: nil,
                    withCallback: onComplete)
    }

    @objc public func onDisconnectPutData(_ data: Any,
                                          forPath path: FPath,
                                          withCallback callback: @escaping (String, String?) -> Void) {
        if canSendWrites {
            sendOnDisconnectAction(kFWPRequestActionDisconnectPut,
                                   forPath: path.description,
                                   withData: data,
                                   andCallback: callback)
        } else {
            let tuple: OnDisconnectTuple = (
                pathString: path.description,
                action: kFWPRequestActionDisconnectPut,
                data: data,
                onComplete: callback
            )
            onDisconnectQueue.append(tuple)
        }
    }

    @objc public func onDisconnectMergeData(_ data: Any,
                                            forPath path: FPath,
                                            withCallback callback: @escaping (String, String?) -> Void) {

        if canSendWrites {
            sendOnDisconnectAction(kFWPRequestActionDisconnectMerge,
                                   forPath: path.description,
                                   withData: data,
                                   andCallback: callback)
        } else {
            let tuple: OnDisconnectTuple = (
                pathString: path.description,
                action: kFWPRequestActionDisconnectMerge,
                data: data,
                onComplete: callback
            )
            onDisconnectQueue.append(tuple)
        }
    }

    @objc public func onDisconnectCancelPath(_ path: FPath,
                                             withCallback callback: @escaping (String, String?) -> Void) {
        if canSendWrites {
            sendOnDisconnectAction(kFWPRequestActionDisconnectCancel,
                                   forPath: path.description,
                                   withData: NSNull(),
                                   andCallback: callback)
        } else {
            let tuple: OnDisconnectTuple = (
                pathString: path.description,
                action: kFWPRequestActionDisconnectCancel,
                data: NSNull(),
                onComplete: callback
            )
            onDisconnectQueue.append(tuple)
        }
    }

    @objc public func unlistenObjc(_ query: FQuerySpec,
                               tagId: Int) {
        unlisten(query, tagId: tagId)
    }

    func unlisten(_ query: FQuerySpec,
                               tagId: Int?) {
        let path = query.path
        FFLog("I-RDB034002", "Unlistening for \(query)")
        let outstanding = removeListen(query)
        if !outstanding.isEmpty && connected {
            sendUnlisten(path, queryParams: query.params, tagId: tagId)
        }
    }

    @objc public func refreshAuthToken(_ token: String?) {
        self.authToken = token
        if connected {
            if token != nil {
                sendAuthAndRestoreStateAfterComplete(false)
            } else {
                sendUnauth()
            }
        }
    }

    // MARK: -
    // MARK: Connection status

    private var connected: Bool {
        switch connectionState {
        case .authenticating, .connected:
            return true
        case .disconnected, .connecting, .gettingToken:
            return false
        }
    }

    private var canSendWrites: Bool {
        connectionState == .connected
    }

    private var canSendReads: Bool {
        connectionState == .connected
    }

    // MARK: -
    // MARK: FConnection delegate methods
    public func onReady(_ fconnection: AnyObject, atTime timestamp: NSNumber, sessionID: String) {
        FFLog("I-RDB034003", "On ready");
        lastConnectionEstablishedTime = Date().timeIntervalSince1970
        handleTimestamp(timestamp)

        if firstConnection {
            sendConnectStats()
            firstConnection = false
        }
        restoreAuth()
        lastSessionID = sessionID
        dispatchQueue.async {
            self.delegate?.onConnect(self)
        }
    }

    public func onDataMessage(_ fconnection: AnyObject, withMessage message: NSDictionary) {
        if let number = message[kFWPRequestNumber] as? NSNumber {
            // this is a response to a request we sent
            let rn = number.intValue
            if let callback = requestCBHash[rn] {
                requestCBHash.removeValue(forKey: rn)
                callback(message[kFWPResponseForRNData] as? [String: Any])
            }
        } else if let error = message[kFWPRequestError] as? String {
            // XXX TODO THROW ERROR HERE?
            fatalError("FirebaseDatabaseServerError: \(error)")
        } else if let action = message[kFWPAsyncServerAction] as? String,
            let body = message[kFWPAsyncServerPayloadBody] as? [String: Any] {
            // this is a server push of some sort
            onDataPush(action, andBody: body)
        }
    }

    public func onDisconnect(_ fconnection: AnyObject, withReason reason: FDisconnectReason) {
        FFLog("I-RDB034004", "Got on disconnect due to \(reason.description)")
        connectionState = .disconnected
        // Drop the realtime connection
        realtime = nil
        cancelSentTransactions()
        requestCBHash.removeAll()
        unackedListentsCount = 0
        if shouldReconnect {
            let timeSinceLastConnectSucceeded = Date().timeIntervalSince1970 - lastConnectionEstablishedTime
            let lastConnectionWasSuccessful: Bool
            if lastConnectionEstablishedTime > 0 {
                lastConnectionWasSuccessful = timeSinceLastConnectSucceeded > kPersistentConnSuccessfulConnectionEstablishedDelay
            } else {
                lastConnectionWasSuccessful = false
            }
            if reason == .DISCONNECT_REASON_SERVER_RESET || lastConnectionWasSuccessful {
                retryHelper.signalSuccess()
            }
            tryScheduleReconnect()
        }
        lastConnectionEstablishedTime = 0
        delegate?.onDisconnect(self)
    }

    public func onKill(_ fconnection: AnyObject, withReason reason: String) {
        FFWarn("I-RDB034005",
               "Firebase Database connection was forcefully killed by the server. Will not attempt reconnect. Reason: \(reason)")
        interruptForReason(kFInterruptReasonServerKill)
    }

    // MARK: -
    // MARK: Connection handling methods

    @objc public func interruptForReason(_ reason: String) {
        FFLog("I-RDB034006", "Connection interrupted for: \(reason)")
        interruptReasons.insert(reason)
        if let realtime = realtime {
            // Will call onDisconnect and set the connection state to Disconnected
            realtime.close()
            self.realtime = nil
        } else {
            retryHelper.cancel()
            connectionState = .disconnected
        }
        // Reset timeouts
        retryHelper.signalSuccess()
    }

    @objc public func resumeForReason(_ reason: String) {
        FFLog("I-RDB034007", "Connection no longer interrupted for: \(reason)")
        interruptReasons.remove(reason)
        if shouldReconnect && connectionState == .disconnected {
            tryScheduleReconnect()
        }
    }

    var shouldReconnect: Bool {
        interruptReasons.isEmpty
    }

    @objc public func isInterruptedForReason(_ reason: String) -> Bool {
        interruptReasons.contains(reason)
    }

    // MARK: -
    // MARK: Private methods
    private func tryScheduleReconnect() {
        print("A")
        guard shouldReconnect else { return }
        print("B")
        assert(connectionState == .disconnected, "Not in disconnected state: \(connectionState)")
        let forceRefresh = forceTokenRefreshes
        forceTokenRefreshes = false
        FFLog("I-RDB034008", "Scheduling connection attempt")
        retryHelper.retry {
            FFLog("I-RDB034009", "Trying to fetch auth token")
            assert(self.connectionState == .disconnected, "Not in disconnected state: \(self.connectionState)")
            self.connectionState = .gettingToken
            self.currentFetchTokenAttempt += 1
            let thisFetchTokenAttempt = self.currentFetchTokenAttempt
            self.contextProvider.fetchContextForcingRefresh(forceRefresh) { context, error in
                print("C")
                if thisFetchTokenAttempt == self.currentFetchTokenAttempt {
                    if let error = error {
                        self.connectionState = .disconnected
                        FFLog("I-RDB034010",
                              "Error fetching token: \(error)")
                        self.tryScheduleReconnect()
                    } else {
                        print("D")
                        // XXX TODO: Model Result explicitly - or async call
                        let context = context!
                        // Someone could have interrupted us while
                        // fetching the token, marking the
                        // connection as Disconnected
                        if self.connectionState == .gettingToken {
                            FFLog("I-RDB034011",
                                  "Successfully fetched token, opening connection")
                            self.openNetworkConnection(context: context)
                        } else {
                            assert(self.connectionState == .disconnected, "Expected connection state disconnected, but got \(self.connectionState)")
                            FFLog("I-RDB034012", "Not opening connection after token refresh, because  connection was set to disconnected.")
                        }
                    }
                } else {
                    FFLog("I-RDB034013",
                          "Ignoring fetch token result, because this was not the latest attempt.")
                }
            }
        }
    }

    private func openNetworkConnection(context: DatabaseConnectionContext) {
        assert(connectionState == .gettingToken, "Trying to open network connection while in wrong state: \(connectionState)")
        // TODO: Save entire context?
        authToken = context.authToken
        connectionState = .connecting
        let connection = FConnection(with: repoInfo,
                                     andDispatchQueue: dispatchQueue,
                                     googleAppID: config.googleAppID,
                                     lastSessionID: lastSessionID,
                                     appCheckToken: context.appCheckToken,
                                     userAgent: userAgent)
        connection.delegate = self
        connection.open()
        realtime = connection
    }

#if !os(watchOS)
    static func reachabilityCallback(_ ref: SCNetworkReachability, _ flags: SCNetworkReachabilityFlags, _ info: UnsafeRawPointer) {

//        if flags.contains(.reachable) {
//            FFLog("I-RDB034014",
//                  "Network became reachable. Trigger a connection attempt")
//            let self = XXXDummyError
//            // Reset reconnect delay
//            self.retryHelper.signalSuccess()
//            if self.connectionState == .disconnected {
//                self.tryScheduleReconnect()
//            }
//
//        } else {
//            FFLog("I-RDB034015", "Network is not reachable")
//
//        }
    }
#endif

    private func enteringForeground() {
        dispatchQueue.async {
            // Reset reconnect delay
            self.retryHelper.signalSuccess()
            if self.connectionState == .disconnected {
                self.tryScheduleReconnect()
            }
        }
    }

    private func setupNotifications() {
#if os(watchOS)
        let center = NotificationCenter.default
        center.addObserver(forName: WKExtension.applicationWillEnterForegroundNotification,
                           object: nil,
                           queue: nil) { [weak self] _ in
            self?.enteringForeground()
        }
#elseif os(iOS) || os(tvOS)

        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.willEnterForegroundNotification,
                           object: nil, queue: nil) { [weak self] _ in
            self?.enteringForeground()
        }
        // XXX TODO REACHABILITY STUFF
        /*
         // An empty address is interpreted a generic internet access
         struct sockaddr_in zeroAddress;
         bzero(&zeroAddress, sizeof(zeroAddress));
         zeroAddress.sin_len = sizeof(zeroAddress);
         zeroAddress.sin_family = AF_INET;
         reachability = SCNetworkReachabilityCreateWithAddress(
             kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
         SCNetworkReachabilityContext ctx = {0, (__bridge void *)(self), NULL, NULL,
                                             NULL};
         if (SCNetworkReachabilitySetCallback(reachability, reachabilityCallback,
                                              &ctx)) {
             SCNetworkReachabilitySetDispatchQueue(reachability, self.dispatchQueue);
         } else {
             FFLog(@"I-RDB034016",
                   @"Failed to set up network reachability monitoring");
             CFRelease(reachability);
             reachability = NULL;
         }

         */
#endif
    }

    private func sendAuthAndRestoreStateAfterComplete(_ restoreStateAfterComplete: Bool) {
        assert(connected, "Must be connected to send auth")
        guard let authToken = authToken else {
            assertionFailure("Can't send auth if there is no credential")
            return
        }
        let requestData = [kFWPRequestCredential: authToken]
        sendAction(kFWPRequestActionAuth, body: requestData, sensitive: true, callback: { data in
            self.connectionState = .connected
            let status = data?[kFWPResponseForActionStatus] as? String
            var responseData = data?[kFWPResponseForActionData]
            if responseData == nil {
                responseData = "error"
            }
            let statusOk = status == kFWPResponseForActionStatusOk
            if statusOk {
                if restoreStateAfterComplete {
                    self.restoreState()
                }
            } else {
                self.authToken = nil
                self.forceTokenRefreshes = true
                if status == "expired_token" {
                    FFLog("I-RDB034017", "Authentication failed: \(status) (\(responseData))")
                } else {
                    FFWarn("I-RDB034018", "Authentication failed: \(status) (\(responseData))")
                }
                self.realtime?.close()
            }
        })
    }

    private func sendUnauth() {
        sendAction(kFWPRequestActionUnauth, body: [:], sensitive: false, callback: nil)
    }

    private func onAuthRevokedWithStatus(_ status: String, andReason reason: String) {
        // This might be for an earlier token than we just recently sent. But since
        // we need to close the connection anyways, we can set it to null here and
        // we will refresh the token later on reconnect
        if status == "expired_token" {
            FFLog("I-RDB034019", "Auth token revoked: \(status) (\(reason))")
        } else {
            FFWarn("I-RDB034020", "Auth token revoked: \(status) (\(reason))")
        }
        self.authToken = nil
        self.forceTokenRefreshes = true
        // Try reconnecting on auth revocation

        self.realtime?.close()
    }

    private func onListenRevoked(_ path: FPath) {
        let queries = removeAllListensAtPath(path)
        for query in queries {
            query.onComplete?("permission_denied")
        }
    }

    private func sendOnDisconnectAction(_ action: String,
                                        forPath pathString: String,
                                        withData data: Any,
                                        andCallback callback: @escaping (String, String) -> Void) {
        let request: [String: Any] = [
            kFWPRequestPath: pathString,
            kFWPRequestData: data
        ]
        FFLog("I-RDB034021", "onDisconnect \(action): \(request)")
        sendAction(action, body: request, sensitive: false, callback: { data in
            let status = data?[kFWPResponseForActionStatus] as? String
            let errorReason = data?[kFWPResponseForActionData] as? String
            if let status = status, let errorReason = errorReason {
                callback(status, errorReason)
            }
        })
    }

    private func sendPut(_ index: Int) {
        assert(canSendWrites, "sendPut called when not able to send writes")
        guard let put = outstandingPuts[index] else {
            return
        }
        let onComplete = put.onComplete

        // Do not async this block; copying the block insinde sendAction: doesn't
        // happen in time (or something) so coredumps
        put.sent = true
        sendAction(put.action,
                   body: put.request,
                   sensitive: false) { data in
            let currentPut = self.outstandingPuts[index]
            if currentPut === put {
                self.outstandingPuts.removeValue(forKey: index)
                if let onComplete = onComplete,
                   let status = data?[kFWPResponseForActionStatus] as? String,
                   let errorReason = data?[kFWPResponseForActionData] as? String {

                    if self.unackedListentsCount == 0 {
                        onComplete(status, errorReason)
                    } else {
                        let putToAck: PutToAckTuple = (block: onComplete, status: status, errorReason: errorReason)
                        self.putsToAck.append(putToAck)
                    }
                } else {
                    FFLog("I-RDB034022",
                          "Ignoring on complete for put \(index) because it was already removed")
                }
            }
        }
    }

    private func sendGet(_ index: Int) {
        assert(canSendReads, "sendGet called when not able to send reads")
        guard let get = outstandingGets[index] else {
            assertionFailure("sendGet found no outstanding get at index \(index)")
            return
        }
        guard !get.sent else { return }
        get.sent = true
        sendAction(kFWPRequestActionGet, body: get.request, sensitive: false) { data in
            let currentGet = self.outstandingGets[index]
            guard currentGet === get else {
                FFLog("I-RDB034045",
                      "Ignoring on complete for get \(index) because it was already removed")
                return
            }
            self.outstandingGets.removeValue(forKey: index)
            let status = data?[kFWPResponseForActionStatus] as? String
            var resultData = data?[kFWPResponseForActionData]
            if (resultData as? AnyObject) === NSNull() {
                resultData = nil
            }
            if let status = status {
                if status == kFWPResponseForActionStatusOk {
                    get.onComplete(status, resultData, nil)
                    return
                }
                get.onComplete(status, Optional<Any>.none, resultData as? String)
            }
        }
    }

    private func sendUnlisten(_ path: FPath,
                              queryParams: FQueryParams,
                              tagId: Int?) {
        FFLog("I-RDB034023", "Unlisten on \(path) for \(queryParams)")
        var request: [String: Any] = [path.description: kFWPRequestPath]
        if let tagId = tagId {
            request[kFWPRequestQueries] = queryParams.wireProtocolParams
            // XXX TODO: Ensure that this works or if it needs to be an NSNumber
            request[kFWPRequestTag] = tagId
        }
        sendAction(kFWPRequestActionTaggedUnlisten,
                   body: request,
                   sensitive: false, callback: { _ in })
    }

    private func putInternal(_ data: Any, forAction action: String, forPath pathString: String, withHash hash: String?, withCallback onComplete: @escaping (String, String?) -> Void) {
        var request: [String: Any] = [kFWPRequestPath: pathString,
                                      kFWPRequestData: data]
        if let hash = hash {
            request[kFWPRequestHash] = hash
        }
        let put = FOutstandingPut(action: action,
                                  request: request,
                                  onComplete: onComplete,
                                  sent: false)
        let index = putCounter.getAndIncrement().intValue
        outstandingPuts[index] = put
        if canSendWrites {
            FFLog("I-RDB034024", "Was connected, and added as index: \(index)")
            sendPut(index)
        } else {
            FFLog("I-RDB034025",
                  "Wasn't connected or writes paused, so added to outstanding puts only. Path: \(pathString)")

        }
    }

    @objc public func getDataAtPath(_ pathString: String,
                               withParams queryWireProtocolParams: [String: Any],
                               withCallback onComplete: @escaping (String, Any?, String?) -> Void) {
        var request: [String: Any] = [
            kFWPRequestPath: pathString,
            kFWPRequestQueries: queryWireProtocolParams
        ]
        let get = FOutstandingGet(request: request,
                                  onComplete: onComplete,
                                  sent: false)
        let index = getCounter.getAndIncrement().intValue
        outstandingGets[index] = get

        if !connected {
            dispatchQueue.asyncAfter(deadline: .now() + .seconds(kPersistentConnectionGetConnectTimeout)) {
                let currentGet = self.outstandingGets[index]
                if currentGet?.sent == true || currentGet == nil {
                    return
                }
                FFLog("I-RDB034045",
                      "get \(index) timed out waiting for a connection")
                currentGet?.sent = true
                currentGet?.onComplete(kFWPResponseForActionStatusFailed, Optional<Any>.none, kPersistentConnectionOffline)
                self.outstandingGets.removeValue(forKey: index)
            }
            return
        }
        if canSendReads {
            FFLog("I-RDB034024", "Sending get: \(index)")
            sendGet(index)
        }
    }

    private func sendListen(_ listenSpec: FOutstandingQuery) {
        let query = listenSpec.query
        FFLog("I-RDB034026", "Listen for \(query)")
        var request: [String: Any] = [kFWPRequestPath: query.path.description]
        // Only bother to send query if it's non-default
        if let tagId = listenSpec.tagId {
            request[kFWPRequestQueries] = query.params.wireProtocolParams
            // XXX TODO: NSNUmber?
            request[kFWPRequestTag] = tagId
        }
        request[kFWPRequestHash] = listenSpec.syncTreeHash.simpleHash
        if listenSpec.syncTreeHash.includeCompoundHash {
            let compoundHash = listenSpec.syncTreeHash.compoundHash
            var posts: [String] = []
            for path in compoundHash.posts {
                posts.append(path.wireFormat())
            }
            let hashDict: [String: Any] = [
                kFWPRequestCompoundHashHashes: compoundHash.hashes,
                kFWPRequestCompoundHashPaths: posts
            ]
            request[kFWPRequestCompoundHash] = hashDict
        }
        let onResponse: ([String: Any]?) -> Void = { response in
            FFLog("I-RDB034027", "Listen response \(response)")
            // warn in any case, even if the listener was removed
            self.warnOnListenWarningsForQuery(query, payload: response?[kFWPResponseForActionData])
            let currentListenSpec = self.listens[query]
            // only trigger actions if the listen hasn't been removed (and maybe
            // readded)
            if currentListenSpec === listenSpec {
                if let status = response?[kFWPRequestStatus] as? String {
                    if status != "ok" {
                        _ = self.removeListen(query)
                    }
                    listenSpec.onComplete?(status)
                }
            }
            self.unackedListentsCount -= 1
            assert(self.unackedListentsCount >= 0, "unackedListensCount decremented to be negative.")
            if self.unackedListentsCount == 0 {
                self.ackPuts()
            }
        }
        sendAction(kFWPRequestActionTaggedListen,
                   body: request,
                   sensitive: false,
                   callback: onResponse)
        unackedListentsCount += 1
    }

    private func warnOnListenWarningsForQuery(_ query: FQuerySpec, payload: Any?) {
        guard let payloadDict = payload as? [String: Any] else { return }
        guard let warnings = payloadDict[kFWPResponseDataWarnings] as? [String] else { return }
        let indexSpec = "\".indexOn\": \"\(query.params.index.queryDefinition)\""
        let indexPath = query.path.description
        FFWarn("I-RDB034028", """
Using an unspecified index. Your data will be \
downloaded and filtered on the client. \
Consider adding \(indexSpec) at \(indexPath) to your security rules for \
better performance
""")

    }

    private func getNextRequestNumber() -> Int {
        requestNumber.getAndIncrement().intValue
    }
    
    private func sendAction(_ action: String, body: [String: Any], sensitive: Bool, callback: (([String: Any]?) -> Void)?) {
        guard let realtime = realtime else { return }
        // Hold onto the onMessage callback for this request before firing it off
        let rn = getNextRequestNumber()
        let msg: [String: Any] = [kFWPRequestNumber: rn, kFWPRequestAction: action, kFWPRequestPayloadBody: body]
        do {
            try realtime.sendRequestSwift(msg, sensitive: sensitive)
        } catch {
            // XXX TODO, error handling
        }
        if let callback = callback {
            // Debug message without a callback; bump the rn, but don't hold onto
            // the cb
            requestCBHash[rn] = callback
        }
    }

    private func cancelSentTransactions() {
        var cancelledOutstandingPuts: [Int: FOutstandingPut] = [:]
        for (index, put) in outstandingPuts {
            if put.request[kFWPRequestHash] != nil && put.sent {
                // This is a sent transaction put.
                cancelledOutstandingPuts[index] = put
            }
        }
        for (index, outstandingPut) in cancelledOutstandingPuts {
            // `onCompleteBlock:` may invoke `rerunTransactionsForPath:` and
            // enqueue new writes. We defer calling it until we have finished
            // enumerating all existing writes.
            outstandingPut.onComplete?(kFTransactionDisconnect,
                                      "Client was disconnected while running a transaction")
            outstandingPuts.removeValue(forKey: index)
        }
    }

    private func onDataPush(_ action: String, andBody body: [String: Any]) {
        FFLog("I-RDB034029", "handleServerMessage: \(action), \(body)")
        switch action {
        case kFWPAsyncServerDataUpdate, kFWPAsyncServerDataMerge:
            let isMerge = action == kFWPAsyncServerDataMerge
            if let path = body[kFWPAsyncServerDataUpdateBodyPath] as? String,
               let payloadData = body[kFWPAsyncServerDataUpdateBodyData] {
                if let dict = payloadData as? [String: Any], dict.isEmpty, isMerge {
                    // ignore empty merge
                } else {
                    let tagId = body[kFWPAsyncServerDataUpdateBodyTag] as? Int
                    delegate?.onDataUpdate(self, forPath: path, message: payloadData, isMerge: isMerge, tagId: tagId)
                }
            } else {
                FFLog(
                    "I-RDB034030",
                    "Malformed data response from server missing path or data: \(body)")
            }
        case kFWPAsyncServerDataRangeMerge:
            guard let path = body[kFWPAsyncServerDataUpdateBodyPath] as? String else { return }
            let ranges = (body[kFWPAsyncServerDataUpdateBodyData] as? [[String: Any]]) ?? []
            let tag = body[kFWPAsyncServerDataUpdateBodyTag] as? Int
            var rangeMerges: [FRangeMerge] = []
            for range in ranges {
                let startString = range[kFWPAsyncServerDataUpdateStartPath] as? String
                let endString = range[kFWPAsyncServerDataUpdateEndPath] as? String
                let updateData = range[kFWPAsyncServerDataUpdateRangeMerge]
                let updates = FSnapshotUtilitiesSwift.nodeFrom(updateData)
                let start = startString.map(FPath.init(with:))
                let end = endString.map(FPath.init(with:))
                let merge = FRangeMerge(start: start, end: end, updates: updates)
                rangeMerges.append(merge)
            }
            delegate?.onRangeMerge(rangeMerges, forPath: path, tagId: tag)
        case kFWPAsyncServerAuthRevoked:
            let status = body[kFWPResponseForActionStatus] as? String
            let reason = body[kFWPResponseForActionData] as? String
            if let status = status, let reason = reason {
                self.onAuthRevokedWithStatus(status, andReason: reason)
            } else {
                // XXX TODO: log error
            }
        case kFWPASyncServerListenCancelled:
            if let pathString = body[kFWPAsyncServerDataUpdateBodyPath] as? String {
                onListenRevoked(FPath(with: pathString))
            } else {
                // XXX TODO: log error

            }
        case kFWPAsyncServerSecurityDebug:
            if let msg = body["msg"] as? String {
                let msgs = msg.components(separatedBy: "\n")
                for m in msgs {
                    FFWarn("I-RDB034031", m)
                }
            }
        default:
            // TODO: revoke listens, auth, security debug
            FFLog("I-RDB034032", "Unsupported action from server: \(action)")
        }

    }

    private func restoreAuth() {
        FFLog("I-RDB034033", "Calling restore state")
        assert(connectionState == .connecting,
                 "Wanted to restore auth, but was in wrong state: \(connectionState)")
        if authToken == nil {
            FFLog("I-RDB034034", "Not restoring auth because token is nil")
            connectionState = .connected
            restoreState()
        } else {
            FFLog("I-RDB034035", "Restoring auth")
            connectionState = .authenticating
            sendAuthAndRestoreStateAfterComplete(true)
        }
    }

    private func restoreState() {
        assert(connectionState == .connected,
                 "Should be connected if we're restoring state, but we are: \(connectionState)")
        for (query, outstandingListen) in listens {
            FFLog("I-RDB034036", "Restoring listen for \(query)")
            sendListen(outstandingListen)
        }
        let putKeys = outstandingPuts.keys.sorted()
        for (i, key) in putKeys.enumerated() {
            // if-branch will always be true, right?
            if outstandingPuts[key] != nil {
                // XXX TODO: Why log the index? Why not the key?
                FFLog("I-RDB034037", "Restoring put: \(i)")
                sendPut(key)
            } else {
                FFLog("I-RDB034038", "Restoring put: skipped nil: \(i)")
            }
        }

        let getKeys = outstandingGets.keys.sorted()
        for (i, key) in getKeys.enumerated() {
            if outstandingGets[key] != nil {
                FFLog("I-RDB034037", "Restoring get: \(i)")
                sendGet(key)
            } else {
                FFLog("I-RDB034038", "Restoring get: skipped nil: \(i)")
            }
        }

        for tuple in onDisconnectQueue {
            sendOnDisconnectAction(tuple.action,
                                   forPath: tuple.pathString,
                                   withData: tuple.data,
                                   andCallback: tuple.onComplete)
        }
        onDisconnectQueue.removeAll()
    }

    private func removeListen(_ query: FQuerySpec) -> [FOutstandingQuery] {
        assert(query.isDefault || !query.loadsAllData,
               "removeListen called for non-default but complete query"
        )
        if let outstanding = listens[query] {
            listens.removeValue(forKey: query)
            return [outstanding]
        } else {
            FFLog("I-RDB034039",
                  "Trying to remove listener for query \(query) but no listener exists")
            return []
        }
    }

    private func removeAllListensAtPath(_ path: FPath) -> [FOutstandingQuery] {
        FFLog("I-RDB034040", "Removing all listens at path \(path)")
        var removed: [FOutstandingQuery] = []
        var toRemove: [FQuerySpec] = []
        for (spec, outstanding) in listens {
            if spec.path == path {
                removed.append(outstanding)
                toRemove.append(spec)
            }
        }
        for key in toRemove {
            listens.removeValue(forKey: key)
        }

        return removed
    }

    @objc public func purgeOutstandingWrites() {
        // We might have unacked puts in our queue that we need to ack now before we
        // send out any cancels...
        ackPuts()
        // Cancel in order
        let keys = outstandingPuts.keys.sorted()
        for key in keys {
            guard let put = outstandingPuts[key] else { continue }
            put.onComplete?(kFErrorWriteCanceled, nil)
        }
        for onDisconnect in onDisconnectQueue {
            onDisconnect.onComplete(kFErrorWriteCanceled, nil)
        }
        outstandingPuts.removeAll()
        onDisconnectQueue.removeAll()
    }

    private func ackPuts() {
        for put in putsToAck {
            put.block(put.status, put.errorReason)
        }
        putsToAck.removeAll()
    }

    private func handleTimestamp(_ timestamp: NSNumber) {
        FFLog("I-RDB034041", "Handling timestamp: \(timestamp)")
        let timestampDeltaMs = timestamp.doubleValue - Date().timeIntervalSince1970 * 1000
        delegate?.onServerInfoUpdate(self, updates: [kDotInfoServerTimeOffset: NSNumber(value: timestampDeltaMs)])
    }

    private func sendStats(_ stats: [String: Any]) {
        guard !stats.isEmpty else {
            FFLog("I-RDB034043", "Not sending stats because stats are empty")
            return
        }
        let request: [String: Any] = [kFWPRequestCounters: stats]
        sendAction(kFWPRequestActionStats,
                   body: request,
                   sensitive: false) { data in
            let status = data?[kFWPResponseForActionStatus] as? String
            let errorReason = data?[kFWPResponseForActionData] as? String
            let statusOk = status == kFWPResponseForActionStatusOk
            if !statusOk {
                FFLog("I-RDB034042", "Failed to send stats: \(errorReason)")
            }
        }
    }

    private func sendConnectStats() {
        var stats: [String: Any] = [:]
#if os(iOS) || os(tvOS)
        if config.persistenceEnabled {
            stats["persistence.ios.enabled"] = true
        }
#elseif os(macOS)
        if config.persistenceEnabled {
            stats["persistence.osx.enabled"] = true
        }
#elseif os(watchOS)
        if config.persistenceEnabled {
            stats["persistence.watchos.enabled"] = true
        }
#endif
        let sdkVersion = Database.sdkVersion.replacingOccurrences(of: ".", with: "-")
        // XXX TODO: objc -> swift? :-)
        let sdkStatName = "sdk.objc.\(sdkVersion)"
        stats[sdkStatName] = 1
        FFLog("I-RDB034044", "Sending first connection stats")
        sendStats(stats)
    }
    /*
     */

    // Testing methods
    @objc public func dumpListens() -> [FQuerySpec: FOutstandingQuery] {
        listens
    }

    // MARK: - App Check Token update
    // TODO: Add tests!
    @objc public func refreshAppCheckToken(_ token: String) {
        if !connected {
            // A fresh FAC token will be sent as a part of initial handshake.
            return
        }
        if token.isEmpty {
            // No token to send.
            return
        }
        // Send updated FAC token to the open connection.
        sendAppCheckToken(token)
    }

    private func sendAppCheckToken(_ token: String) {
        let requestData: [String: Any] = [kFWPRequestAppCheckToken: token]
        sendAction(kFWPRequestActionAppCheck,
                   body: requestData,
                   sensitive: true) { data in
            let status = data?[kFWPResponseForActionStatus] as? String
            let responseData = data?[kFWPResponseForActionData] ?? "Response data was empty."
            let statusOk = status == kFWPResponseForActionStatusOk
            if !statusOk {
                self.authToken = nil
                self.forceTokenRefreshes = true
                if status == "invalid_token" {
                    FFLog("I-RDB034045", "App check failed: \(status) (\(responseData))")
                } else {
                    FFWarn("I-RDB034046", "App check failed: \(status) (\(responseData))")
                }
                self.realtime?.close()
            }
        }
    }
}
