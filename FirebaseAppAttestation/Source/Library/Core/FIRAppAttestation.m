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

#import <FirebaseAppAttestation/FIRAppAttestationProvider.h>
#import <FirebaseAppAttestation/FIRAppAttestationProviderFactory.h>
#import <FirebaseAppAttestation/FIRAppAttestationToken.h>
#import <FirebaseAppAttestation/FIRAppAttestationVersion.h>

#import "FIRAppAttestationToken+Interop.h"

#import <FirebaseAppAttestationInterop/FIRAppAttestationInterop.h>
#import <FirebaseAppAttestationInterop/FIRAppAttestationTokenInterop.h>

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIRLibrary.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRAppAttestation () <FIRLibrary, FIRAppAttestationInterop>
@property(nonatomic, readonly) NSString *appName;
@property(nonatomic, readonly, nullable) id<FIRAppAttestationProvider> attestationProvider;
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

// TODO: Consider removing the initializer and move the provider fetching to the client code.
- (nullable instancetype)initWithApp:(FIRApp *)app {
  self = [super init];
  if (self) {
    id<FIRAppAttestationProviderFactory> providerFactory =
        [[self class] providerFactoryForAppName:app.name]
            ?: [[self class] providerFactoryForAppName:kFIRDefaultAppName];

    if (providerFactory == nil) {
      return nil;
    }

    id<FIRAppAttestationProvider> attestationProvider = [providerFactory createProviderWithApp:app];
    if (attestationProvider == nil) {
      return nil;
    }

    return [self initWithApp:app attestationProvider:attestationProvider];
  }
  return self;
}

- (instancetype)initWithApp:(FIRApp *)app
        attestationProvider:(id<FIRAppAttestationProvider>)attestationProvider {
  self = [super init];
  if (self) {
    _appName = app.name;
    _attestationProvider = attestationProvider;
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
    // TODO: Consider logging a message.
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
    return nil;
  }

  @synchronized([self providerFactoryByAppName]) {
    return [self providerFactoryByAppName][appName];
  }
}

#pragma mark - FIRAppAttestationInterop

- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(FIRAppAttestationTokenHandlerInterop)handler {
  if (self.attestationProvider == nil) {
    // TODO: finish with a specific error.
    handler(nil, nil);
    return;
  }

  [self.attestationProvider getTokenWithCompletion:handler];
}

- (void)getTokenWithCompletion:(FIRAppAttestationTokenHandlerInterop)handler {
  [self getTokenForcingRefresh:NO completion:handler];
}

@end

NS_ASSUME_NONNULL_END
