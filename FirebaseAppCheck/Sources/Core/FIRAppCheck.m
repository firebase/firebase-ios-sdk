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

#import <AppCheck/AppCheck.h>

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckErrors.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProvider.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProviderFactory.h"

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Core/FIRApp+AppCheck.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheck+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckSettings.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckTokenResult.h"
#import "FirebaseAppCheck/Sources/Core/FIRInternalAppCheckProvider.h"

#import "FirebaseAppCheck/Interop/FIRAppCheckInterop.h"
#import "FirebaseAppCheck/Interop/FIRAppCheckTokenResultInterop.h"

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

static NSString *const kDummyFACTokenValue = @"eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==";

@interface FIRAppCheck () <GACAppCheckTokenDelegate, FIRAppCheckInterop>
@property(class, nullable) id<FIRAppCheckProviderFactory> providerFactory;

@property(nonatomic, readonly) NSString *appName;
@property(nonatomic, readonly) GACAppCheck *internalAppCheck;
@property(nonatomic, readonly) NSNotificationCenter *notificationCenter;
@property(nonatomic, readonly) id<GACAppCheckSettingsProtocol, FIRAppCheckSettingsProtocol>
    settings;

@end

@implementation FIRAppCheck

#pragma mark - Internal

- (nullable instancetype)initWithApp:(FIRApp *)app {
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

  id<GACAppCheckProvider> internalAppCheckProvider =
      [[FIRInternalAppCheckProvider alloc] initWithAppCheckProvider:appCheckProvider];

  id<GACAppCheckSettingsProtocol, FIRAppCheckSettingsProtocol> settings =
      [[FIRAppCheckSettings alloc] initWithApp:app
                                   userDefault:[NSUserDefaults standardUserDefaults]
                                    mainBundle:[NSBundle mainBundle]];

  return [self initWithAppName:app.name
              appCheckProvider:internalAppCheckProvider
            notificationCenter:[NSNotificationCenter defaultCenter]
                      settings:settings
                  resourceName:app.resourceName
                    appGroupID:app.options.appGroupID];
}

- (instancetype)initWithAppName:(NSString *)appName
               appCheckProvider:(id<GACAppCheckProvider>)appCheckProvider
             notificationCenter:(NSNotificationCenter *)notificationCenter
                       settings:
                           (id<GACAppCheckSettingsProtocol, FIRAppCheckSettingsProtocol>)settings
                   resourceName:(NSString *)resourceName
                     appGroupID:(NSString *)appGroupID {
  self = [super init];
  if (self) {
    _appName = appName;
    _notificationCenter = notificationCenter;
    _settings = settings;
    _internalAppCheck = [[GACAppCheck alloc] initWithInstanceName:appName
                                                 appCheckProvider:appCheckProvider
                                                         settings:settings
                                                     resourceName:resourceName
                                              keychainAccessGroup:appGroupID];

    _internalAppCheck.tokenDelegate = self;
    //
    //    [_internalNotificationCenter addObserver:self
    //                           selector:@selector(tokenUpdateNotification:)
    //                               name:GACAppCheckAppCheckTokenDidChangeNotification
    //                             object:nil];
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
  [self.internalAppCheck
      tokenForcingRefresh:forcingRefresh
               completion:^(GACAppCheckToken *_Nullable internalToken, NSError *_Nullable error) {
                 if (error) {
                   handler(nil, [FIRAppCheckErrorUtil publicDomainErrorWithError:error]);
                   return;
                 }

                 handler([[FIRAppCheckToken alloc] initWithInternalToken:internalToken], nil);
               }];
}

- (void)limitedUseTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable token,
                                                NSError *_Nullable error))handler {
  [self.internalAppCheck limitedUseTokenWithCompletion:^(GACAppCheckToken *_Nullable internalToken,
                                                         NSError *_Nullable error) {
    if (error) {
      handler(nil, [FIRAppCheckErrorUtil publicDomainErrorWithError:error]);
      return;
    }

    handler([[FIRAppCheckToken alloc] initWithInternalToken:internalToken], nil);
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
  [self.internalAppCheck
      tokenForcingRefresh:forcingRefresh
               completion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 FIRAppCheckTokenResult *tokenResult;
                 if (token) {
                   tokenResult = [[FIRAppCheckTokenResult alloc] initWithToken:token.token
                                                                         error:nil];
                 } else {
                   tokenResult = [[FIRAppCheckTokenResult alloc] initWithToken:kDummyFACTokenValue
                                                                         error:error];
                 }

                 handler(tokenResult);
               }];
}

- (void)getLimitedUseTokenWithCompletion:(FIRAppCheckTokenHandlerInterop)handler {
  [self.internalAppCheck
      limitedUseTokenWithCompletion:^(GACAppCheckToken *_Nullable token, NSError *_Nullable error) {
        FIRAppCheckTokenResult *tokenResult;
        if (token) {
          tokenResult = [[FIRAppCheckTokenResult alloc] initWithToken:token.token error:nil];
        } else {
          tokenResult = [[FIRAppCheckTokenResult alloc] initWithToken:token.token error:error];
        }

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

- (void)didUpdateWithToken:(NSString *)token {
  [self.notificationCenter postNotificationName:FIRAppCheckAppCheckTokenDidChangeNotification
                                         object:self
                                       userInfo:@{
                                         kFIRAppCheckTokenNotificationKey : token,
                                         kFIRAppCheckAppNameNotificationKey : self.appName
                                       }];
}

@end

NS_ASSUME_NONNULL_END
