import Foundation
import FirebaseABTesting
import FirebaseCore

class FIRRemoteConfigSettings {
    var minimumFetchInterval: TimeInterval = RCNConstants.RCNDefaultMinimumFetchInterval
    var fetchTimeout: TimeInterval = RCNConstants.RCNHTTPDefaultConnectionTimeout

    init() {}
}

class FIRRemoteConfig {
    static var RCInstances: [String: [String: FIRRemoteConfig]] = [:]
    static var sharedRemoteConfigQueue: DispatchQueue = DispatchQueue(label: RCNConstants.RCNRemoteConfigQueueLabel)
    
    var configContent: RCNConfigContent?
    var DBManager: RCNConfigDBManager?
    var settings: FIRRemoteConfigSettings?
    var configFetch: RCNConfigFetch?
    var configExperiment: RCNConfigExperiment?
    var configRealtime: RCNConfigRealtime?
    var queue: DispatchQueue?
    var appName: String?
    var listeners: [((String, [String: Any])) -> Void]?

    private var _FIRNamespace: String = ""
    private var _options: FIROptions?

    static func remoteConfig(app: FIRApp) -> FIRRemoteConfig {
        return remoteConfig(FIRNamespace: RCNConstants.FIRNamespaceGoogleMobilePlatform, app: app)
    }

    static func remoteConfig(FIRNamespace: String) -> FIRRemoteConfig {
        guard let app = FIRApp.defaultApp else {
            fatalError("The default `FirebaseApp` instance must be configured before the " +
                      "default Remote Config instance can be initialized. One way to ensure this " +
                      "is to call `FirebaseApp.configure()` in the App Delegate's " +
                      "`application(_:didFinishLaunchingWithOptions:)` or the `@main` struct's " +
                      "initializer in SwiftUI.")
        }
        return remoteConfig(FIRNamespace: FIRNamespace, app: app)
    }

    static func remoteConfig(FIRNamespace: String, app: FIRApp) -> FIRRemoteConfig {
      // Use the provider to generate and return instances of FIRRemoteConfig for this specific app and
      // namespace. This will ensure the app is configured before Remote Config can return an instance.
      guard let provider = FIRComponentContainer.shared.getComponent(FIRRemoteConfigProvider.self) else {
        fatalError("Component not found")
      }

        return provider.remoteConfigForNamespace(firebaseNamespace: FIRNamespace)
    }
    
    static func remoteConfig() -> FIRRemoteConfig {
        guard let app = FIRApp.defaultApp else {
            fatalError("The default `FirebaseApp` instance must be configured before the " +
                       "default Remote Config instance can be initialized. One way to ensure this " +
                       "is to call `FirebaseApp.configure()` in the App Delegate's " +
                       "`application(_:didFinishLaunchingWithOptions:)` or the `@main` struct's " +
                       "initializer in SwiftUI.")
        }
        return remoteConfig(FIRNamespace: RCNConstants.FIRNamespaceGoogleMobilePlatform, app: app)
    }
    
    static func sharedRemoteConfigSerialQueue() -> DispatchQueue {
        return FIRRemoteConfig.sharedRemoteConfigSerialQueue()
    }

    init(appName: String, FIRNamespace: String, options: FIROptions,
         DBManager: RCNConfigDBManager, configContent: RCNConfigContent,
         analytics: FIRAnalyticsInterop?) {
        
    }

    func callListeners(key: String, config: [String: Any]) {
        for listener in self.listeners ?? [] {
            listener(key, config)
        }
    }

    func setCustomSignals(customSignals: [String: NSObject], completionHandler: ((Error?) -> Void)?) {
      // Validate value type, and key and value length
      for (key, value) in customSignals {
        if let value = value as? NSNull {
          continue
        }
        if let value = value as? NSString {
          if value.count > FIRRemoteConfigCustomSignalsMaxStringValueLength {
            let error = NSError(domain: FIRRemoteConfigCustomSignalsErrorDomain, code: FIRRemoteConfigCustomSignalsErrorLimitExceeded, userInfo: nil)
            completionHandler?(error)
            return
          }
        }

        if key.count > FIRRemoteConfigCustomSignalsMaxKeyLength {
          let error = NSError(domain: FIRRemoteConfigCustomSignalsErrorDomain, code: FIRRemoteConfigCustomSignalsErrorLimitExceeded, userInfo: nil)
          completionHandler?(error)
          return
        }

        // Check the size limit.
        if customSignals.count > FIRRemoteConfigCustomSignalsMaxCount {
          let error = NSError(domain: FIRRemoteConfigCustomSignalsErrorDomain, code: FIRRemoteConfigCustomSignalsErrorLimitExceeded, userInfo: nil)
          completionHandler?(error)
          return
        }
      }
      
      // Merge new signals with existing ones, overwriting existing keys.
      // Also, remove entries where the new value is null.
      var newCustomSignals = [String: String]()
      for (key, value) in customSignals {
        if (value is NSNull) {
          [newCustomSignals removeObjectForKey:key];
        } else {
          NSString *stringValue = nil;
          if ([value isKindOfClass:[NSNumber class]]) {
            stringValue = [(NSNumber *)value stringValue];
          } else if ([value isKindOfClass:[NSString class]]) {
            stringValue = (NSString *)value;
          }
          [newCustomSignals setObject:stringValue forKey:key];
        }
      }
      
      // Check if there are changes
      if (newCustomSignals != self.settings?.customSignals) {
        self->_settings?.customSignals = newCustomSignals;
      }

      // Log the keys of the updated custom signals.
      FIRLogDebug(RCNRemoteConfigQueueLabel, @"I-RCN000078", "Keys of updated custom signals: %@",
                  [newCustomSignals allKeys].joined(separator: ", "));

      if (completionHandler != nil) {
          completionHandler(nil);
        }
    }

