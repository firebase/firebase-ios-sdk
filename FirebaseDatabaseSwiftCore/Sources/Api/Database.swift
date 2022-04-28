//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 13/04/2022.
//

import Foundation

@objc public class FIRAppThing: NSObject {
    struct Options {
        var databaseURL: String?
        var projectID: String?
    }
    var options: Options
    init(options: Options) {
        self.options = options
    }
    static var isDefaultAppConfigured: Bool { defaultApp != nil }
    static var defaultApp: FIRAppThing?
}

/**
 * The entry point for accessing a Firebase Database.  You can get an instance
 * by calling [FIRDatabase database]. To access a location in the database and
 * read or write data, use [FIRDatabase reference].
 */
@objc(FIRDatabase) public class Database: NSObject {
    private var repo: FRepo?
    private var repoInfo: FRepoInfo
    @objc public let config: DatabaseConfig
    
    /**
     * Gets the instance of FIRDatabase for the default FIRApp.
     *
     * @return A FIRDatabase instance.
     */
    @objc public class func database() -> Database {

        if !FIRAppThing.isDefaultAppConfigured {
            fatalError("The default FirebaseApp instance must be configured before the default Database instance can be initialized. One way to ensure this is to call `FirebaseApp.configure()` in the App Delegate's `application(_:didFinishLaunchingWithOptions:)` (or the `@main` struct's initializer in SwiftUI).")
        }
        return Database.database(app: FIRAppThing.defaultApp!)
    }

    /**
     * Gets a FirebaseDatabase instance for the specified URL.
     *
     * @param url The URL to the Firebase Database instance you want to access.
     * @return A FIRDatabase instance.
     */
    @objc(databaseWithURL:) public class func database(url: String) -> Database {
        guard let app = FIRAppThing.defaultApp else {
            fatalError("Failed to get default Firebase Database instance. Must call `[FIRApp configure]` (`FirebaseApp.configure()` in Swift) before using Firebase Database.")
        }
        return Database.database(app: app, url: url)
    }

    /**
     * Gets a FirebaseDatabase instance for the specified URL, using the specified
     * FirebaseApp.
     *
     * @param app The FIRApp to get a FIRDatabase for.
     * @param url The URL to the Firebase Database instance you want to access.
     * @return A FIRDatabase instance.
     */
    @objc(databaseForApp:URL:) public class func database(app: FIRAppThing, url: String) -> Database {
//        let provider =
//            FIR_COMPONENT(FIRDatabaseProvider, app.container);
//        return [provider databaseForApp:app URL:url];
//
        // XXX TODO:
        fatalError("Not implemented yet")
    }

    /**
     * Gets an instance of FIRDatabase for a specific FIRApp.
     *
     * @param app The FIRApp to get a FIRDatabase for.
     * @return A FIRDatabase instance.
     */
    @objc(databaseForApp:) public class func database(app: FIRAppThing) -> Database {
        let url: String
        if let dbURL = app.options.databaseURL {
            url = dbURL
        } else {
            guard let projectID = app.options.projectID else {
                fatalError("Can't determine Firebase Database URL. Be sure to include a Project ID when calling `FirebaseApp.configure()`.")
            }
            FFLog("I-RDB024002", "Using default host for project \(projectID)")
            url = "https://\(projectID)-default-rtdb.firebaseio.com"
        }
        return Database.database(app: app, url: url)
    }

    /** The FIRApp instance to which this FIRDatabase belongs. */
    @objc public weak var app: FIRAppThing?

    /**
     * Gets a FIRDatabaseReference for the root of your Firebase Database.
     */
    @objc public var reference: DatabaseReference {
        let repo = ensureRepo()
        return DatabaseReference(repo: repo, path: .empty)
    }

    /**
     * Gets a FIRDatabaseReference for the provided path.
     *
     * @param path Path to a location in your Firebase Database.
     * @return A FIRDatabaseReference pointing to the specified path.
     */
    @objc public func referenceWithPath(_ path: String) -> DatabaseReference {
        let repo = ensureRepo()
        FValidation.validateFrom("referenceWithPath", validRootPathString: path)
        let childPath = FPath(with: path)
        return DatabaseReference(repo: repo, path: childPath)
    }

    /**
     * Gets a FIRDatabaseReference for the provided URL.  The URL must be a URL to a
     * path within this Firebase Database.  To create a FIRDatabaseReference to a
     * different database, create a FIRApp with a FIROptions object configured with
     * the appropriate database URL.
     *
     * @param databaseUrl A URL to a path within your database.
     * @return A FIRDatabaseReference for the provided URL.
     */
    @objc public func referenceFromURL(_ databaseUrl: String) -> DatabaseReference {
        let repo = ensureRepo()
        let parsedUrl = FUtilitiesSwift.parseUrl(databaseUrl)
        FValidation.validateFrom("referenceFromURL:", validURL: parsedUrl)
        let isInvalidHost = !parsedUrl.repoInfo.isCustomHost && repoInfo.host != parsedUrl.repoInfo.host
        if isInvalidHost {
            fatalError("Invalid URL (\(databaseUrl)) passed to getReference(). URL was expected to match configured Database URL: \(repoInfo.host)")
        }
        return DatabaseReference(repo: repo, path: parsedUrl.path)
    }

