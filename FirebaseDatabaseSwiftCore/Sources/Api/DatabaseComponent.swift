//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/05/2022.
//

import Foundation

/// This protocol is used in the interop registration process to register an
/// instance provider for individual FIRApps.
@objc(FIRDatabaseProvider) public protocol DatabaseProvider: NSObjectProtocol {
    /// Gets a FirebaseDatabase instance for the specified URL, using the specified
    /// FirebaseApp.
    func databaseForApp(_ app: FIRAppThing, URL url: String) -> Database
}

/// A concrete implementation for FIRDatabaseProvider to create Database
/// instances.
@objc(FIRDatabaseComponent) public class DatabaseComponent: NSObject, DatabaseProvider {
    internal init(app: FIRAppThing) {
        self.app = app
    }
    
    public func databaseForApp(_ app: FIRAppThing, URL url: String) -> Database {
        guard let databaseUrl = URL(string: url) else {
            fatalError("The Database URL '\(url)' cannot be parsed. Specify a valid DatabaseURL within FIRApp or from your databaseForApp:URL: call.")
        }
        guard databaseUrl.path == "" || databaseUrl.path == "/" else {
            fatalError("Configured Database URL '\(databaseUrl)' is invalid. It should point to the root of a Firebase Database but it includes a path: \(databaseUrl.path)")
        }
        objc_sync_enter(instances)
        defer {
            objc_sync_exit(instances)
        }
        let parsedUrl = FUtilitiesSwift.parseUrl(databaseUrl.absoluteString)
        let urlIndex = "\(parsedUrl.repoInfo.host):\(parsedUrl.path)"
        if let database = instances[urlIndex] {
            return database
        }
        // XXX TODO: Inject auth and app check interop somehow
        let contextProvider = DatabaseConnectionContextProvider.contextProvider(auth: nil, appCheck: nil, dispatchQueue: DatabaseQuery.sharedQueue)

        // If this is the default app, don't set the session persistence key
        // so that we use our default ("default") instead of the FIRApp
        // default ("[DEFAULT]") so that we preserve the default location
        // used by the legacy Firebase SDK.
        var sessionIdentifier = "default"
        if !FIRAppThing.isDefaultAppConfigured || app != FIRAppThing.defaultApp {
            sessionIdentifier = app.name
        }
        let config = DatabaseConfig(sessionIdentifier: sessionIdentifier,
                                    googleAppID: app.options.googleAppID,
                                    contextProvider: contextProvider)
        let database = Database(app: app, repoInfo: parsedUrl.repoInfo, config: config)
        instances[urlIndex] = database
        return database
    }

    // MARK: - Instance management.
    func appWillBeDeleted(_ app: FIRAppThing) {
        objc_sync_enter(instances)
        defer {
            objc_sync_exit(instances)
        }
        // Clean up the deleted instance in an effort to remove any resources
        // still in use. Note: Any leftover instances of this exact database
        // will be invalid.
        for database in instances.values {
            FRepoManager.disposeRepos(database.config)
        }
        instances.removeAll()
    }

    private var app: FIRAppThing
    private var instances: [String: Database] = [:]

    /*
     #pragma mark - Lifecycle

     + (void)load {
         [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self
                                withName:@"fire-db"];
     }

     #pragma mark - FIRComponentRegistrant

     + (NSArray<FIRComponent *> *)componentsToRegister {
         FIRDependency *authDep =
             [FIRDependency dependencyWithProtocol:@protocol(FIRAuthInterop)
                                        isRequired:NO];
         FIRComponentCreationBlock creationBlock =
             ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
             *isCacheable = YES;
             return [[FIRDatabaseComponent alloc] initWithApp:container.app];
         };
         FIRComponent *databaseProvider =
             [FIRComponent componentWithProtocol:@protocol(FIRDatabaseProvider)
                             instantiationTiming:FIRInstantiationTimingLazy
                                    dependencies:@[ authDep ]
                                   creationBlock:creationBlock];
         return @[ databaseProvider ];
     }
     ---
     
     @interface FIRAppCheckTokenResult () <FIRDatabaseAppCheckTokenResultInterop>
     @end


     */
}
