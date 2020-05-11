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

#import "FIRAppAttestation.h"

#import <FBLPromises/FBLPromises.h>

#import <FirebaseAppAttestation/FIRAppAttestationProvider.h>
#import <FirebaseAppAttestation/FIRAppAttestationProviderFactory.h>
#import <FirebaseAppAttestation/FIRAppAttestationToken.h>
#import <FirebaseAppAttestation/FIRAppAttestationVersion.h>

#import "FIRAppAttestErrorUtil.h"
#import "FIRAppAttestLogger.h"
#import "FIRAppAttestStorage.h"
#import "FIRAppAttestationToken+Interop.h"

#import <FirebaseAppAttestationInterop/FIRAppAttestationInterop.h>
#import <FirebaseAppAttestationInterop/FIRAppAttestationTokenInterop.h>

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIRLibrary.h>
#import <FirebaseCore/FIROptions.h>

NS_ASSUME_NONNULL_BEGIN

static const NSTimeInterval kTokenExpirationThreshold = 60 * 60;  // 1 hour.

@interface FIRAppAttestation () <FIRLibrary, FIRAppAttestationInterop>
@property(nonatomic, readonly) NSString *appName;
@property(nonatomic, readonly) id<FIRAppAttestationProvider> attestationProvider;
@property(nonatomic, readonly) id<FIRAppAttestStorageProtocol> storage;

@end

@implementation FIRAppAttestation

#pragma mark - FIRComponents

+ (void)load {
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self
                         withName:@"fire-app-attest"
                      withVersion:[NSString stringWithUTF8String:FIRAppAttestationVersionStr]];
}

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    *isCacheable = YES;
    return [[FIRAppAttestation alloc] initWithApp:container.app];
  };

  FIRComponent *appAttestationProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRAppAttestationInterop)
                      instantiationTiming:FIRInstantiationTimingLazy
                             dependencies:@[]
                            creationBlock:creationBlock];
  return @[ appAttestationProvider ];
}

- (nullable instancetype)initWithApp:(FIRApp *)app {
  self = [super init];
  if (self) {
    id<FIRAppAttestationProviderFactory> providerFactory =
        [[self class] providerFactoryForAppName:app.name]
            ?: [[self class] providerFactoryForAppName:kFIRDefaultAppName];

    if (providerFactory == nil) {
      FIRLogError(kFIRLoggerAppAttest, kFIRLoggerAppAttestMessageCodeUnknown,
                  @"Cannot instantiate `FIRAppAttestation` for app: %@ without a provider factory. "
                  @"Please register a provider factory using "
                  @"`AppAttestation.setAttestationProviderFactory(_ ,forAppName:)` method.",
                  app.name);
      return nil;
    }

    id<FIRAppAttestationProvider> attestationProvider = [providerFactory createProviderWithApp:app];
    if (attestationProvider == nil) {
      FIRLogError(
          kFIRLoggerAppAttest, kFIRLoggerAppAttestMessageCodeUnknown,
          @"Cannot instantiate `FIRAppAttestation` for app: %@ without an attestation provider. "
          @"Please make sure the provide factory returns a valid attestation provider.",
          app.name);
      return nil;
    }

    FIRAppAttestStorage *storage =
        [[FIRAppAttestStorage alloc] initWithAppName:app.name accessGroup:app.options.appGroupID];
    return [self initWithAppName:app.name attestationProvider:attestationProvider storage:storage];
  }
  return self;
}

- (instancetype)initWithAppName:(NSString *)appName
            attestationProvider:(id<FIRAppAttestationProvider>)attestationProvider
                        storage:(id<FIRAppAttestStorageProtocol>)storage {
  self = [super init];
  if (self) {
    _appName = appName;
    _attestationProvider = attestationProvider;
    _storage = storage;
  }
  return self;
}

#pragma mark - Public

+ (void)setAttestationProviderFactory:(nullable id<FIRAppAttestationProviderFactory>)factory {
  [self setAttestationProviderFactory:factory forAppName:kFIRDefaultAppName];
}

+ (void)setAttestationProviderFactory:(nullable id<FIRAppAttestationProviderFactory>)factory
                           forAppName:(NSString *)firebaseAppName {
  if (firebaseAppName == nil) {
    FIRLogError(kFIRLoggerAppAttest, kFIRLoggerAppAttestMessageCodeUnknown,
                @"App name must not be `nil`");
    return;
  }

  @synchronized([self providerFactoryByAppName]) {
    [self providerFactoryByAppName][firebaseAppName] = factory;
  }
}

#pragma mark - Attestation Provider Ingestion

+ (NSMutableDictionary<NSString *, id<FIRAppAttestationProviderFactory>> *)
    providerFactoryByAppName {
  static NSMutableDictionary<NSString *, id<FIRAppAttestationProviderFactory>>
      *providerFactoryByAppName;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    providerFactoryByAppName = [[NSMutableDictionary alloc] init];
  });
  return providerFactoryByAppName;
}

+ (nullable id<FIRAppAttestationProviderFactory>)providerFactoryForAppName:(NSString *)appName {
  if (appName == nil) {
    FIRLogError(kFIRLoggerAppAttest, kFIRLoggerAppAttestMessageCodeUnknown,
                @"App name must not be `nil`");
    return nil;
  }

  @synchronized([self providerFactoryByAppName]) {
    return [self providerFactoryByAppName][appName];
  }
}

#pragma mark - FIRAppAttestationInterop

- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(FIRAppAttestationTokenHandlerInterop)handler {
  [self getCachedValidTokenForcingRefresh:forcingRefresh]
      .recover(^id _Nullable(NSError *_Nonnull error) {
        return [self refreshToken];
      })
      .then(^id _Nullable(FIRAppAttestationToken *token) {
        handler(token, nil);
        return token;
      })
      .catch(^(NSError *_Nonnull error) {
        handler(nil, error);
      });
}

- (void)getTokenWithCompletion:(FIRAppAttestationTokenHandlerInterop)handler {
  [self getTokenForcingRefresh:NO completion:handler];
}

#pragma mark - FAA token cache

- (FBLPromise<FIRAppAttestationToken *> *)getCachedValidTokenForcingRefresh:(BOOL)forcingRefresh {
  if (forcingRefresh) {
    FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
    [rejectedPromise reject:[FIRAppAttestErrorUtil cachedTokenNotFound]];
    return rejectedPromise;
  }

  return [self.storage getToken].then(^id(FIRAppAttestationToken *_Nullable token) {
    if (token == nil) {
      return [FIRAppAttestErrorUtil cachedTokenNotFound];
    }

    BOOL isTokenExpiredOrExpiresSoon =
        [token.expirationDate timeIntervalSinceNow] < kTokenExpirationThreshold;
    if (isTokenExpiredOrExpiresSoon) {
      return [FIRAppAttestErrorUtil cachedTokenExpired];
    }

    return token;
  });
}

- (FBLPromise<FIRAppAttestationToken *> *)refreshToken {
  return
      [FBLPromise wrapObjectOrErrorCompletion:^(
                      FBLPromiseObjectOrErrorCompletion _Nonnull handler) {
        [self.attestationProvider getTokenWithCompletion:handler];
      }].then(^id _Nullable(FIRAppAttestationToken *_Nullable token) {
        return [self.storage setToken:token];
      });
}

@end

NS_ASSUME_NONNULL_END
