/*
 * Copyright 2020 Google LLC
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

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheck.h"

#import <AppCheckCore/AppCheckCore.h>
#import <FirebaseAppCheckInterop/FirebaseAppCheckInterop.h>
#import <GoogleUtilities/GULUserDefaults.h>

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckErrors.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProvider.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProviderFactory.h"

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheck+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckSettings.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckTokenResult.h"
#import "FirebaseAppCheck/Sources/Core/FIRInternalAppCheckProvider.h"

NS_ASSUME_NONNULL_BEGIN

/// A notification with the specified name is sent to the default notification center
/// (`NotificationCenter.default`) each time a Firebase app check token is refreshed.
/// The user info dictionary contains `kFIRAppCheckTokenNotificationKey` and
/// `kFIRAppCheckAppNameNotificationKey` keys.
const NSNotificationName FIRAppCheckAppCheckTokenDidChangeNotification =
    @"FIRAppCheckAppCheckTokenDidChangeNotification";

/// `userInfo` key for the `AppCheckToken` in `appCheckTokenRefreshNotification`.
NSString *const kFIRAppCheckTokenNotificationKey = @"FIRAppCheckTokenNotificationKey";

/// `userInfo` key for the `FirebaseApp.name` in `appCheckTokenRefreshNotification`.
NSString *const kFIRAppCheckAppNameNotificationKey = @"FIRAppCheckAppNameNotificationKey";

static id<FIRAppCheckProviderFactory> _providerFactory;

@interface FIRAppCheck () <FIRAppCheckInterop, GACAppCheckTokenDelegate>
@property(class, nullable) id<FIRAppCheckProviderFactory> providerFactory;

@property(nonatomic, readonly) NSString *appName;
@property(nonatomic, readonly) NSNotificationCenter *notificationCenter;
@property(nonatomic, readonly) FIRAppCheckSettings *settings;
@property(nonatomic, readonly) GACAppCheck *appCheckCore;

@end

@implementation FIRAppCheck

#pragma mark - Internal

- (nullable instancetype)initWithApp:(FIRApp *)app {
  // Set the App Check Core logging level to the current equivalent Firebase logging level.
  GACAppCheckLogger.logLevel = FIRGetGACAppCheckLogLevel();

  id<FIRAppCheckProviderFactory> providerFactory = [FIRAppCheck providerFactory];

  if (providerFactory == nil) {
    FIRLogError(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeProviderFactoryIsMissing,
                @"Cannot instantiate `FIRAppCheck` for app: %@ without a provider factory. "
                @"Please register a provider factory using "
                @"`AppCheck.setAppCheckProviderFactory(_ ,forAppName:)` method.",
                app.name);
    return nil;
  }

  id<FIRAppCheckProvider> appCheckProvider = [providerFactory createProviderWithApp:app];
  if (appCheckProvider == nil) {
    FIRLogError(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeProviderIsMissing,
                @"Cannot instantiate `FIRAppCheck` for app: %@ without an app check provider. "
                @"Please make sure the provider factory returns a valid app check provider.",
                app.name);
    return nil;
  }

  NSString *serviceName = [self serviceNameForApp:app];
  NSString *resourceName = [self resourceNameForApp:app];
  id<GACAppCheckProvider> appCheckCoreProvider =
      [[FIRInternalAppCheckProvider alloc] initWithAppCheckProvider:appCheckProvider];
  FIRAppCheckSettings *settings =
      [[FIRAppCheckSettings alloc] initWithApp:app
                                   userDefault:[GULUserDefaults standardUserDefaults]
                                    mainBundle:[NSBundle mainBundle]];

  GACAppCheck *appCheckCore = [[GACAppCheck alloc] initWithServiceName:serviceName
                                                          resourceName:resourceName
                                                      appCheckProvider:appCheckCoreProvider
                                                              settings:settings
                                                         tokenDelegate:self
                                                   keychainAccessGroup:app.options.appGroupID];

  return [self initWithAppName:app.name
                  appCheckCore:appCheckCore
              appCheckProvider:appCheckProvider
            notificationCenter:NSNotificationCenter.defaultCenter
                      settings:settings];
}

- (instancetype)initWithAppName:(NSString *)appName
                   appCheckCore:(GACAppCheck *)appCheckCore
               appCheckProvider:(id<FIRAppCheckProvider>)appCheckProvider
             notificationCenter:(NSNotificationCenter *)notificationCenter
                       settings:(FIRAppCheckSettings *)settings {
  self = [super init];
  if (self) {
    _appName = appName;
    _appCheckCore = appCheckCore;
    _notificationCenter = notificationCenter;
    _settings = settings;
  }
  return self;
}

#pragma mark - Public

+ (instancetype)appCheck {
  FIRApp *defaultApp = [FIRApp defaultApp];
  if (!defaultApp) {
    [NSException raise:FIRAppCheckErrorDomain
                format:@"The default FirebaseApp instance must be configured before the default"
                       @"AppCheck instance can be initialized. One way to ensure this is to "
                       @"call `FirebaseApp.configure()` in the App Delegate's "
                       @"`application(_:didFinishLaunchingWithOptions:)` (or the `@main` struct's "
                       @"initializer in SwiftUI)."];
  }
  return [self appCheckWithApp:defaultApp];
}

+ (nullable instancetype)appCheckWithApp:(FIRApp *)firebaseApp {
  id<FIRAppCheckInterop> appCheck = FIR_COMPONENT(FIRAppCheckInterop, firebaseApp.container);
  return (FIRAppCheck *)appCheck;
}

- (void)tokenForcingRefresh:(BOOL)forcingRefresh
                 completion:(void (^)(FIRAppCheckToken *_Nullable token,
                                      NSError *_Nullable error))handler {
  [self.appCheckCore
      tokenForcingRefresh:forcingRefresh
               completion:^(GACAppCheckTokenResult *result) {
                 if (result.error) {
                   handler(nil, [FIRAppCheckErrorUtil publicDomainErrorWithError:result.error]);
                   return;
                 }

                 handler([[FIRAppCheckToken alloc] initWithInternalToken:result.token], nil);
               }];
}

- (void)limitedUseTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable token,
                                                NSError *_Nullable error))handler {
  [self.appCheckCore limitedUseTokenWithCompletion:^(GACAppCheckTokenResult *result) {
    if (result.error) {
      handler(nil, [FIRAppCheckErrorUtil publicDomainErrorWithError:result.error]);
      return;
    }

    handler([[FIRAppCheckToken alloc] initWithInternalToken:result.token], nil);
  }];
}

+ (void)setAppCheckProviderFactory:(nullable id<FIRAppCheckProviderFactory>)factory {
  self.providerFactory = factory;
}

- (void)setIsTokenAutoRefreshEnabled:(BOOL)isTokenAutoRefreshEnabled {
  self.settings.isTokenAutoRefreshEnabled = isTokenAutoRefreshEnabled;
}

- (BOOL)isTokenAutoRefreshEnabled {
  return self.settings.isTokenAutoRefreshEnabled;
}

#pragma mark - App Check Provider Ingestion

+ (void)setProviderFactory:(nullable id<FIRAppCheckProviderFactory>)providerFactory {
  @synchronized(self) {
    _providerFactory = providerFactory;
  }
}

+ (nullable id<FIRAppCheckProviderFactory>)providerFactory {
  @synchronized(self) {
    return _providerFactory;
  }
}

#pragma mark - FIRAppCheckInterop

- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(FIRAppCheckTokenHandlerInterop)handler {
  [self.appCheckCore
      tokenForcingRefresh:forcingRefresh
               completion:^(GACAppCheckTokenResult *internalResult) {
                 FIRAppCheckToken *token =
                     [[FIRAppCheckToken alloc] initWithInternalToken:internalResult.token];
                 FIRAppCheckTokenResult *tokenResult =
                     [[FIRAppCheckTokenResult alloc] initWithToken:token.token
                                                             error:internalResult.error];

                 handler(tokenResult);
               }];
}

- (void)getLimitedUseTokenWithCompletion:(FIRAppCheckTokenHandlerInterop)handler {
  [self.appCheckCore limitedUseTokenWithCompletion:^(GACAppCheckTokenResult *internalResult) {
    FIRAppCheckToken *token = [[FIRAppCheckToken alloc] initWithInternalToken:internalResult.token];
    FIRAppCheckTokenResult *tokenResult =
        [[FIRAppCheckTokenResult alloc] initWithToken:token.token error:internalResult.error];

    handler(tokenResult);
  }];
}

- (nonnull NSString *)tokenDidChangeNotificationName {
  return FIRAppCheckAppCheckTokenDidChangeNotification;
}

- (nonnull NSString *)notificationAppNameKey {
  return kFIRAppCheckAppNameNotificationKey;
}

- (nonnull NSString *)notificationTokenKey {
  return kFIRAppCheckTokenNotificationKey;
}

#pragma mark - GACAppCheckTokenDelegate

- (void)tokenDidUpdate:(nonnull GACAppCheckToken *)token
           serviceName:(nonnull NSString *)serviceName {
  FIRAppCheckToken *appCheckToken = [[FIRAppCheckToken alloc] initWithInternalToken:token];
  [self postTokenUpdateNotificationWithToken:appCheckToken];
}

#pragma mark - Token update notification

- (void)postTokenUpdateNotificationWithToken:(FIRAppCheckToken *)token {
  [self.notificationCenter postNotificationName:FIRAppCheckAppCheckTokenDidChangeNotification
                                         object:self
                                       userInfo:@{
                                         kFIRAppCheckTokenNotificationKey : token.token,
                                         kFIRAppCheckAppNameNotificationKey : self.appName
                                       }];
}

#pragma mark - Helpers

- (NSString *)serviceNameForApp:(FIRApp *)app {
  return [NSString stringWithFormat:@"FirebaseApp:%@", app.name];
}

- (NSString *)resourceNameForApp:(FIRApp *)app {
  return [NSString
      stringWithFormat:@"projects/%@/apps/%@", app.options.projectID, app.options.googleAppID];
}

#pragma mark - Force Category Linking

extern void FIRInclude_FIRApp_AppCheck_Category(void);
extern void FIRInclude_FIRHeartbeatLogger_AppCheck_Category(void);

/// Does nothing when called, and not meant to be called.
///
/// This method forces the linker to include categories even if
/// users do not include the '-ObjC' linker flag in their project.
+ (void)noop {
  FIRInclude_FIRApp_AppCheck_Category();
  FIRInclude_FIRHeartbeatLogger_AppCheck_Category();
}

@end

NS_ASSUME_NONNULL_END
