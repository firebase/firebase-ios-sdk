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

#import "AppCheck/Sources/Public/AppCheck/GACAppCheck.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "AppCheck/Sources/Public/AppCheck/GACAppCheckErrors.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckProvider.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckProviderFactory.h"

#import "AppCheck/Sources/Core/Errors/GACAppCheckErrorUtil.h"
#import "AppCheck/Sources/Core/GACAppCheck+Internal.h"
#import "AppCheck/Sources/Core/GACAppCheckLogger.h"
#import "AppCheck/Sources/Core/GACAppCheckSettings.h"
#import "AppCheck/Sources/Core/GACAppCheckToken+Internal.h"
#import "AppCheck/Sources/Core/GACAppCheckTokenResult.h"
#import "AppCheck/Sources/Core/Storage/GACAppCheckStorage.h"
#import "AppCheck/Sources/Core/TokenRefresh/GACAppCheckTokenRefreshResult.h"
#import "AppCheck/Sources/Core/TokenRefresh/GACAppCheckTokenRefresher.h"

#import "AppCheck/Interop/GACAppCheckInterop.h"
#import "AppCheck/Interop/GACAppCheckTokenResultInterop.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

/// A notification with the specified name is sent to the default notification center
/// (`NotificationCenter.default`) each time a Firebase app check token is refreshed.
/// The user info dictionary contains `kGACAppCheckTokenNotificationKey` and
/// `kGACAppCheckAppNameNotificationKey` keys.
const NSNotificationName GACAppCheckAppCheckTokenDidChangeNotification =
    @"GACAppCheckAppCheckTokenDidChangeNotification";

/// `userInfo` key for the `AppCheckToken` in `appCheckTokenRefreshNotification`.
NSString *const kGACAppCheckTokenNotificationKey = @"GACAppCheckTokenNotificationKey";

/// `userInfo` key for the `FirebaseApp.name` in `appCheckTokenRefreshNotification`.
NSString *const kGACAppCheckAppNameNotificationKey = @"GACAppCheckAppNameNotificationKey";

// TODO(andrewheard): Remove from generic App Check SDK.
// FIREBASE_APP_CHECK_ONLY_BEGIN
NSString *const kGACAppCheckTokenAutoRefreshEnabledUserDefaultsPrefix =
    @"GACAppCheckTokenAutoRefreshEnabled_";
NSString *const kGACAppCheckTokenAutoRefreshEnabledInfoPlistKey =
    @"FirebaseAppCheckTokenAutoRefreshEnabled";
// FIREBASE_APP_CHECK_ONLY_END

static id<GACAppCheckProviderFactory> _providerFactory;

static const NSTimeInterval kTokenExpirationThreshold = 5 * 60;  // 5 min.

static NSString *const kDummyFACTokenValue = @"eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==";

@interface GACAppCheck () <GACAppCheckInterop>
@property(class, nullable) id<GACAppCheckProviderFactory> providerFactory;

@property(nonatomic, readonly) NSString *appName;
@property(nonatomic, readonly) id<GACAppCheckProvider> appCheckProvider;
@property(nonatomic, readonly) id<GACAppCheckStorageProtocol> storage;
@property(nonatomic, readonly) NSNotificationCenter *notificationCenter;
@property(nonatomic, readonly) id<GACAppCheckSettingsProtocol> settings;

@property(nonatomic, readonly, nullable) id<GACAppCheckTokenRefresherProtocol> tokenRefresher;

@property(nonatomic, nullable) FBLPromise<GACAppCheckToken *> *ongoingRetrieveOrRefreshTokenPromise;
@property(nonatomic, nullable) FBLPromise<GACAppCheckToken *> *ongoingLimitedUseTokenPromise;
@end

@implementation GACAppCheck

#pragma mark - Internal

