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

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckErrors.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProvider.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProviderFactory.h"

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckSettings.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckTokenResult.h"
#import "FirebaseAppCheck/Sources/Core/Storage/FIRAppCheckStorage.h"
#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTokenRefreshResult.h"
#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTokenRefresher.h"

#import "FirebaseAppCheck/Interop/FIRAppCheckInterop.h"
#import "FirebaseAppCheck/Interop/FIRAppCheckTokenResultInterop.h"

#import "FirebaseCore/Internal/FirebaseCoreInternal.h"

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

static const NSTimeInterval kTokenExpirationThreshold = 5 * 60;  // 5 min.

static NSString *const kDummyFACTokenValue = @"eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==";

@interface FIRAppCheck () <FIRLibrary, FIRAppCheckInterop>
@property(class, nullable) id<FIRAppCheckProviderFactory> providerFactory;

@property(nonatomic, readonly) NSString *appName;
@property(nonatomic, readonly) id<FIRAppCheckProvider> appCheckProvider;
@property(nonatomic, readonly) id<FIRAppCheckStorageProtocol> storage;
@property(nonatomic, readonly) NSNotificationCenter *notificationCenter;
@property(nonatomic, readonly) id<FIRAppCheckSettingsProtocol> settings;

@property(nonatomic, readonly, nullable) id<FIRAppCheckTokenRefresherProtocol> tokenRefresher;

@property(nonatomic, nullable) FBLPromise<FIRAppCheckToken *> *ongoingRetrieveOrRefreshTokenPromise;

@end

@implementation FIRAppCheck

#pragma mark - FIRComponents

