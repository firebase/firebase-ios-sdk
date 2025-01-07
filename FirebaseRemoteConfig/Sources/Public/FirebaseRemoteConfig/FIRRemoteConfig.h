/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

@class FIRApp;

/// The Firebase Remote Config service default namespace, to be used if the API method does not
/// specify a different namespace. Use the default namespace if configuring from the Google Firebase
/// service.
extern NSString *const _Nonnull FIRNamespaceGoogleMobilePlatform NS_SWIFT_NAME(
    NamespaceGoogleMobilePlatform);

/// Key used to manage throttling in NSError user info when the refreshing of Remote Config
/// parameter values (data) is throttled. The value of this key is the elapsed time since 1970,
/// measured in seconds.
extern NSString *const _Nonnull FIRRemoteConfigThrottledEndTimeInSecondsKey NS_SWIFT_NAME(
    RemoteConfigThrottledEndTimeInSecondsKey);

/**
 * Listener registration returned by `addOnConfigUpdateListener`. Calling its method `remove` stops
 * the associated listener from receiving config updates and unregisters itself.
 *
 * If remove is called and no other listener registrations remain, the connection to the real-time
 * RC backend is closed. Subsequently calling `addOnConfigUpdateListener` will re-open the
 * connection.
 */
NS_SWIFT_SENDABLE
NS_SWIFT_NAME(ConfigUpdateListenerRegistration)
@interface FIRConfigUpdateListenerRegistration : NSObject
/**
 * Removes the listener associated with this `ConfigUpdateListenerRegistration`. After the
 * initial call, subsequent calls have no effect.
 */
- (void)remove;
@end

/// Indicates whether updated data was successfully fetched.
typedef NS_ENUM(NSInteger, FIRRemoteConfigFetchStatus) {
  /// Config has never been fetched.
  FIRRemoteConfigFetchStatusNoFetchYet,
  /// Config fetch succeeded.
  FIRRemoteConfigFetchStatusSuccess,
  /// Config fetch failed.
  FIRRemoteConfigFetchStatusFailure,
  /// Config fetch was throttled.
  FIRRemoteConfigFetchStatusThrottled,
} NS_SWIFT_NAME(RemoteConfigFetchStatus);

/// Indicates whether updated data was successfully fetched and activated.
typedef NS_ENUM(NSInteger, FIRRemoteConfigFetchAndActivateStatus) {
  /// The remote fetch succeeded and fetched data was activated.
  FIRRemoteConfigFetchAndActivateStatusSuccessFetchedFromRemote,
  /// The fetch and activate succeeded from already fetched but yet unexpired config data. You can
  /// control this using minimumFetchInterval property in FIRRemoteConfigSettings.
  FIRRemoteConfigFetchAndActivateStatusSuccessUsingPreFetchedData,
  /// The fetch and activate failed.
  FIRRemoteConfigFetchAndActivateStatusError
} NS_SWIFT_NAME(RemoteConfigFetchAndActivateStatus);

/// Remote Config error domain that handles errors when fetching data from the service.
extern NSString *const _Nonnull FIRRemoteConfigErrorDomain NS_SWIFT_NAME(RemoteConfigErrorDomain);
/// Firebase Remote Config service fetch error.
typedef NS_ERROR_ENUM(FIRRemoteConfigErrorDomain, FIRRemoteConfigError){
    /// Unknown or no error.
    FIRRemoteConfigErrorUnknown = 8001,
    /// Frequency of fetch requests exceeds throttled limit.
    FIRRemoteConfigErrorThrottled = 8002,
    /// Internal error that covers all internal HTTP errors.
    FIRRemoteConfigErrorInternalError = 8003,
} NS_SWIFT_NAME(RemoteConfigError);

/// Remote Config error domain that handles errors for the real-time config update service.
extern NSString *const _Nonnull FIRRemoteConfigUpdateErrorDomain NS_SWIFT_NAME(RemoteConfigUpdateErrorDomain);
/// Firebase Remote Config real-time config update service error.
typedef NS_ERROR_ENUM(FIRRemoteConfigUpdateErrorDomain, FIRRemoteConfigUpdateError){
    /// Unable to make a connection to the Remote Config backend.
    FIRRemoteConfigUpdateErrorStreamError = 8001,
    /// Unable to fetch the latest version of the config.
    FIRRemoteConfigUpdateErrorNotFetched = 8002,
    /// The ConfigUpdate message was unparsable.
    FIRRemoteConfigUpdateErrorMessageInvalid = 8003,
    /// The Remote Config real-time config update service is unavailable.
    FIRRemoteConfigUpdateErrorUnavailable = 8004,
} NS_SWIFT_NAME(RemoteConfigUpdateError);

