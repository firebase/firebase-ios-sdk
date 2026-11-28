/*
 * Copyright 2026 Google LLC
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

// Internal FirebaseCore API and helpers for FirebaseCore's Swift unit tests.
//
// The declarations below describe internal Objective-C selectors of FirebaseCore. They're
// declared here, instead of in FirebaseCore's headers, so that they stay out of the public API,
// and they're resolved at run time, so they keep working when FirebaseCore is implemented in
// Swift. They're covered by FirebaseCore/Tests/RuntimeABI. The internal API that other products
// use is in FirebaseCoreExtension.

#import <Foundation/Foundation.h>

#if SWIFT_PACKAGE
@import FirebaseCore;
@import FirebaseCoreExtension;
#else
#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseCoreExtension/FirebaseCoreInternal.h>
#endif  // SWIFT_PACKAGE

NS_ASSUME_NONNULL_BEGIN

@interface FIROptions (CoreTestHooks)

/// Clears the cached default options and default options dictionary.
+ (void)resetDefaultOptions;

/// The contents of GoogleService-Info.plist, read once and cached.
+ (nullable NSDictionary<NSString *, id> *)defaultOptionsDictionary;

/// Creates options from a GoogleService-Info.plist dictionary, as `+defaultOptions` does.
- (instancetype)initInternalWithOptionsDictionary:
    (nullable NSDictionary<NSString *, id> *)optionsDictionary;

/// Combines the analytics flags of the options with those in the given Info.plist dictionary.
- (NSDictionary<NSString *, id> *)analyticsOptionsDictionaryWithInfoDictionary:
    (nullable NSDictionary<NSString *, id> *)infoDictionary;

@property(nonatomic, readonly) BOOL isAnalyticsCollectionExplicitlySet;
@property(nonatomic, readonly) BOOL isAnalyticsCollectionEnabled;
@property(nonatomic, readonly) BOOL isAnalyticsCollectionDeactivated;
@property(nonatomic, readonly) BOOL isMeasurementEnabled;
@property(nonatomic, readonly, copy) NSString *libraryVersionID;
@property(nonatomic, getter=isEditingLocked) BOOL editingLocked;
@property(nonatomic) BOOL usingOptionsFromDefaultPlist;

@end

// Internal FIRApp API that isn't declared in FirebaseCore/Extension/FIRAppInternal.h. The tests use
// FirebaseCoreExtension for the rest of the internal FIRApp API.
@interface FIRApp (CoreTestHooks)

/// Whether `appID` is a valid GOOGLE_APP_ID.
+ (BOOL)validateAppID:(nullable NSString *)appID NS_SWIFT_NAME(validateAppID(_:));

/// Whether `appID` has the format of a GOOGLE_APP_ID of the given version.
+ (BOOL)validateAppIDFormat:(nullable NSString *)appID
                withVersion:(nullable NSString *)version
    NS_SWIFT_NAME(validateAppIDFormat(_:withVersion:));

/// Whether the hashed bundle ID in `appID` is valid for the given version.
+ (BOOL)validateBundleIDHashWithinAppID:(nullable NSString *)appID
                             forVersion:(nullable NSString *)version
    NS_SWIFT_NAME(validateBundleIDHash(withinAppID:forVersion:));

/// Whether the GOOGLE_APP_ID of the app's options is valid.
- (BOOL)isAppIDValid NS_SWIFT_NAME(isAppIDValid());

@end

/// Internal FirebaseCore class that finds GoogleService-Info.plist and checks bundle IDs.
@interface FIRBundleUtil : NSObject

/// The bundles that FirebaseCore searches, starting with the main bundle.
+ (NSArray<NSBundle *> *)relevantBundles NS_SWIFT_NAME(relevantBundles());

/// The URL schemes in the Info.plist of the relevant bundles.
+ (NSArray<NSString *> *)relevantURLSchemes NS_SWIFT_NAME(relevantURLSchemes());

/// The path of the first resource with the given name and type in `bundles`.
+ (nullable NSString *)optionsDictionaryPathWithResourceName:(NSString *)resourceName
                                                 andFileType:(NSString *)fileType
                                                   inBundles:(NSArray<NSBundle *> *)bundles
    NS_SWIFT_NAME(optionsDictionaryPath(resourceName:fileType:bundles:));

/// Whether a bundle in `bundles` has the given bundle ID, or, in an app extension, has it with an
/// extension suffix.
+ (BOOL)hasBundleIdentifierPrefix:(NSString *)bundleIdentifier
                        inBundles:(NSArray<NSBundle *> *)bundles
    NS_SWIFT_NAME(hasBundleIdentifierPrefix(_:in:));

/// Whether FirebaseCore considers itself to run in an app extension.
+ (BOOL)isAppExtension NS_SWIFT_NAME(isAppExtension());

- (instancetype)init NS_UNAVAILABLE;

@end

/// Internal FirebaseCore class that forwards the Analytics collection flag to Analytics. Found by
/// name by GoogleAppMeasurement.
@interface FIRAnalyticsConfiguration : NSObject

+ (FIRAnalyticsConfiguration *)sharedInstance NS_SWIFT_NAME(sharedInstance());

/// Posts FIRAnalyticsConfigurationSetEnabledNotification, and persists the flag in user defaults
/// when `shouldPersist` is true.
- (void)setAnalyticsCollectionEnabled:(BOOL)analyticsCollectionEnabled
                       persistSetting:(BOOL)shouldPersist
    NS_SWIFT_NAME(setAnalyticsCollectionEnabled(_:persistSetting:));

- (instancetype)init NS_UNAVAILABLE;

@end

// Internal FIRTimestamp API.
@interface FIRTimestamp (CoreTestHooks)

/// The timestamp in ISO 8601 format with nanoseconds, for example
/// "1912-04-14T23:40:00.000000000Z".
@property(nonatomic, readonly) NSString *ISO8601String NS_SWIFT_NAME(iso8601String);

@end

// Internal FIRConfiguration API.
@interface FIRConfiguration (CoreTestHooks)

/// The configuration that forwards the Analytics collection flag.
@property(nonatomic, readonly) FIRAnalyticsConfiguration *analyticsConfiguration;

@end

// Internal FIRComponentContainer API that isn't declared in FirebaseCoreExtension.
@interface FIRComponentContainer (CoreTestHooks)

/// Adds `klass` to `allRegistrants`. Containers created with those registrants get its
/// components.
+ (void)registerAsComponentRegistrant:(Class<FIRLibrary>)klass
                                inSet:(NSMutableSet<Class> *)allRegistrants
    NS_SWIFT_NAME(registerAsComponentRegistrant(_:in:));

/// Creates a container for `app` with the components of `allRegistrants`.
- (instancetype)initWithApp:(FIRApp *)app registrants:(NSMutableSet<Class> *)allRegistrants;

/// The creation blocks of the registered components, keyed by protocol name.
@property(nonatomic, readonly)
    NSMutableDictionary<NSString *, FIRComponentCreationBlock> *components;

/// The cached component instances, keyed by protocol name.
@property(nonatomic, readonly) NSMutableDictionary<NSString *, id> *cachedInstances;

/// Creates the instances of the components that asked to be created eagerly.
- (void)instantiateEagerComponents;

/// Removes the cached instances, after telling them that the app will be deleted.
- (void)removeAllCachedInstances;

/// Removes the components, so the container creates no more instances.
- (void)removeAllComponents;

@end

// Internal FIRHeartbeatLogger API.
@interface FIRHeartbeatLogger (CoreTestHooks)

/// Creates a logger that stores heartbeats under `appID` and asks `userAgentProvider` for the user
/// agent each time it logs.
- (instancetype)initWithAppID:(NSString *)appID
            userAgentProvider:(NSString * (^)(void))userAgentProvider;

@end

/// Internal FirebaseCore class that builds the Firebase user agent string.
@interface FIRFirebaseUserAgent : NSObject

/// The environment components and the components set with `setValue:forComponent:`, as
/// "name/value" pairs sorted by name and separated by spaces.
- (NSString *)firebaseUserAgent NS_SWIFT_NAME(firebaseUserAgent());

/// Sets the value of a component, or removes the component when `value` is nil.
- (void)setValue:(nullable NSString *)value
    forComponent:(NSString *)componentName NS_SWIFT_NAME(setValue(_:forComponent:));

/// Removes the components set with `setValue:forComponent:`.
- (void)reset NS_SWIFT_NAME(reset());

@end

NS_SWIFT_NAME(CoreTestHooks)
@interface FIRCoreTestHooks : NSObject

/// Replaces the bundles that FirebaseCore searches for GoogleService-Info.plist and checks the
/// bundle ID against. Pass nil to restore the default bundles.
+ (void)setRelevantBundles:(nullable NSArray<NSBundle *> *)bundles;

/// Makes FirebaseCore use `userDefaults` instead of the standard user defaults: FIRApp for the data
/// collection flag, and FIRAnalyticsConfiguration for the persisted Analytics flag. Pass nil to
/// restore the standard user defaults.
+ (void)setUserDefaults:(nullable NSUserDefaults *)userDefaults;

/// Makes FirebaseCore (FIRApp and FIRBundleUtil) behave as if it were (or weren't) running in an
/// app extension. Pass nil to restore the real environment.
+ (void)setIsAppExtension:(nullable NSNumber *)isAppExtension;

/// Sets the same override through `+[FIRApp setIsAppExtensionForTesting:]`, which FIRAppTest.m
/// uses, to check that FIRApp forwards it to FIRBundleUtil.
+ (void)setIsAppExtensionThroughFirebaseApp:(nullable NSNumber *)isAppExtension;

/// Makes FIRApp read the data collection flag from `infoDictionary` instead of the main bundle's
/// Info.plist. Pass nil to restore the main bundle's Info.plist.
+ (void)setInfoDictionary:(nullable NSDictionary<NSString *, id> *)infoDictionary;

/// Calls `handler` with the app's GOOGLE_APP_ID whenever an app initialized from now on logs a
/// heartbeat. Pass nil to stop recording for apps initialized afterwards.
///
/// The apps use real heartbeat loggers with a test-only storage ID. Each call removes the
/// heartbeats that the loggers created by the previous call stored.
+ (void)setHeartbeatLogHandler:(nullable void (^)(NSString *appID))handler;

/// Calls `+[FIRApp registerInternalLibrary:withName:withVersion:]` without the compile-time check
/// that `library` conforms to FIRLibrary, so tests can pass classes that don't.
+ (void)registerInternalLibraryWithUncheckedClass:(Class)library
                                             name:(NSString *)name
                                          version:(NSString *)version
    NS_SWIFT_NAME(registerInternalLibrary(uncheckedClass:name:version:));

/// Resets the logger to its state at launch, and makes it read the persisted debug mode from
/// `userDefaults` and the launch arguments from `launchArguments` when it initializes again. Pass
/// nil for the standard user defaults and the process's launch arguments. Only available in DEBUG
/// builds; returns NO if the seam isn't available.
+ (BOOL)resetLoggerWithUserDefaults:(nullable NSUserDefaults *)userDefaults
                    launchArguments:(nullable NSArray<NSString *> *)launchArguments
    NS_SWIFT_NAME(resetLogger(userDefaults:launchArguments:));

/// Calls `+[FIRApp configureWithOptions:]`, which can't be passed nil from Swift.
+ (void)configureWithNullableOptions:(nullable FIROptions *)options;

/// Calls `+[FIRApp configureWithName:options:]`, which can't be passed nil from Swift.
+ (void)configureWithNullableName:(nullable NSString *)name options:(nullable FIROptions *)options;

/// Runs `block` and returns the Objective-C exception it raised, or nil if it raised none.
+ (nullable NSException *)exceptionRaisedBy:(NS_NOESCAPE void (^)(void))block;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
