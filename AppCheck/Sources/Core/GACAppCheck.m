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

#import <AppCheckInterop/AppCheckInterop.h>

#import "AppCheck/Sources/Public/AppCheck/GACAppCheckErrors.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckProvider.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckSettings.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckToken.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckTokenDelegate.h"

#import "AppCheck/Sources/Core/Errors/GACAppCheckErrorUtil.h"
#import "AppCheck/Sources/Core/GACAppCheckLogger.h"
#import "AppCheck/Sources/Core/Storage/GACAppCheckStorage.h"
#import "AppCheck/Sources/Core/TokenRefresh/GACAppCheckTokenRefreshResult.h"
#import "AppCheck/Sources/Core/TokenRefresh/GACAppCheckTokenRefresher.h"

NS_ASSUME_NONNULL_BEGIN

// TODO(andrewheard): Remove from generic App Check SDK.
// FIREBASE_APP_CHECK_ONLY_BEGIN
static NSString *const kGACAppCheckTokenAutoRefreshEnabledUserDefaultsPrefix =
    @"GACAppCheckTokenAutoRefreshEnabled_";
static NSString *const kGACAppCheckTokenAutoRefreshEnabledInfoPlistKey =
    @"FirebaseAppCheckTokenAutoRefreshEnabled";
// FIREBASE_APP_CHECK_ONLY_END

static const NSTimeInterval kTokenExpirationThreshold = 5 * 60;  // 5 min.

static NSString *const kDummyFACTokenValue = @"eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==";

@interface GACAppCheck ()

@property(nonatomic, readonly) NSString *instanceName;
@property(nonatomic, readonly) id<GACAppCheckProvider> appCheckProvider;
@property(nonatomic, readonly) id<GACAppCheckStorageProtocol> storage;
@property(nonatomic, readonly) id<GACAppCheckSettingsProtocol> settings;
@property(nonatomic, readonly, weak) id<GACAppCheckTokenDelegate> tokenDelegate;

@property(nonatomic, readonly, nullable) id<GACAppCheckTokenRefresherProtocol> tokenRefresher;

@property(nonatomic, nullable) FBLPromise<GACAppCheckToken *> *ongoingRetrieveOrRefreshTokenPromise;

@end

@implementation GACAppCheck

#pragma mark - Internal

- (instancetype)initWithInstanceName:(NSString *)instanceName
                    appCheckProvider:(id<GACAppCheckProvider>)appCheckProvider
                             storage:(id<GACAppCheckStorageProtocol>)storage
                      tokenRefresher:(id<GACAppCheckTokenRefresherProtocol>)tokenRefresher
                            settings:(id<GACAppCheckSettingsProtocol>)settings
                       tokenDelegate:(id<GACAppCheckTokenDelegate>)tokenDelegate {
  self = [super init];
  if (self) {
    _instanceName = instanceName;
    _appCheckProvider = appCheckProvider;
    _storage = storage;
    _tokenRefresher = tokenRefresher;
    _settings = settings;
    _tokenDelegate = tokenDelegate;

    __auto_type __weak weakSelf = self;
    tokenRefresher.tokenRefreshHandler = ^(GACAppCheckTokenRefreshCompletion _Nonnull completion) {
      __auto_type strongSelf = weakSelf;
      [strongSelf periodicTokenRefreshWithCompletion:completion];
    };
  }
  return self;
}

#pragma mark - Public

- (instancetype)initWithInstanceName:(NSString *)instanceName
                    appCheckProvider:(id<GACAppCheckProvider>)appCheckProvider
                            settings:(id<GACAppCheckSettingsProtocol>)settings
                       tokenDelegate:(id<GACAppCheckTokenDelegate>)tokenDelegate
                        resourceName:(NSString *)resourceName
                 keychainAccessGroup:(nullable NSString *)accessGroup {
  GACAppCheckTokenRefreshResult *refreshResult =
      [[GACAppCheckTokenRefreshResult alloc] initWithStatusNever];
  GACAppCheckTokenRefresher *tokenRefresher =
      [[GACAppCheckTokenRefresher alloc] initWithRefreshResult:refreshResult settings:settings];

  NSString *tokenKey =
      [NSString stringWithFormat:@"app_check_token.%@.%@", instanceName, resourceName];
  GACAppCheckStorage *storage = [[GACAppCheckStorage alloc] initWithTokenKey:tokenKey
                                                                 accessGroup:accessGroup];

  return [self initWithInstanceName:instanceName
                   appCheckProvider:appCheckProvider
                            storage:storage
                     tokenRefresher:tokenRefresher
                           settings:settings
                      tokenDelegate:tokenDelegate];
}

#pragma mark - GACAppCheckInterop

- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(GACAppCheckTokenHandlerInterop)handler {
  [self retrieveOrRefreshTokenForcingRefresh:forcingRefresh]
      .then(^id _Nullable(GACAppCheckToken *token) {
        handler(token, nil);
        return token;
      })
      .catch(^(NSError *_Nonnull error) {
        handler(nil, error);
      });
}

- (void)getLimitedUseTokenWithCompletion:(GACAppCheckTokenHandlerInterop)handler {
  [self limitedUseToken]
      .then(^id _Nullable(GACAppCheckToken *token) {
        handler(token, nil);
        return token;
      })
      .catch(^(NSError *_Nonnull error) {
        handler(nil, error);
      });
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
        [self.tokenDelegate tokenDidUpdate:token instanceName:self.instanceName];
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

@end

NS_ASSUME_NONNULL_END