/// Error domain for custom signals errors.
extern NSString *const _Nonnull FIRRemoteConfigCustomSignalsErrorDomain NS_SWIFT_NAME(RemoteConfigCustomSignalsErrorDomain);

/// Firebase Remote Config custom signals error.
typedef NS_ERROR_ENUM(FIRRemoteConfigCustomSignalsErrorDomain, FIRRemoteConfigCustomSignalsError){
    /// Unknown error.
    FIRRemoteConfigCustomSignalsErrorUnknown = 8101,
    /// Invalid value type in the custom signals dictionary.
    FIRRemoteConfigCustomSignalsErrorInvalidValueType = 8102,
    /// Limit exceeded for key length, value length, or number of signals.
    FIRRemoteConfigCustomSignalsErrorLimitExceeded = 8103,
} NS_SWIFT_NAME(RemoteConfigCustomSignalsError);

/// Enumerated value that indicates the source of Remote Config data. Data can come from
/// the Remote Config service, the DefaultConfig that is available when the app is first installed,
/// or a static initialized value if data is not available from the service or DefaultConfig.
typedef NS_ENUM(NSInteger, FIRRemoteConfigSource) {
  FIRRemoteConfigSourceRemote,   ///< The data source is the Remote Config service.
  FIRRemoteConfigSourceDefault,  ///< The data source is the DefaultConfig defined for this app.
  FIRRemoteConfigSourceStatic,   ///< The data doesn't exist, return a static initialized value.
} NS_SWIFT_NAME(RemoteConfigSource);

