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

#import <FBLPromises/FBLPromises.h>

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProvider.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProviderFactory.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckToken.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckVersion.h"

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckTokenResult.h"
#import "FirebaseAppCheck/Sources/Core/Storage/FIRAppCheckStorage.h"

#import "FirebaseAppCheck/Sources/Interop/FIRAppCheckInterop.h"
#import "FirebaseAppCheck/Sources/Interop/FIRAppCheckTokenResultInterop.h"

NS_ASSUME_NONNULL_BEGIN

static id<FIRAppCheckProviderFactory> _providerFactory;

static const NSTimeInterval kTokenExpirationThreshold = 5 * 60;  // 5 min.

static NSString *const kDummyFACTokenValue = @"eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==";

@interface FIRAppCheck () <FIRLibrary, FIRAppCheckInterop>
@property(class, nullable) id<FIRAppCheckProviderFactory> providerFactory;

@property(nonatomic, readonly) NSString *appName;
@property(nonatomic, readonly) id<FIRAppCheckProvider> appCheckProvider;
@property(nonatomic, readonly) id<FIRAppCheckStorageProtocol> storage;

@end

@implementation FIRAppCheck

#pragma mark - FIRComponents

+ (void)load {
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self
                         withName:@"fire-app-check"
                      withVersion:[NSString stringWithUTF8String:FIRAppCheckVersionStr]];
}

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    *isCacheable = YES;
    return [[FIRAppCheck alloc] initWithApp:container.app];
  };

  FIRComponent *appCheckProvider = [FIRComponent componentWithProtocol:@protocol(FIRAppCheckInterop)
                                                   instantiationTiming:FIRInstantiationTimingLazy
                                                          dependencies:@[]
                                                         creationBlock:creationBlock];
  return @[ appCheckProvider ];
}

- (nullable instancetype)initWithApp:(FIRApp *)app {
  self = [super init];
  if (self) {
    id<FIRAppCheckProviderFactory> providerFactory = [[self class] providerFactory];

    if (providerFactory == nil) {
      FIRLogError(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeUnknown,
                  @"Cannot instantiate `FIRAppCheck` for app: %@ without a provider factory. "
                  @"Please register a provider factory using "
                  @"`AppCheck.setAppCheckProviderFactory(_ ,forAppName:)` method.",
                  app.name);
      return nil;
    }

    id<FIRAppCheckProvider> appCheckProvider = [providerFactory createProviderWithApp:app];
    if (appCheckProvider == nil) {
      FIRLogError(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeUnknown,
                  @"Cannot instantiate `FIRAppCheck` for app: %@ without an app check provider. "
                  @"Please make sure the provide factory returns a valid app check provider.",
                  app.name);
      return nil;
    }

    FIRAppCheckStorage *storage =
        [[FIRAppCheckStorage alloc] initWithAppName:app.name accessGroup:app.options.appGroupID];
    return [self initWithAppName:app.name appCheckProvider:appCheckProvider storage:storage];
  }
  return self;
}

- (instancetype)initWithAppName:(NSString *)appName
               appCheckProvider:(id<FIRAppCheckProvider>)appCheckProvider
                        storage:(id<FIRAppCheckStorageProtocol>)storage {
  self = [super init];
  if (self) {
    _appName = appName;
    _appCheckProvider = appCheckProvider;
    _storage = storage;
  }
  return self;
}

#pragma mark - Public

+ (void)setAppCheckProviderFactory:(nullable id<FIRAppCheckProviderFactory>)factory {
  self.providerFactory = factory;
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
  [self getCachedValidTokenForcingRefresh:forcingRefresh]
      .recover(^id _Nullable(NSError *_Nonnull error) {
        return [self refreshToken];
      })
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

#pragma mark - FAA token cache

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
  return
      [FBLPromise wrapObjectOrErrorCompletion:^(
                      FBLPromiseObjectOrErrorCompletion _Nonnull handler) {
        [self.appCheckProvider getTokenWithCompletion:handler];
      }].then(^id _Nullable(FIRAppCheckToken *_Nullable token) {
        return [self.storage setToken:token];
      });
}

@end

NS_ASSUME_NONNULL_END