    /**
     * The Firebase Database client automatically queues writes and sends them to
     * the server at the earliest opportunity, depending on network connectivity. In
     * some cases (e.g. offline usage) there may be a large number of writes waiting
     * to be sent. Calling this method will purge all outstanding writes so they are
     * abandoned.
     *
     * All writes will be purged, including transactions and onDisconnect writes.
     * The writes will be rolled back locally, perhaps triggering events for
     * affected event listeners, and the client will not (re-)send them to the
     * Firebase Database backend.
     */
    @objc public func purgeOutstandingWrites() {
        let repo = ensureRepo()

        DatabaseQuery.sharedQueue.async {
            repo.purgeOutstandingWrites()
        }
    }

    /**
     * Shuts down our connection to the Firebase Database backend until goOnline is
     * called.
     */
    @objc public func goOffline() {
        let repo = ensureRepo()

        DatabaseQuery.sharedQueue.async {
            repo.interrupt()
        }
    }

    /**
     * Resumes our connection to the Firebase Database backend after a previous
     * goOffline call.
     */
    @objc public func goOnline() {
        let repo = ensureRepo()

        DatabaseQuery.sharedQueue.async {
            repo.resume()
        }
    }

    /**
     * The Firebase Database client will cache synchronized data and keep track of
     * all writes you've initiated while your application is running. It seamlessly
     * handles intermittent network connections and re-sends write operations when
     * the network connection is restored.
     *
     * However by default your write operations and cached data are only stored
     * in-memory and will be lost when your app restarts.  By setting this value to
     * `YES`, the data will be persisted to on-device (disk) storage and will thus
     * be available again when the app is restarted (even when there is no network
     * connectivity at that time). Note that this property must be set before
     * creating your first Database reference and only needs to be called once per
     * application.
     *
     */
    @objc(persistenceEnabled) public var isPersistenceEnabled: Bool {
        set {
            assertUnfrozen("setPersistenceEnabled")
            config.persistenceEnabled = newValue
        }

        get {
            config.persistenceEnabled
        }
    }

    /**
     * By default the Firebase Database client will use up to 10MB of disk space to
     * cache data. If the cache grows beyond this size, the client will start
     * removing data that hasn't been recently used. If you find that your
     * application caches too little or too much data, call this method to change
     * the cache size. This property must be set before creating your first
     * FIRDatabaseReference and only needs to be called once per application.
     *
     * Note that the specified cache size is only an approximation and the size on
     * disk may temporarily exceed it at times. Cache sizes smaller than 1 MB or
     * greater than 100 MB are not supported.
     */
    @objc public var persistenceCacheSizeBytes: Int {
        set {
            assertUnfrozen("setPersistenceCacheSizeBytes")
            config.persistenceCacheSizeBytes = newValue
        }
        get {
            config.persistenceCacheSizeBytes
        }
    }

    /**
     * Sets the dispatch queue on which all events are raised. The default queue is
     * the main queue.
     *
     * Note that this must be set before creating your first Database reference.
     */
    @objc public var callbackQueue: DispatchQueue {
        set {
            assertUnfrozen("setCallbackQueue")
            config.callbackQueue = newValue
        }
        get {
            config.callbackQueue
        }
    }

    private func assertUnfrozen(_ methodName: String) {
        guard repo == nil else {
            fatalError("Calls to \(methodName) must be made before any other usage of FIRDatabase instance.")
        }
    }

    @discardableResult
    private func ensureRepo() -> FRepo {
        if let repo = repo {
            return repo
        }
        let r = FRepoManager.createRepo(repoInfo,
                                        config: self.config,
                                        database: self)
        self.repo = r
        return r
    }

    /**
     * Enables verbose diagnostic logging.
     *
     * @param enabled YES to enable logging, NO to disable.
     */
    @objc public class func setLoggingEnabled(_ enabled: Bool) {
        FUtilitiesSwift.setLoggingEnabled(enabled)
        FFLog("I-RDB024001", "BUILD Version: \(buildVersion)")
    }

    /** Retrieve the Firebase Database SDK version. */
    @objc public static var sdkVersion: String {
        // XXX TODO: Firebase version should be a define!
        "8.7.0"
    }

    /**
     * Configures the database to use an emulated backend instead of the default
     * remote backend.
     */
    @objc public func useEmulator(host: String, port: Int) {
        guard !host.isEmpty else {
            fatalError("Cannot connect to empty host.")
        }
        guard repo == nil else {
            fatalError("Cannot connect to emulator after database initialization. Call useEmulator(host:port:) before creating a database reference or trying to load data.")
        }
        let fullHost = "\(host):\(port)"
        let emulatorInfo = FRepoInfo(info: repoInfo, emulatedHost: fullHost)
        self.repoInfo = emulatorInfo
    }

    @objc public init(app: FIRAppThing?, repoInfo: FRepoInfo, config: DatabaseConfig) {
        self.app = app
        self.repoInfo = repoInfo
        self.config = config
    }

    @objc public class func createDatabaseForTests(_ repoInfo: FRepoInfo, config: DatabaseConfig) -> Database {
        let db = Database(app: nil, repoInfo: repoInfo, config: config)
        db.ensureRepo()
        return db
    }

    @objc public static var buildVersion: String {
        // TODO: Restore git hash when build moves back to git
        // XXX TODO: No DATE macro in Swift
        let date = "Apr 20 2022"
        return "\(sdkVersion)_\(date)"
    }
}
