//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 12/04/2022.
//

import Foundation


@objc(FIRDatabaseConnectionContext) public class DatabaseConnectionContext: NSObject {
    /// Auth token if available.
    @objc public var authToken: String?

    /// App check token if available.
    @objc public var appCheckToken: String?

    @objc public init(authToken: String?, appCheckToken: String?) {
        self.authToken = authToken
        self.appCheckToken = appCheckToken
    }
}

@objc(FIRDatabaseConnectionContextProvider) public protocol DatabaseConnectionContextProviderProtocol: NSObjectProtocol {
    func fetchContextForcingRefresh(_ forceRefresh: Bool, withCallback callback: @escaping (DatabaseConnectionContext?, Error?) -> Void)

    /// Adds a listener to the Auth token updates.
    /// @param listener A block that will be invoked each time the Auth token is
    /// updated.
    func listenForAuthTokenChanges(_ listener:  @escaping (String) -> Void)

    /// Adds a listener to the FAC token updates.
    /// @param listener A block that will be invoked each time the FAC token is
    /// updated.
    func listenForAppCheckTokenChanges(_ listener: @escaping (String) -> Void)
}

extension Notification.Name {
    public static let FIRAuthStateDidChangeInternalNotification = Notification.Name("FIRAuthStateDidChangeInternalNotification")
}

let FIRAuthStateDidChangeInternalNotificationTokenKey = "FIRAuthStateDidChangeInternalNotificationTokenKey"

private class FAuthStateListenerWrapper {
    private let listener: (String) -> Void
    private weak var auth: DatabaseAuthInterop?
    private let queue: DispatchQueue