/// Completion handler invoked by fetch methods when they get a response from the server.
///
/// @param status Config fetching status.
/// @param error  Error message on failure.
typedef void (^FIRRemoteConfigFetchCompletion)(FIRRemoteConfigFetchStatus status,
                                               NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/// Completion handler invoked by activate method upon completion.
/// @param error  Error message on failure. Nil if activation was successful.
typedef void (^FIRRemoteConfigActivateCompletion)(NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/// Completion handler invoked upon completion of Remote Config initialization.
///
/// @param initializationError nil if initialization succeeded.
typedef void (^FIRRemoteConfigInitializationCompletion)(NSError *_Nullable initializationError)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/// Completion handler invoked by the fetchAndActivate method. Used to convey status of fetch and,
/// if successful, resultant activate call
/// @param status Config fetching status.
/// @param error  Error message on failure of config fetch
typedef void (^FIRRemoteConfigFetchAndActivateCompletion)(
    FIRRemoteConfigFetchAndActivateStatus status, NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

#pragma mark - FIRRemoteConfigValue
/// This class provides a wrapper for Remote Config parameter values, with methods to get parameter
/// values as different data types.
NS_SWIFT_NAME(RemoteConfigValue)
@interface FIRRemoteConfigValue : NSObject <NSCopying>
/// Gets the value as a string.
@property(nonatomic, readonly, nonnull) NSString *stringValue;
/// Gets the value as a number value.
@property(nonatomic, readonly, nonnull) NSNumber *numberValue;
/// Gets the value as a NSData object.
@property(nonatomic, readonly, nonnull) NSData *dataValue;
/// Gets the value as a boolean.
@property(nonatomic, readonly) BOOL boolValue;
/// Gets a foundation object (NSDictionary / NSArray) by parsing the value as JSON. This method uses
/// NSJSONSerialization's JSONObjectWithData method with an options value of 0.
@property(nonatomic, readonly, nullable) id JSONValue NS_SWIFT_NAME(jsonValue);
/// Identifies the source of the fetched value.
@property(nonatomic, readonly) FIRRemoteConfigSource source;
@end

#pragma mark - FIRRemoteConfigSettings
/// Firebase Remote Config settings.
NS_SWIFT_NAME(RemoteConfigSettings)
@interface FIRRemoteConfigSettings : NSObject
/// Indicates the default value in seconds to set for the minimum interval that needs to elapse
/// before a fetch request can again be made to the Remote Config backend. After a fetch request to
/// the backend has succeeded, no additional fetch requests to the backend will be allowed until the
/// minimum fetch interval expires. Note that you can override this default on a per-fetch request
/// basis using `RemoteConfig.fetch(withExpirationDuration:)`. For example, setting
/// the expiration duration to 0 in the fetch request will override the `minimumFetchInterval` and
/// allow the request to proceed.
@property(nonatomic, assign) NSTimeInterval minimumFetchInterval;
/// Indicates the default value in seconds to abandon a pending fetch request made to the backend.
/// This value is set for outgoing requests as the `timeoutIntervalForRequest` as well as the
/// `timeoutIntervalForResource` on the `NSURLSession`'s configuration.
@property(nonatomic, assign) NSTimeInterval fetchTimeout;
@end

#pragma mark - FIRRemoteConfigUpdate
/// Used by Remote Config real-time config update service, this class represents changes between the
/// newly fetched config and the current one. An instance of this class is passed to
/// `FIRRemoteConfigUpdateCompletion` when a new config version has been automatically fetched.
NS_SWIFT_NAME(RemoteConfigUpdate)
@interface FIRRemoteConfigUpdate : NSObject

/// Parameter keys whose values have been updated from the currently activated values. Includes
/// keys that are added, deleted, and whose value, value source, or metadata has changed.
@property(nonatomic, readonly, nonnull) NSSet<NSString *> *updatedKeys;

@end

#pragma mark - FIRRemoteConfig
/// Firebase Remote Config class. The class method `remoteConfig()` can be used
/// to fetch, activate and read config results and set default config results on the default
/// Remote Config instance.
NS_SWIFT_NAME(RemoteConfig)
@interface FIRRemoteConfig : NSObject <NSFastEnumeration>
/// Last successful fetch completion time.
@property(nonatomic, readonly, strong, nullable) NSDate *lastFetchTime;
/// Last fetch status. The status can be any enumerated value from `RemoteConfigFetchStatus`.
@property(nonatomic, readonly, assign) FIRRemoteConfigFetchStatus lastFetchStatus;
/// Config settings are custom settings.
@property(nonatomic, readwrite, strong, nonnull) FIRRemoteConfigSettings *configSettings;

/// Returns the `RemoteConfig` instance configured for the default Firebase app. This singleton
/// object contains the complete set of Remote Config parameter values available to the app,
/// including the Active Config and Default Config. This object also caches values fetched from the
/// Remote Config server until they are copied to the Active Config by calling `activate()`. When
/// you fetch values from the Remote Config server using the default Firebase app, you should use
/// this class method to create and reuse a shared instance of `RemoteConfig`.
+ (nonnull FIRRemoteConfig *)remoteConfig NS_SWIFT_NAME(remoteConfig());

/// Returns the `RemoteConfig` instance for your (non-default) Firebase appID. Note that Firebase
/// analytics does not work for non-default app instances. This singleton object contains the
/// complete set of Remote Config parameter values available to the app, including the Active Config
/// and Default Config. This object also caches values fetched from the Remote Config Server until
/// they are copied to the Active Config by calling `activate())`. When you fetch values
/// from the Remote Config Server using the non-default Firebase app, you should use this
/// class method to create and reuse shared instance of `RemoteConfig`.
+ (nonnull FIRRemoteConfig *)remoteConfigWithApp:(nonnull FIRApp *)app
    NS_SWIFT_NAME(remoteConfig(app:));

/// Unavailable. Use +remoteConfig instead.
- (nonnull instancetype)init __attribute__((unavailable("Use +remoteConfig instead.")));

/// Ensures initialization is complete and clients can begin querying for Remote Config values.
/// @param completionHandler Initialization complete callback with error parameter.
- (void)ensureInitializedWithCompletionHandler:
    (void (^_Nonnull)(NSError *_Nullable initializationError))completionHandler;
#pragma mark - Fetch

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 180000)
/// Fetches Remote Config data with a callback. Call `activate()` to make fetched data
/// available to your app.
///
/// Note: This method uses a Firebase Installations token to identify the app instance, and once
/// it's called, it periodically sends data to the Firebase backend. (see
/// `Installations.authToken(completion:)`).
/// To stop the periodic sync, call `Installations.delete(completion:)`
/// and avoid calling this method again.
///
/// @param completionHandler Fetch operation callback with status and error parameters.
- (void)fetchWithCompletionHandler:
    (void (^_Nullable NS_SWIFT_SENDABLE)(FIRRemoteConfigFetchStatus status,
                                         NSError *_Nullable error))completionHandler;
#else
/// Fetches Remote Config data with a callback. Call `activate()` to make fetched data
/// available to your app.
///
/// Note: This method uses a Firebase Installations token to identify the app instance, and once
/// it's called, it periodically sends data to the Firebase backend. (see
/// `Installations.authToken(completion:)`).
/// To stop the periodic sync, call `Installations.delete(completion:)`
/// and avoid calling this method again.
///
/// @param completionHandler Fetch operation callback with status and error parameters.
- (void)fetchWithCompletionHandler:(void (^_Nullable)(FIRRemoteConfigFetchStatus status,
                                                      NSError *_Nullable error))completionHandler;
#endif

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 180000)
/// Fetches Remote Config data and sets a duration that specifies how long config data lasts.
/// Call `activateWithCompletion:` to make fetched data available to your app.
///
/// Note: This method uses a Firebase Installations token to identify the app instance, and once
/// it's called, it periodically sends data to the Firebase backend. (see
/// `Installations.authToken(completion:)`).
/// To stop the periodic sync, call `Installations.delete(completion:)`
/// and avoid calling this method again.
///
/// @param expirationDuration  Override the (default or optionally set `minimumFetchInterval`
/// property in RemoteConfigSettings) `minimumFetchInterval` for only the current request, in
/// seconds. Setting a value of 0 seconds will force a fetch to the backend.
/// @param completionHandler   Fetch operation callback with status and error parameters.
- (void)fetchWithExpirationDuration:(NSTimeInterval)expirationDuration
                  completionHandler:(void (^_Nullable NS_SWIFT_SENDABLE)(
                                        FIRRemoteConfigFetchStatus status,
                                        NSError *_Nullable error))completionHandler;
#else
/// Fetches Remote Config data and sets a duration that specifies how long config data lasts.
/// Call `activateWithCompletion:` to make fetched data available to your app.
///
/// Note: This method uses a Firebase Installations token to identify the app instance, and once
/// it's called, it periodically sends data to the Firebase backend. (see
/// `Installations.authToken(completion:)`).
/// To stop the periodic sync, call `Installations.delete(completion:)`
/// and avoid calling this method again.
///
/// @param expirationDuration  Override the (default or optionally set `minimumFetchInterval`
/// property in RemoteConfigSettings) `minimumFetchInterval` for only the current request, in
/// seconds. Setting a value of 0 seconds will force a fetch to the backend.
/// @param completionHandler   Fetch operation callback with status and error parameters.
- (void)fetchWithExpirationDuration:(NSTimeInterval)expirationDuration
                  completionHandler:(void (^_Nullable)(FIRRemoteConfigFetchStatus status,
                                                       NSError *_Nullable error))completionHandler;
#endif

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 180000)
/// Fetches Remote Config data and if successful, activates fetched data. Optional completion
/// handler callback is invoked after the attempted activation of data, if the fetch call succeeded.
///
/// Note: This method uses a Firebase Installations token to identify the app instance, and once
/// it's called, it periodically sends data to the Firebase backend. (see
/// `Installations.authToken(completion:)`).
/// To stop the periodic sync, call `Installations.delete(completion:)`
/// and avoid calling this method again.
///
/// @param completionHandler Fetch operation callback with status and error parameters.
- (void)fetchAndActivateWithCompletionHandler:
    (void (^_Nullable NS_SWIFT_SENDABLE)(FIRRemoteConfigFetchAndActivateStatus status,
                                         NSError *_Nullable error))completionHandler;