- (nullable instancetype)initWithApp:(FIRApp *)app {
  id<GACAppCheckProviderFactory> providerFactory = [GACAppCheck providerFactory];

  if (providerFactory == nil) {
    GACLogError(kFIRLoggerAppCheckMessageCodeProviderFactoryIsMissing,
                @"Cannot instantiate `GACAppCheck` for app: %@ without a provider factory. "
                @"Please register a provider factory using "
                @"`AppCheck.setAppCheckProviderFactory(_ ,forAppName:)` method.",
                app.name);
    return nil;
  }

  id<GACAppCheckProvider> appCheckProvider = [providerFactory createProviderWithApp:app];
  if (appCheckProvider == nil) {
    GACLogError(kFIRLoggerAppCheckMessageCodeProviderIsMissing,
                @"Cannot instantiate `GACAppCheck` for app: %@ without an app check provider. "
                @"Please make sure the provider factory returns a valid app check provider.",
                app.name);
    return nil;
  }

  id<GACAppCheckSettingsProtocol> settings = [[GACAppCheckSettings alloc]
                       initWithUserDefaults:[NSUserDefaults standardUserDefaults]
                                 mainBundle:[NSBundle mainBundle]
      tokenAutoRefreshPolicyUserDefaultsKey:[kGACAppCheckTokenAutoRefreshEnabledUserDefaultsPrefix
                                                stringByAppendingString:app.name]
         tokenAutoRefreshPolicyInfoPListKey:kGACAppCheckTokenAutoRefreshEnabledInfoPlistKey];
  GACAppCheckTokenRefreshResult *refreshResult =
      [[GACAppCheckTokenRefreshResult alloc] initWithStatusNever];
  GACAppCheckTokenRefresher *tokenRefresher =
      [[GACAppCheckTokenRefresher alloc] initWithRefreshResult:refreshResult settings:settings];

  GACAppCheckStorage *storage = [[GACAppCheckStorage alloc] initWithAppName:app.name
                                                                      appID:app.options.googleAppID
                                                                accessGroup:app.options.appGroupID];

  return [self initWithAppName:app.name
              appCheckProvider:appCheckProvider
                       storage:storage
                tokenRefresher:tokenRefresher
            notificationCenter:NSNotificationCenter.defaultCenter
                      settings:settings];
}

- (instancetype)initWithAppName:(NSString *)appName
               appCheckProvider:(id<GACAppCheckProvider>)appCheckProvider
                        storage:(id<GACAppCheckStorageProtocol>)storage
                 tokenRefresher:(id<GACAppCheckTokenRefresherProtocol>)tokenRefresher
             notificationCenter:(NSNotificationCenter *)notificationCenter
                       settings:(id<GACAppCheckSettingsProtocol>)settings {
  self = [super init];
  if (self) {
    _appName = appName;
    _appCheckProvider = appCheckProvider;
    _storage = storage;
    _tokenRefresher = tokenRefresher;
    _notificationCenter = notificationCenter;
    _settings = settings;

    __auto_type __weak weakSelf = self;
    tokenRefresher.tokenRefreshHandler = ^(GACAppCheckTokenRefreshCompletion _Nonnull completion) {
      __auto_type strongSelf = weakSelf;
      [strongSelf periodicTokenRefreshWithCompletion:completion];
    };
  }
  return self;
}

#pragma mark - Public

+ (instancetype)appCheck {
  FIRApp *defaultApp = [FIRApp defaultApp];
  if (!defaultApp) {
    [NSException raise:GACAppCheckErrorDomain
                format:@"The default FirebaseApp instance must be configured before the default"
                       @"AppCheck instance can be initialized. One way to ensure this is to "
                       @"call `FirebaseApp.configure()` in the App Delegate's "
                       @"`application(_:didFinishLaunchingWithOptions:)` (or the `@main` struct's "
                       @"initializer in SwiftUI)."];
  }
  return [self appCheckWithApp:defaultApp];
}

+ (nullable instancetype)appCheckWithApp:(FIRApp *)firebaseApp {
  id<GACAppCheckInterop> appCheck = FIR_COMPONENT(GACAppCheckInterop, firebaseApp.container);
  return (GACAppCheck *)appCheck;
}

