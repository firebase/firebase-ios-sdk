import Foundation
import FirebaseCore
class FIRRemoteConfigComponent :NSObject, FIRRemoteConfigProvider, FIRRemoteConfigInterop {

    static var componentInstances = [String : FIRRemoteConfigComponent]()
    
    var app : FIRApp?
    var instances : NSMutableDictionary<NSString,FIRRemoteConfig> = [:]

    static func getComponent(app: FIRApp) -> FIRRemoteConfigComponent? {
        @synchronized(componentInstances) {
            if (componentInstances.isEmpty) {
              componentInstances = [String : FIRRemoteConfigComponent]()
            }
            if (componentInstances[app.name] == nil) {
                componentInstances[app.name] = FIRRemoteConfigComponent(app: app)
            }
            return componentInstances[app.name]
        }
        return nil
    }

    static func clearAllComponentInstances() {
        @synchronized(componentInstances) {
          componentInstances.removeAll()
        }
    }

    func remoteConfigForNamespace(firebaseNamespace: String) -> FIRRemoteConfig? {
        if firebaseNamespace.isEmpty {
            return nil
        }

        // Validate the required information is available.
        guard let options = self.app?.options else {
            fatalError("The 'options' property was not available for this configuration")
        }

        if options.googleAppID.isEmpty {
          fatalError("Firebase Remote Config is missing the required googleAppID property from the " +
                     "configured FirebaseApp and will not be able to function properly. Please " +
                     "fix this issue to ensure that Firebase is correctly configured.")
        }
        
        if options.GCMSenderID.isEmpty {
          fatalError("Firebase Remote Config is missing the required GCMSenderID property from the " +
                     "configured FirebaseApp and will not be able to function properly. Please " +
                     "fix this issue to ensure that Firebase is correctly configured.")
        }

        if options.projectID.isEmpty {
            fatalError("Firebase Remote Config is missing the required projectID property from the " +
                       "configured FirebaseApp and will not be able to function properly. Please " +
                       "fix this issue to ensure that Firebase is correctly configured.")
        }
        
        var instance : FIRRemoteConfig? = self.instances[firebaseNamespace]
        if (instance == nil) {
            let appName : String = self.app?.name ?? ""
            let dbManager : RCNConfigDBManager = RCNConfigDBManager.sharedInstance()
            let configContent = RCNConfigContent.sharedInstance()
            let googleAppID = options.googleAppID ?? ""

            instance = FIRRemoteConfig(appName: appName,
                                         FIROptions: options,
                                         namespace: FIRNamespace, DBManager: dbManager,
                                         configContent: configContent, analytics: nil)
            
            self.instances[firebaseNamespace] = instance;
        }

        return instance
    }

    init(app: FIRApp) {
        self.app = app;
        self.instances = [:]
    }

    static func load() {
        // Register as an internal library to be part of the initialization process. The name comes
        // from go/firebase-sdk-platform-info.
        FIRApp.registerInternalLibrary(self, withName: "fire-rc")
    }
    
    
    
    static func componentsToRegister() -> [FIRComponent] {
      let rcProvider = FIRComponent(protocol: FIRRemoteConfigProvider.self,
                                      instantiationTiming: .alwaysEager) {
        (container, isCacheable) -> AnyObject in
        // Cache the component so instances of Remote Config are cached.
        var isCacheable = true
        return FIRRemoteConfigComponent.getComponent(app: container.app) as Any
      }
        
      let rcInterop = FIRComponent(protocol: FIRRemoteConfigInterop.self,
                                      instantiationTiming: .alwaysEager) {
        (container, isCacheable) -> AnyObject in
        // Cache the component so instances of Remote Config are cached.
        var isCacheable = true
        return FIRRemoteConfigComponent.getComponent(app: container.app) as Any
      }
        return [rcProvider, rcInterop]
    }

    // MARK: - Remote Config Interop Protocol
    func registerRolloutsStateSubscriber(subscriber: FIRRolloutsStateSubscriber, for namespace: String) {
        let instance : FIRRemoteConfig? = self.remoteConfigForNamespace(firebaseNamespace: namespace)
      guard let instance = instance else {
        return
      }
        [instance addRemoteConfigInteropSubscriber:subscriber];
    }
    
}