#else
/// Fetches Remote Config data and if successful, activates fetched data. Optional completion
/// handler callback is invoked after the attempted activation of data, if the fetch call succeeded.
///
/// Note: This method uses a Firebase Installations token to identify the app instance, and once
/// it's called, it periodically sends data to the Firebase backend. (see
/// `Installations.authToken(completion:)`).
/// To stop the periodic sync, call `Installations.delete(completion:)`
/// and avoid calling this method again.
///
/// @param completionHandler Fetch operation callback with status and error parameters.
- (void)fetchAndActivateWithCompletionHandler:
    (void (^_Nullable)(FIRRemoteConfigFetchAndActivateStatus status,
                       NSError *_Nullable error))completionHandler;
#endif

#pragma mark - Apply

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 180000)
/// Applies Fetched Config data to the Active Config, causing updates to the behavior and appearance
/// of the app to take effect (depending on how config data is used in the app).
/// @param completion Activate operation callback with changed and error parameters.
- (void)activateWithCompletion:
    (void (^_Nullable NS_SWIFT_SENDABLE)(BOOL changed, NSError *_Nullable error))completion;
#else
/// Applies Fetched Config data to the Active Config, causing updates to the behavior and appearance
/// of the app to take effect (depending on how config data is used in the app).
/// @param completion Activate operation callback with changed and error parameters.
- (void)activateWithCompletion:(void (^_Nullable)(BOOL changed,
                                                  NSError *_Nullable error))completion;