    init(listener: @escaping (String) -> Void, auth: DatabaseAuthInterop, queue: DispatchQueue) {
        self.listener = listener
        self.auth = auth
        self.queue = queue
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(authStateDidChangeNotification),
                         name: .FIRAuthStateDidChangeInternalNotification,
                         object: nil)
    }
    @objc func authStateDidChangeNotification(_ notification: Notification) {
        let userInfo = notification.userInfo
        guard (notification.object as? AnyObject) === self.auth else { return }
        guard let token = userInfo?[FIRAuthStateDidChangeInternalNotificationTokenKey] as? String else { return }
        queue.async {
            self.listener(token)
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

@objc(FIRDatabaseAuthInterop) public protocol DatabaseAuthInterop: NSObjectProtocol {
    func getTokenForcingRefresh(_ forceRefresh: Bool, withCallback callback: (String?, Error?) -> Void)
}

@objc(FIRDatabaseAppCheckTokenResultInterop) public protocol DatabaseAppCheckTokenResultInterop: NSObjectProtocol {
    var token: String? { get }
    var error: Error? { get }
}

@objc(FIRDatabaseAppCheckInterop) public protocol DatabaseAppCheckInterop: NSObjectProtocol {
    func getTokenForcingRefresh(_ forceRefresh: Bool, completion: @escaping (DatabaseAppCheckTokenResultInterop) -> Void)
    var notificationTokenKey: String { get }
    var tokenDidChangeNotificationName: Notification.Name { get }
}

// TODO: Make FIRAppCheckInterop conform to FIRDatabaseAppCheckInterop
// TODO: Make FIRAppCheckTokenResultInterop conform to FIRDatabaseAppCheckTokenResultInterop
// TODO: Make FIRAuthInterop conform to FIRDatabaseAuthInterop

@objc(FIRDatabaseConnectionContextProvider) public class DatabaseConnectionContextProvider: NSObject, DatabaseConnectionContextProviderProtocol {

    var appCheck: DatabaseAppCheckInterop? // FIRAppCheckInterop
    var auth: DatabaseAuthInterop? // FIRAuthInterop

    /// Strong references to the auth listeners as they are only weak in
    /// FIRFirebaseApp.
    private var authListeners: [FAuthStateListenerWrapper] = []

    /// Observer objects returned by
    /// `-[NSNotificationCenter addObserverForName:object:queue:usingBlock:]`
    /// method. Required to cleanup the observers on dealloc.
    var appCheckNotificationObservers: [Any] = []

    /// An NSOperationQueue to call listeners on.
    var listenerQueue: OperationQueue

    private let dispatchQueue: DispatchQueue

    private init(auth: DatabaseAuthInterop?,
         appCheck: DatabaseAppCheckInterop?,
                 dispatchQueue: DispatchQueue) {
        self.appCheck = appCheck
        self.auth = auth
        self.dispatchQueue = dispatchQueue
        self.listenerQueue = OperationQueue()
        self.listenerQueue.underlyingQueue = dispatchQueue
    }

    deinit {
        // TODO: Will this work on Linux?
        // NOTE: Maybe it doesn't need to. Auth will be likely be bridged
        // in some other way
        // Otherwise we need some other synchronization method
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        for observer in self.appCheckNotificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func fetchContextForcingRefresh(_ forceRefresh: Bool, withCallback callback: @escaping (DatabaseConnectionContext?, Error?) -> Void) {
        guard self.auth != nil || self.appCheck != nil else {
            // Nothing to fetch. Finish straight away.
            // XXX TODO: HACK TO MAKE TESTING WORK
            callback(DatabaseConnectionContext(authToken: nil, appCheckToken: nil), nil)
//            callback(nil, nil)
            return
        }
        // Use dispatch group to call the callback when both Auth and FAC operations
        // finished.
        let dispatchGroup = DispatchGroup()
        var authToken: String? = nil
        var appCheckToken: String? = nil
        var authError: Error? = nil
        if let auth = auth {
            dispatchGroup.enter()
            auth.getTokenForcingRefresh(forceRefresh) { token, error in
                authToken = token
                authError = error
                dispatchGroup.leave()
            }
        }
        if let appCheck = appCheck {
            dispatchGroup.enter()
            appCheck.getTokenForcingRefresh(forceRefresh) { tokenResult in
                appCheckToken = tokenResult.token
                if let error = tokenResult.error {
                    FFLog("I-RDB096001", "Failed to fetch App Check token: \(error)")
                }
                dispatchGroup.leave()
            }
        }
        dispatchGroup.notify(queue: dispatchQueue, execute: {
            let context = DatabaseConnectionContext(authToken: authToken, appCheckToken: appCheckToken)
            // Pass only a possible Auth error. App Check errors should not change the
            // database SDK behaviour at this point as the App Check enforcement is
            // controlled on the backend.
            callback(context, authError)
        })
    }

    public func listenForAuthTokenChanges(_ listener: @escaping (String) -> Void) {
        guard let auth = auth else {
            return
        }

        let wrapper = FAuthStateListenerWrapper(listener: listener, auth: auth, queue: dispatchQueue)
        authListeners.append(wrapper)
    }

    public func listenForAppCheckTokenChanges(_ listener: @escaping (String) -> Void) {
        guard let appCheck = appCheck else {
            return
        }
        let appCheckTokenKey = appCheck.notificationTokenKey
        let observer = NotificationCenter.default
            .addObserver(forName: appCheck.tokenDidChangeNotificationName,
                         object: appCheck,
                         queue: listenerQueue) { notification in
                guard let appCheckToken = notification.userInfo?[appCheckTokenKey] as? String else {
                    return
                }
                listener(appCheckToken)
            }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        self.appCheckNotificationObservers.append(observer)
    }

    @objc public class func contextProvider(auth: DatabaseAuthInterop?, appCheck: DatabaseAppCheckInterop?, dispatchQueue: DispatchQueue) -> DatabaseConnectionContextProviderProtocol {
        DatabaseConnectionContextProvider(auth: auth, appCheck: appCheck, dispatchQueue: dispatchQueue)
    }
}