- (void)tokenForcingRefresh:(BOOL)forcingRefresh
                 completion:(void (^)(GACAppCheckToken *_Nullable token,
                                      NSError *_Nullable error))handler {
  [self retrieveOrRefreshTokenForcingRefresh:forcingRefresh]
      .then(^id _Nullable(GACAppCheckToken *token) {
        handler(token, nil);
        return token;
      })
      .catch(^(NSError *_Nonnull error) {
        handler(nil, [GACAppCheckErrorUtil publicDomainErrorWithError:error]);
      });
}

- (void)limitedUseTokenWithCompletion:(void (^)(GACAppCheckToken *_Nullable token,
                                                NSError *_Nullable error))handler {
  [self retrieveLimitedUseToken]
      .then(^id _Nullable(GACAppCheckToken *token) {
        handler(token, nil);
        return token;
      })
      .catch(^(NSError *_Nonnull error) {
        handler(nil, [GACAppCheckErrorUtil publicDomainErrorWithError:error]);
      });
}

+ (void)setAppCheckProviderFactory:(nullable id<GACAppCheckProviderFactory>)factory {
  self.providerFactory = factory;
}

- (void)setIsTokenAutoRefreshEnabled:(BOOL)isTokenAutoRefreshEnabled {
  self.settings.isTokenAutoRefreshEnabled = isTokenAutoRefreshEnabled;
}

- (BOOL)isTokenAutoRefreshEnabled {
  return self.settings.isTokenAutoRefreshEnabled;
}

#pragma mark - App Check Provider Ingestion

+ (void)setProviderFactory:(nullable id<GACAppCheckProviderFactory>)providerFactory {
  @synchronized(self) {
    _providerFactory = providerFactory;
  }
}

+ (nullable id<GACAppCheckProviderFactory>)providerFactory {
  @synchronized(self) {
    return _providerFactory;
  }
}

#pragma mark - GACAppCheckInterop

- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(GACAppCheckTokenHandlerInterop)handler {
  [self retrieveOrRefreshTokenForcingRefresh:forcingRefresh]
      .then(^id _Nullable(GACAppCheckToken *token) {
        GACAppCheckTokenResult *result = [[GACAppCheckTokenResult alloc] initWithToken:token.token
                                                                                 error:nil];
        handler(result);
        return result;
      })
      .catch(^(NSError *_Nonnull error) {
        GACAppCheckTokenResult *result =
            [[GACAppCheckTokenResult alloc] initWithToken:kDummyFACTokenValue error:error];
        handler(result);
      });
}

- (nonnull NSString *)tokenDidChangeNotificationName {
  return GACAppCheckAppCheckTokenDidChangeNotification;
}

- (nonnull NSString *)notificationAppNameKey {
  return kGACAppCheckAppNameNotificationKey;
}

- (nonnull NSString *)notificationTokenKey {
  return kGACAppCheckTokenNotificationKey;
}

#pragma mark - FAA token cache

- (FBLPromise<GACAppCheckToken *> *)retrieveOrRefreshTokenForcingRefresh:(BOOL)forcingRefresh {
  return [FBLPromise do:^id _Nullable {
    if (self.ongoingRetrieveOrRefreshTokenPromise == nil) {
      // Kick off a new operation only when there is not an ongoing one.
      self.ongoingRetrieveOrRefreshTokenPromise =
          [self createRetrieveOrRefreshTokenPromiseForcingRefresh:forcingRefresh]

              // Release the ongoing operation promise on completion.
              .then(^GACAppCheckToken *(GACAppCheckToken *token) {
                self.ongoingRetrieveOrRefreshTokenPromise = nil;
                return token;
              })
              .recover(^NSError *(NSError *error) {
                self.ongoingRetrieveOrRefreshTokenPromise = nil;
                return error;
              });
    }
    return self.ongoingRetrieveOrRefreshTokenPromise;
  }];
}

- (FBLPromise<GACAppCheckToken *> *)createRetrieveOrRefreshTokenPromiseForcingRefresh:
    (BOOL)forcingRefresh {
  return [self getCachedValidTokenForcingRefresh:forcingRefresh].recover(
      ^id _Nullable(NSError *_Nonnull error) {
        return [self refreshToken];
      });
}