#endif

#pragma mark - Get Config
/// Enables access to configuration values by using object subscripting syntax.
/// For example:
///     let config = RemoteConfig.remoteConfig()
///     let value = config["yourKey"]
///     let boolValue = value.boolValue
///     let number = config["yourKey"].numberValue
- (nonnull FIRRemoteConfigValue *)objectForKeyedSubscript:(nonnull NSString *)key;

/// Gets the config value.
/// @param key Config key.
- (nonnull FIRRemoteConfigValue *)configValueForKey:(nullable NSString *)key;

/// Gets the config value of a given source from the default namespace.
/// @param key              Config key.
/// @param source           Config value source.
- (nonnull FIRRemoteConfigValue *)configValueForKey:(nullable NSString *)key
                                             source:(FIRRemoteConfigSource)source;

/// Gets all the parameter keys of a given source from the default namespace.
///
/// @param source           The config data source.
/// @return                 An array of keys under the given source.
- (nonnull NSArray<NSString *> *)allKeysFromSource:(FIRRemoteConfigSource)source;

/// Returns the set of parameter keys that start with the given prefix, from the default namespace
///                         in the active config.
///
/// @param prefix           The key prefix to look for. If prefix is nil or empty, returns all the
///                         keys.
/// @return                 The set of parameter keys that start with the specified prefix.
- (nonnull NSSet<NSString *> *)keysWithPrefix:(nullable NSString *)prefix;

#pragma mark - Defaults
/// Sets config defaults for parameter keys and values in the default namespace config.
/// @param defaults         A dictionary mapping a NSString * key to a NSObject * value.
- (void)setDefaults:(nullable NSDictionary<NSString *, NSObject *> *)defaults;

/// Sets default configs from plist for default namespace.
///
/// @param fileName The plist file name, with no file name extension. For example, if the plist file
///                 is named `defaultSamples.plist`:
///                 `RemoteConfig.remoteConfig().setDefaults(fromPlist: "defaultSamples")`
- (void)setDefaultsFromPlistFileName:(nullable NSString *)fileName
    NS_SWIFT_NAME(setDefaults(fromPlist:));

/// Returns the default value of a given key from the default config.
///
/// @param key              The parameter key of default config.
/// @return                 Returns the default value of the specified key. Returns
///                         nil if the key doesn't exist in the default config.
- (nullable FIRRemoteConfigValue *)defaultValueForKey:(nullable NSString *)key;

#pragma mark - Real-time Config Updates

/// Completion handler invoked by `addOnConfigUpdateListener` when there is an update to
/// the config from the backend.
///
/// @param configUpdate An instance of `FIRRemoteConfigUpdate` that contains information on which
/// key's values have changed.
/// @param error  Error message on failure.
typedef void (^FIRRemoteConfigUpdateCompletion)(FIRRemoteConfigUpdate *_Nullable configUpdate,
                                                NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/// Start listening for real-time config updates from the Remote Config backend and automatically
/// fetch updates when they're available.
///
/// If a connection to the Remote Config backend is not already open, calling this method will
/// open it. Multiple listeners can be added by calling this method again, but subsequent calls
/// re-use the same connection to the backend.
///
/// Note: Real-time Remote Config requires the Firebase Remote Config Realtime API. See Get started
/// with Firebase Remote Config at https://firebase.google.com/docs/remote-config/get-started for
/// more information.
///
/// @param listener              The configured listener that is called for every config update.
/// @return              Returns a registration representing the listener. The registration contains
/// a remove method, which can be used to stop receiving updates for the provided listener.
- (FIRConfigUpdateListenerRegistration *_Nonnull)addOnConfigUpdateListener:
    (FIRRemoteConfigUpdateCompletion _Nonnull)listener
    NS_SWIFT_NAME(addOnConfigUpdateListener(remoteConfigUpdateCompletion:));

- (void)setCustomSignals:(nonnull NSDictionary<NSString *, NSObject *> *)customSignals
          withCompletion:(void (^_Nullable)(NSError *_Nullable error))completionHandler
    NS_REFINED_FOR_SWIFT;

@end