+ (void)load {
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self withName:@"fire-app-check"];
}

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    *isCacheable = YES;
    return [[FIRAppCheck alloc] initWithApp:container.app];
  };

  // Use eager instantiation timing to give a chance for FAC token to be requested before it is
  // actually needed to avoid extra delaying dependent requests.
  FIRComponent *appCheckProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRAppCheckInterop)
                      instantiationTiming:FIRInstantiationTimingAlwaysEager
                             dependencies:@[]
                            creationBlock:creationBlock];
  return @[ appCheckProvider ];
}

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
                @"Please make sure the provide factory returns a valid app check provider.",
                app.name);
    return nil;
  }

  FIRAppCheckSettings *settings =
      [[FIRAppCheckSettings alloc] initWithApp:app
                                   userDefault:[NSUserDefaults standardUserDefaults]
                                    mainBundle:[NSBundle mainBundle]];
  FIRAppCheckTokenRefreshResult *refreshResult =
      [[FIRAppCheckTokenRefreshResult alloc] initWithStatusNever];
  FIRAppCheckTokenRefresher *tokenRefresher =
      [[FIRAppCheckTokenRefresher alloc] initWithRefreshResult:refreshResult settings:settings];

  FIRAppCheckStorage *storage = [[FIRAppCheckStorage alloc] initWithAppName:app.name
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
               appCheckProvider:(id<FIRAppCheckProvider>)appCheckProvider
                        storage:(id<FIRAppCheckStorageProtocol>)storage
                 tokenRefresher:(id<FIRAppCheckTokenRefresherProtocol>)tokenRefresher
             notificationCenter:(NSNotificationCenter *)notificationCenter
                       settings:(id<FIRAppCheckSettingsProtocol>)settings {
  self = [super init];
  if (self) {
    _appName = appName;
    _appCheckProvider = appCheckProvider;
    _storage = storage;
    _tokenRefresher = tokenRefresher;
    _notificationCenter = notificationCenter;
    _settings = settings;

    __auto_type __weak weakSelf = self;
    tokenRefresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
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
  [self retrieveOrRefreshTokenForcingRefresh:forcingRefresh]
      .then(^id _Nullable(FIRAppCheckToken *token) {
        handler(token, nil);
        return token;
      })
      .catch(^(NSError *_Nonnull error) {
        handler(nil, [FIRAppCheckErrorUtil publicDomainErrorWithError:error]);
      });
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
  [self retrieveOrRefreshTokenForcingRefresh:forcingRefresh]
      .then(^id _Nullable(FIRAppCheckToken *token) {
        FIRAppCheckTokenResult *result = [[FIRAppCheckTokenResult alloc] initWithToken:token.token
                                                                                 error:nil];
        handler(result);
        return result;
      })
      .catch(^(NSError *_Nonnull error) {
        FIRAppCheckTokenResult *result =
            [[FIRAppCheckTokenResult alloc] initWithToken:kDummyFACTokenValue error:error];
        handler(result);
      });
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

#pragma mark - FAA token cache

- (FBLPromise<FIRAppCheckToken *> *)retrieveOrRefreshTokenForcingRefresh:(BOOL)forcingRefresh {
  return [FBLPromise do:^id _Nullable {
    if (self.ongoingRetrieveOrRefreshTokenPromise == nil) {
      // Kick off a new operation only when there is not an ongoing one.
      self.ongoingRetrieveOrRefreshTokenPromise =
          [self createRetrieveOrRefreshTokenPromiseForcingRefresh:forcingRefresh]

              // Release the ongoing operation promise on completion.
              .then(^FIRAppCheckToken *(FIRAppCheckToken *token) {
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

- (FBLPromise<FIRAppCheckToken *> *)createRetrieveOrRefreshTokenPromiseForcingRefresh:
    (BOOL)forcingRefresh {
  return [self getCachedValidTokenForcingRefresh:forcingRefresh].recover(
      ^id _Nullable(NSError *_Nonnull error) {
        return [self refreshToken];
      });
}

- (FBLPromise<FIRAppCheckToken *> *)getCachedValidTokenForcingRefresh:(BOOL)forcingRefresh {
  if (forcingRefresh) {
    FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
    [rejectedPromise reject:[FIRAppCheckErrorUtil cachedTokenNotFound]];
    return rejectedPromise;
  }

  return [self.storage getToken].then(^id(FIRAppCheckToken *_Nullable token) {
    if (token == nil) {
      return [FIRAppCheckErrorUtil cachedTokenNotFound];
    }

    BOOL isTokenExpiredOrExpiresSoon =
        [token.expirationDate timeIntervalSinceNow] < kTokenExpirationThreshold;
    if (isTokenExpiredOrExpiresSoon) {
      return [FIRAppCheckErrorUtil cachedTokenExpired];
    }

    return token;
  });
}

- (FBLPromise<FIRAppCheckToken *> *)refreshToken {
  return [FBLPromise
             wrapObjectOrErrorCompletion:^(FBLPromiseObjectOrErrorCompletion _Nonnull handler) {
               [self.appCheckProvider getTokenWithCompletion:handler];
             }]
      .then(^id _Nullable(FIRAppCheckToken *_Nullable token) {
        return [self.storage setToken:token];
      })
      .then(^id _Nullable(FIRAppCheckToken *_Nullable token) {
        // TODO: Make sure the self.tokenRefresher is updated only once. Currently the timer will be
        // updated twice in the case when the refresh triggered by self.tokenRefresher, but it
        // should be fine for now as it is a relatively cheap operation.
        __auto_type refreshResult = [[FIRAppCheckTokenRefreshResult alloc]
            initWithStatusSuccessAndExpirationDate:token.expirationDate
                                    receivedAtDate:token.receivedAtDate];
        [self.tokenRefresher updateWithRefreshResult:refreshResult];
        [self postTokenUpdateNotificationWithToken:token];
        return token;
      });
}

#pragma mark - Token auto refresh

- (void)periodicTokenRefreshWithCompletion:(FIRAppCheckTokenRefreshCompletion)completion {
  [self retrieveOrRefreshTokenForcingRefresh:NO]
      .then(^id _Nullable(FIRAppCheckToken *_Nullable token) {
        __auto_type refreshResult = [[FIRAppCheckTokenRefreshResult alloc]
            initWithStatusSuccessAndExpirationDate:token.expirationDate
                                    receivedAtDate:token.receivedAtDate];
        completion(refreshResult);
        return nil;
      })
      .catch(^(NSError *error) {
        __auto_type refreshResult = [[FIRAppCheckTokenRefreshResult alloc] initWithStatusFailure];
        completion(refreshResult);
      });
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

@end

NS_ASSUME_NONNULL_END
