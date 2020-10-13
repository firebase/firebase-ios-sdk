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
typedef NS_ENUM(NSInteger, FIRRemoteConfigError) {
  /// Unknown or no error.
  FIRRemoteConfigErrorUnknown = 8001,
  /// Frequency of fetch requests exceeds throttled limit.
  FIRRemoteConfigErrorThrottled = 8002,
  /// Internal error that covers all internal HTTP errors.
  FIRRemoteConfigErrorInternalError = 8003,
} NS_SWIFT_NAME(RemoteConfigError);

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
    NS_SWIFT_NAME(RemoteConfigFetchCompletion);

/// Completion handler invoked by activate method upon completion.
/// @param error  Error message on failure. Nil if activation was successful.
typedef void (^FIRRemoteConfigActivateCompletion)(NSError *_Nullable error)
    NS_SWIFT_NAME(RemoteConfigActivateCompletion);

/// Completion handler invoked upon completion of Remote Config initialization.
///
/// @param initializationError nil if initialization succeeded.
typedef void (^FIRRemoteConfigInitializationCompletion)(NSError *_Nullable initializationError)
    NS_SWIFT_NAME(RemoteConfigInitializationCompletion);

/// Completion handler invoked by the fetchAndActivate method. Used to convey status of fetch and,
/// if successful, resultant activate call
/// @param status Config fetching status.
/// @param error  Error message on failure of config fetch
typedef void (^FIRRemoteConfigFetchAndActivateCompletion)(
    FIRRemoteConfigFetchAndActivateStatus status, NSError *_Nullable error)
    NS_SWIFT_NAME(RemoteConfigFetchAndActivateCompletion);

#pragma mark - FIRRemoteConfigValue
/// This class provides a wrapper for Remote Config parameter values, with methods to get parameter
/// values as different data types.
NS_SWIFT_NAME(RemoteConfigValue)
@interface FIRRemoteConfigValue : NSObject <NSCopying>
/// Gets the value as a string.
@property(nonatomic, readonly, nullable) NSString *stringValue;
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
/// basis using -[FIRRemoteConfig fetchWithExpirationDuration:completionHandler]. For E.g. setting
/// the expiration duration to 0 in the fetch request will override the minimumFetchInterval and
/// allow the request to the backend.
@property(nonatomic, assign) NSTimeInterval minimumFetchInterval;
/// Indicates the default value in seconds to abandon a pending fetch request made to the backend.
/// This value is set for outgoing requests as the timeoutIntervalForRequest as well as the
/// timeoutIntervalForResource on the NSURLSession's configuration.
@property(nonatomic, assign) NSTimeInterval fetchTimeout;
@end

#pragma mark - FIRRemoteConfig
/// Firebase Remote Config class. The shared instance method +remoteConfig can be created and used
/// to fetch, activate and read config results and set default config results.
NS_SWIFT_NAME(RemoteConfig)
@interface FIRRemoteConfig : NSObject <NSFastEnumeration>
/// Last successful fetch completion time.
@property(nonatomic, readonly, strong, nullable) NSDate *lastFetchTime;
/// Last fetch status. The status can be any enumerated value from FIRRemoteConfigFetchStatus.
@property(nonatomic, readonly, assign) FIRRemoteConfigFetchStatus lastFetchStatus;
/// Config settings are custom settings.
@property(nonatomic, readwrite, strong, nonnull) FIRRemoteConfigSettings *configSettings;

/// Returns the FIRRemoteConfig instance configured for the default Firebase app. This singleton
/// object contains the complete set of Remote Config parameter values available to the app,
/// including the Active Config and Default Config. This object also caches values fetched from the
/// Remote Config Server until they are copied to the Active Config by calling
/// `activateWithCompletion:`. When you fetch values from the Remote Config Server using the default
/// Firebase namespace service, you should use this class method to create a shared instance of the
/// FIRRemoteConfig object to ensure that your app will function properly with the Remote Config
/// Server and the Firebase service.
+ (nonnull FIRRemoteConfig *)remoteConfig NS_SWIFT_NAME(remoteConfig());

/// Returns the FIRRemoteConfig instance for your (non-default) Firebase appID. Note that Firebase
/// analytics does not work for non-default app instances. This singleton object contains the
/// complete set of Remote Config parameter values available to the app, including the Active Config
/// and Default Config. This object also caches values fetched from the Remote Config Server until
/// they are copied to the Active Config by calling `activateWithCompletion:`. When you fetch values
/// from the Remote Config Server using the default Firebase namespace service, you should use this
/// class method to create a shared instance of the FIRRemoteConfig object to ensure that your app
/// will function properly with the Remote Config Server and the Firebase service.
+ (nonnull FIRRemoteConfig *)remoteConfigWithApp:(nonnull FIRApp *)app
    NS_SWIFT_NAME(remoteConfig(app:));