- (FBLPromise<GACAppCheckToken *> *)getCachedValidTokenForcingRefresh:(BOOL)forcingRefresh {
  if (forcingRefresh) {
    FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
    [rejectedPromise reject:[GACAppCheckErrorUtil cachedTokenNotFound]];
    return rejectedPromise;
  }

  return [self.storage getToken].then(^id(GACAppCheckToken *_Nullable token) {
    if (token == nil) {
      return [GACAppCheckErrorUtil cachedTokenNotFound];
    }

    BOOL isTokenExpiredOrExpiresSoon =
        [token.expirationDate timeIntervalSinceNow] < kTokenExpirationThreshold;
    if (isTokenExpiredOrExpiresSoon) {
      return [GACAppCheckErrorUtil cachedTokenExpired];
    }

    return token;
  });
}

- (FBLPromise<GACAppCheckToken *> *)retrieveLimitedUseToken {
  return [FBLPromise do:^id _Nullable {
    if (self.ongoingLimitedUseTokenPromise == nil) {
      // Kick off a new operation only when there is not an ongoing one.
      self.ongoingLimitedUseTokenPromise =
          [self limitedUseToken]
              // Release the ongoing operation promise on completion.
              .then(^GACAppCheckToken *(GACAppCheckToken *token) {
                self.ongoingLimitedUseTokenPromise = nil;
                return token;
              })
              .recover(^NSError *(NSError *error) {
                self.ongoingLimitedUseTokenPromise = nil;
                return error;
              });
    }
    return self.ongoingLimitedUseTokenPromise;
  }];
}

- (FBLPromise<GACAppCheckToken *> *)refreshToken {
  return [FBLPromise
             wrapObjectOrErrorCompletion:^(FBLPromiseObjectOrErrorCompletion _Nonnull handler) {
               [self.appCheckProvider getTokenWithCompletion:handler];
             }]
      .then(^id _Nullable(GACAppCheckToken *_Nullable token) {
        return [self.storage setToken:token];
      })
      .then(^id _Nullable(GACAppCheckToken *_Nullable token) {
        // TODO: Make sure the self.tokenRefresher is updated only once. Currently the timer will be
        // updated twice in the case when the refresh triggered by self.tokenRefresher, but it
        // should be fine for now as it is a relatively cheap operation.
        __auto_type refreshResult = [[GACAppCheckTokenRefreshResult alloc]
            initWithStatusSuccessAndExpirationDate:token.expirationDate
                                    receivedAtDate:token.receivedAtDate];
        [self.tokenRefresher updateWithRefreshResult:refreshResult];
        [self postTokenUpdateNotificationWithToken:token];
        return token;
      });
}

- (FBLPromise<GACAppCheckToken *> *)limitedUseToken {
  return
      [FBLPromise wrapObjectOrErrorCompletion:^(
                      FBLPromiseObjectOrErrorCompletion _Nonnull handler) {
        [self.appCheckProvider getTokenWithCompletion:handler];
      }].then(^id _Nullable(GACAppCheckToken *_Nullable token) {
        return token;
      });
}

#pragma mark - Token auto refresh

- (void)periodicTokenRefreshWithCompletion:(GACAppCheckTokenRefreshCompletion)completion {
  [self retrieveOrRefreshTokenForcingRefresh:NO]
      .then(^id _Nullable(GACAppCheckToken *_Nullable token) {
        __auto_type refreshResult = [[GACAppCheckTokenRefreshResult alloc]
            initWithStatusSuccessAndExpirationDate:token.expirationDate
                                    receivedAtDate:token.receivedAtDate];
        completion(refreshResult);
        return nil;
      })
      .catch(^(NSError *error) {
        __auto_type refreshResult = [[GACAppCheckTokenRefreshResult alloc] initWithStatusFailure];
        completion(refreshResult);
      });
}

#pragma mark - Token update notification

- (void)postTokenUpdateNotificationWithToken:(GACAppCheckToken *)token {
  [self.notificationCenter postNotificationName:GACAppCheckAppCheckTokenDidChangeNotification
                                         object:self
                                       userInfo:@{
                                         kGACAppCheckTokenNotificationKey : token.token,
                                         kGACAppCheckAppNameNotificationKey : self.appName
                                       }];
}

@end

NS_ASSUME_NONNULL_END