    func fetchWithExpirationDuration(expirationDuration: TimeInterval,
                                     completionHandler: FIRRemoteConfigFetchCompletion?) {
      self->_configFetch?.fetchConfigWithExpirationDuration(expirationDuration: expirationDuration,
                                                        completionHandler: completionHandler)
    }

    func fetchWithCompletionHandler(completionHandler: FIRRemoteConfigFetchCompletion?) {
      fetchWithExpirationDuration(expirationDuration: self.settings?.minimumFetchInterval ?? 0,
                                  completionHandler: completionHandler)
    }

    func fetchAndActivateWithCompletionHandler(completionHandler:
                                                 FIRRemoteConfigFetchAndActivateCompletion?) {
      let fetchCompletion =
          {(_ fetchStatus: FIRRemoteConfigFetchStatus, fetchError: NSError?) in
            if fetchStatus == .success && fetchError == nil {
              
              [self activateWithCompletion:^(Bool changed, NSError * _Nullable activateError) {
                if (completionHandler) {
                  let status =
                      activateError ? FIRRemoteConfigFetchAndActivateStatus.successUsingPreFetchedData
                                : FIRRemoteConfigFetchAndActivateStatus.successFetchedFromRemote
                  dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(status, nil);
                  });
                }
              }];
            } else if (completionHandler != nil) {
              FIRRemoteConfigFetchAndActivateStatus status =
                  fetchStatus == FIRRemoteConfigFetchStatus.success ?
                      FIRRemoteConfigFetchAndActivateStatus.successUsingPreFetchedData :
                      FIRRemoteConfigFetchAndActivateStatus.error;
              dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(status, fetchError);
              });
            }
          };
      [self fetchWithCompletionHandler:fetchCompletion];
    }

    func activateWithCompletion(completion: ((Bool, NSError?) -> Void)?) {
      __weak FIRRemoteConfig *weakSelf = self;
      let applyBlock: () -> Void = {
        __strong FIRRemoteConfig *strongSelf = weakSelf;
        if strongSelf == nil {
          let error = NSError(domain: FIRRemoteConfigErrorDomain, code: FIRRemoteConfigErrorInternalError, userInfo: nil)
          if let completion {
            dispatch_async(DispatchQueue.global(qos: .default), ^{
              completion(false, error);
            });
          }
          FIRLogError(RCNRemoteConfigQueueLabel, @"I-RCN000068", "Internal error activating config.");
          return;
        }
        // Check if the last fetched config has already been activated. Fetches with no data change
        // are ignored.
        if (strongSelf->_settings.lastETagUpdateTime == 0 ||
            strongSelf->_settings.lastETagUpdateTime <= strongSelf->_settings.lastApplyTimeInterval) {
          FIRLogDebug(RCNRemoteConfigQueueLabel, @"I-RCN000069",
                      @"Most recently fetched config is already activated.");
          if (completion) {
            dispatch_async(DispatchQueue.global(qos: .default), ^{
              completion(false, nil);
            });
          }
          return;
        }

        strongSelf->_configContent?.copyFromDictionary(
            from: strongSelf->_configContent.fetchedConfig ?? [:], toSource: .active,
            forNamespace: strongSelf->_FIRNamespace);
        strongSelf->_settings?.lastApplyTimeInterval =
            [[NSDate date] timeIntervalSince1970];
        // New config has been activated at this point
        FIRLogDebug(RCNRemoteConfigQueueLabel, @"I-RCN000069", @"Config activated.");
        // Update last active template version number in setting and userDefaults.
        [strongSelf->_settings updateLastActiveTemplateVersion];
        // Update activeRolloutMetadata
        [strongSelf->_configContent activateRolloutMetadata:^(BOOL success) {
          if (success) {
            [self notifyRolloutsStateChange:strongSelf->_configContent.activeRolloutMetadata
                              versionNumber:strongSelf->_settings.lastActiveTemplateVersion];
          }
        }];

        // Update experiments only for 3p namespace
        NSString *namespace =
            [strongSelf->_FIRNamespace substringToIndex:[strongSelf->_FIRNamespace
                                                            rangeOfString:@":"].location];
        if ([namespace isEqualToString:RCNConstants.FIRNamespaceGoogleMobilePlatform]) {
          dispatch_async(DispatchQueue.main, ^{
            [self notifyConfigHasActivated];
          });
          [strongSelf->_configExperiment updateExperimentsWithHandler:^(NSError *_Nullable error) {
            if (completion) {
              dispatch_async(DispatchQueue.global(qos: .default), ^{
                completion(true, nil);
              });
            }
          }];
        } else {
          if (completion) {
            dispatch_async(DispatchQueue.global(qos: .default), ^{
              completion(true, nil);
            });
          }
        }
      };
      dispatch_async(_queue ?? DispatchQueue.main, applyBlock);
    }
    
    func notifyConfigHasActivated() {
      // Need a valid google app name.
      guard let appName = _appName else {
        return
      }
      // The Remote Config Swift SDK will be listening for this notification so it can tell SwiftUI to
      // update the UI.
      let appInfoDict: [String: Any] = [kFIRAppNameKey: appName];
      NotificationCenter.default.post(name: FIRRemoteConfigActivateNotification, object: self,
                                     userInfo: appInfoDict)
    }
}