/// Unavailable. Use +remoteConfig instead.
- (nonnull instancetype)init __attribute__((unavailable("Use +remoteConfig instead.")));

/// Ensures initialization is complete and clients can begin querying for Remote Config values.
/// @param completionHandler Initialization complete callback with error parameter.
- (void)ensureInitializedWithCompletionHandler:
    (void (^_Nonnull)(NSError *_Nullable initializationError))completionHandler;
#pragma mark - Fetch
/// Fetches Remote Config data with a callback. Call `activateWithCompletion:` to make fetched data
/// available to your app.
///
/// Note: This method uses a Firebase Installations token to identify the app instance, and once
/// it's called, it periodically sends data to the Firebase backend. (see
/// `[FIRInstallations authTokenWithCompletion:]`).
/// To stop the periodic sync, developers need to call `[FIRInstallations deleteWithCompletion:]`
/// and avoid calling this method again.
///
/// @param completionHandler Fetch operation callback with status and error parameters.
- (void)fetchWithCompletionHandler:(void (^_Nullable)(FIRRemoteConfigFetchStatus status,
                                                      NSError *_Nullable error))completionHandler;

/// Fetches Remote Config data and sets a duration that specifies how long config data lasts.
/// Call `activateWithCompletion:` to make fetched data available to your app.
///
/// Note: This method uses a Firebase Installations token to identify the app instance, and once
/// it's called, it periodically sends data to the Firebase backend. (see
/// `[FIRInstallations authTokenWithCompletion:]`).
/// To stop the periodic sync, developers need to call `[FIRInstallations deleteWithCompletion:]`
/// and avoid calling this method again.
///
/// @param expirationDuration  Override the (default or optionally set minimumFetchInterval property
/// in FIRRemoteConfigSettings) minimumFetchInterval for only the current request, in seconds.
/// Setting a value of 0 seconds will force a fetch to the backend.
/// @param completionHandler   Fetch operation callback with status and error parameters.
- (void)fetchWithExpirationDuration:(NSTimeInterval)expirationDuration
                  completionHandler:(void (^_Nullable)(FIRRemoteConfigFetchStatus status,
                                                       NSError *_Nullable error))completionHandler;

/// Fetches Remote Config data and if successful, activates fetched data. Optional completion
/// handler callback is invoked after the attempted activation of data, if the fetch call succeeded.
///
/// Note: This method uses a Firebase Installations token to identify the app instance, and once
/// it's called, it periodically sends data to the Firebase backend. (see
/// `[FIRInstallations authTokenWithCompletion:]`).
/// To stop the periodic sync, developers need to call `[FIRInstallations deleteWithCompletion:]`
/// and avoid calling this method again.
///
/// @param completionHandler Fetch operation callback with status and error parameters.
- (void)fetchAndActivateWithCompletionHandler:
    (void (^_Nullable)(FIRRemoteConfigFetchAndActivateStatus status,
                       NSError *_Nullable error))completionHandler;

#pragma mark - Apply

/// Applies Fetched Config data to the Active Config, causing updates to the behavior and appearance
/// of the app to take effect (depending on how config data is used in the app).
/// @param completion Activate operation callback with changed and error parameters.
- (void)activateWithCompletion:(void (^_Nullable)(BOOL changed,
                                                  NSError *_Nullable error))completion;

#pragma mark - Get Config
/// Enables access to configuration values by using object subscripting syntax.
/// <pre>
/// // Example:
/// FIRRemoteConfig *config = [FIRRemoteConfig remoteConfig];
/// FIRRemoteConfigValue *value = config[@"yourKey"];
/// BOOL b = value.boolValue;
/// NSNumber *number = config[@"yourKey"].numberValue;
/// </pre>
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
///                 is defaultSamples.plist, call:
///                 [[FIRRemoteConfig remoteConfig] setDefaultsFromPlistFileName:@"defaultSamples"];
- (void)setDefaultsFromPlistFileName:(nullable NSString *)fileName
    NS_SWIFT_NAME(setDefaults(fromPlist:));

/// Returns the default value of a given key from the default config.
///
/// @param key              The parameter key of default config.
/// @return                 Returns the default value of the specified key. Returns
///                         nil if the key doesn't exist in the default config.
- (nullable FIRRemoteConfigValue *)defaultValueForKey:(nullable NSString *)key;

@end
