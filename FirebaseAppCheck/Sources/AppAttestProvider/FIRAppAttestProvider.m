/*
 * Copyright 2021 Google LLC
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

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppAttestProvider.h"

#import "FirebaseAppCheck/Sources/AppAttestProvider/DCAppAttestService+FIRAppAttestService.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FirebaseAppCheck/Sources/AppAttestProvider/API/FIRAppAttestAPIService.h"
#import "FirebaseAppCheck/Sources/AppAttestProvider/FIRAppAttestProviderState.h"
#import "FirebaseAppCheck/Sources/AppAttestProvider/FIRAppAttestService.h"
#import "FirebaseAppCheck/Sources/AppAttestProvider/Storage/FIRAppAttestArtifactStorage.h"
#import "FirebaseAppCheck/Sources/AppAttestProvider/Storage/FIRAppAttestKeyIDStorage.h"
#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"
#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

/// A data object that contains all key attest data required for FAC token exchange.
@interface FIRAppAttestKeyAttestationResult : NSObject

@property(nonatomic, readonly) NSString *keyID;
@property(nonatomic, readonly) NSData *challenge;
@property(nonatomic, readonly) NSData *attestation;

- (instancetype)initWithKeyID:(NSString *)keyID
                    challenge:(NSData *)challenge
                  attestation:(NSData *)attestation;

@end

@implementation FIRAppAttestKeyAttestationResult

- (instancetype)initWithKeyID:(NSString *)keyID
                    challenge:(NSData *)challenge
                  attestation:(NSData *)attestation {
  self = [super init];
  if (self) {
    _keyID = keyID;
    _challenge = challenge;
    _attestation = attestation;
  }
  return self;
}

@end

@interface FIRAppAttestProvider ()

@property(nonatomic, readonly) id<FIRAppAttestAPIServiceProtocol> APIService;
@property(nonatomic, readonly) id<FIRAppAttestService> appAttestService;
@property(nonatomic, readonly) id<FIRAppAttestKeyIDStorageProtocol> keyIDStorage;
@property(nonatomic, readonly) id<FIRAppAttestArtifactStorageProtocol> artifactStorage;

@property(nonatomic, readonly) dispatch_queue_t queue;

@end

@implementation FIRAppAttestProvider

- (instancetype)initWithAppAttestService:(id<FIRAppAttestService>)appAttestService
                              APIService:(id<FIRAppAttestAPIServiceProtocol>)APIService
                            keyIDStorage:(id<FIRAppAttestKeyIDStorageProtocol>)keyIDStorage
                         artifactStorage:(id<FIRAppAttestArtifactStorageProtocol>)artifactStorage {
  self = [super init];
  if (self) {
    _appAttestService = appAttestService;
    _APIService = APIService;
    _keyIDStorage = keyIDStorage;
    _artifactStorage = artifactStorage;
    _queue = dispatch_queue_create("com.firebase.FIRAppAttestProvider", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (nullable instancetype)initWithApp:(FIRApp *)app {
#if TARGET_OS_IOS
  NSURLSession *URLSession = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];

  FIRAppAttestKeyIDStorage *keyIDStorage =
      [[FIRAppAttestKeyIDStorage alloc] initWithAppName:app.name appID:app.options.googleAppID];

  FIRAppCheckAPIService *APIService =
      [[FIRAppCheckAPIService alloc] initWithURLSession:URLSession
                                                 APIKey:app.options.APIKey
                                              projectID:app.options.projectID
                                                  appID:app.options.googleAppID];

  FIRAppAttestAPIService *appAttestAPIService =
      [[FIRAppAttestAPIService alloc] initWithAPIService:APIService
                                               projectID:app.options.projectID
                                                   appID:app.options.googleAppID];

  FIRAppAttestArtifactStorage *artifactStorage = [[FIRAppAttestArtifactStorage alloc] init];

  return [self initWithAppAttestService:DCAppAttestService.sharedService
                             APIService:appAttestAPIService
                           keyIDStorage:keyIDStorage
                        artifactStorage:artifactStorage];
#else   // TARGET_OS_IOS
  return nil;
#endif  // TARGET_OS_IOS
}

#pragma mark - FIRAppCheckProvider

- (void)getTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable, NSError *_Nullable))handler {
  // 1. Check `DCAppAttestService.isSupported`.
  [self isAppAttestSupported]
      .thenOn(self.queue,
              ^FBLPromise<NSArray *> *(id result) {
                return [FBLPromise onQueue:self.queue
                                       all:@[
                                         // 2. Request random challenge.
                                         [self.APIService getRandomChallenge],
                                         // 3. Get App Attest key ID.
                                         [self getAppAttestKeyIDGenerateIfNeeded]
                                       ]];
              })
      .thenOn(self.queue,
              ^FBLPromise<FIRAppAttestKeyAttestationResult *> *(NSArray *challengeAndKeyID) {
                // 4. Attest the key.
                NSData *challenge = challengeAndKeyID.firstObject;
                NSString *keyID = challengeAndKeyID.lastObject;

                return [self attestKey:keyID challenge:challenge];
              })
      .thenOn(self.queue,
              ^FBLPromise<FIRAppCheckToken *> *(FIRAppAttestKeyAttestationResult *result) {
                // 5. Exchange the attestation to FAC token.
                return [self.APIService appCheckTokenWithAttestation:result.attestation
                                                               keyID:result.keyID
                                                           challenge:result.challenge];
              })
      // 6. Call the handler with the result.
      .then(^FBLPromise *(FIRAppCheckToken *token) {
        handler(token, nil);
        return nil;
      })
      .catch(^(NSError *error) {
        handler(nil, error);
      });
}

//- (FBLPromise<FIRAppCheckToken *> *)getToken {
//  // 1. Check attestation state to decide on the next steps.
////  return [self attestationState]
////  thenOn(self.queue, ^id());
//}

#pragma mark - Initial handshake sequence

- (FBLPromise<FIRAppCheckToken *> *)initialHandshake {
  return  // 1. Check `DCAppAttestService.isSupported`.
      [self isAppAttestSupported]
          .thenOn(self.queue,
                  ^FBLPromise<NSArray *> *(id result) {
                    return [FBLPromise onQueue:self.queue
                                           all:@[
                                             // 2. Request random challenge.
                                             [self.APIService getRandomChallenge],
                                             // 3. Get App Attest key ID.
                                             [self getAppAttestKeyIDGenerateIfNeeded]
                                           ]];
                  })
          .thenOn(self.queue,
                  ^FBLPromise<FIRAppAttestKeyAttestationResult *> *(NSArray *challengeAndKeyID) {
                    // 4. Attest the key.
                    NSData *challenge = challengeAndKeyID.firstObject;
                    NSString *keyID = challengeAndKeyID.lastObject;

                    return [self attestKey:keyID challenge:challenge];
                  })
          .thenOn(self.queue,
                  ^FBLPromise<FIRAppCheckToken *> *(FIRAppAttestKeyAttestationResult *result) {
                    // 5. Exchange the attestation to FAC token.
                    return [self.APIService appCheckTokenWithAttestation:result.attestation
                                                                   keyID:result.keyID
                                                               challenge:result.challenge];
                  });
}

#pragma mark - Token refresh sequence

- (FBLPromise<FIRAppCheckToken *> *)refreshTokenWithKeyID {
  return [FBLPromise resolvedWith:nil];
}

#pragma mark - Helpers

/// Calculates and returns current `FIRAppAttestAttestationState`.
/// @return A promise that is resolved with FIRAppAttestProviderState with the state and associated
/// data (e.g. key ID).
- (FBLPromise<FIRAppAttestProviderState *> *)attestationState {
  // Use a local variable to store App Attest key ID that may be fetched in the middle of the
  // pipeline but may needed later. It simplifies chaining a bit.
  __block NSString *appAttestKeyID;

  return
      // 1. Check if App Attest is supported.
      [self isAppAttestSupported]
          .recoverOn(self.queue,
                     ^FBLPromise<FIRAppAttestProviderState *> *(NSError *error) {
                       // App Attest is not supported.
                       __auto_type state =
                           [[FIRAppAttestProviderState alloc] initUnsupportedWithError:error];
                       return [FBLPromise resolvedWith:state];
                     })

          // 2. Check for stored key ID of the generated App Attest key pair.
          .thenOn(self.queue,
                  ^FBLPromise<NSString *> *(id result) {
                    return [self.keyIDStorage getAppAttestKeyID];
                  })
          .recoverOn(self.queue,
                     ^FBLPromise<FIRAppAttestProviderState *> *(NSError *error) {
                       // There is no a valid App Attest key pair generated.
                       __auto_type state =
                           [[FIRAppAttestProviderState alloc] initWithSupportedInitialState];
                       return [FBLPromise resolvedWith:state];
                     })

          // 3. Check for stored attestation artefact received from Firebase backend.
          .thenOn(self.queue,
                  ^FBLPromise<NSData *> *(NSString *keyID) {
                    // Save the key ID to be accessible in the recover block in the case when there
                    // is no artifact stored.
                    appAttestKeyID = keyID;
                    return [self.artifactStorage getArtifact];
                  })
          .recoverOn(self.queue,
                     ^FBLPromise<NSNumber *> *(NSError *error) {
                       // A valid App Attest key pair was generated but has not been registered with
                       // Firebase backend.
                       __auto_type state = [[FIRAppAttestProviderState alloc]
                           initWithGeneratedKeyID:appAttestKeyID];
                       return [FBLPromise resolvedWith:state];
                     })
          .thenOn(
              self.queue, ^FBLPromise<FIRAppAttestProviderState *> *(NSData *attestationArtifact) {
                // A valid App Attest key pair was generated and registered with Firebase backend.
                __auto_type state =
                    [[FIRAppAttestProviderState alloc] initWithRegisteredKeyID:appAttestKeyID
                                                                      artifact:attestationArtifact];
                return [FBLPromise resolvedWith:state];
              });
}

/// Returns a resolved promise if App Attest is supported and a rejected promise if it is not.
- (FBLPromise<NSNull *> *)isAppAttestSupported {
  if (self.appAttestService.isSupported) {
    return [FBLPromise resolvedWith:[NSNull null]];
  } else {
    NSError *error = [FIRAppCheckErrorUtil unsupportedAttestationProvider:@"AppAttestProvider"];
    FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
    [rejectedPromise reject:error];
    return rejectedPromise;
  }
}

/// Retrieves or generates App Attest key associated with the Firebase app.
- (FBLPromise<NSString *> *)getAppAttestKeyIDGenerateIfNeeded {
  return [self.keyIDStorage getAppAttestKeyID].recoverOn(self.queue,
                                                         ^FBLPromise<NSString *> *(NSError *error) {
                                                           return [self generateAppAttestKey];
                                                         });
}

/// Generates and stores App Attest key associated with the Firebase app.
- (FBLPromise<NSString *> *)generateAppAttestKey {
  return [FBLPromise onQueue:self.queue
             wrapObjectOrErrorCompletion:^(FBLPromiseObjectOrErrorCompletion _Nonnull handler) {
               [self.appAttestService generateKeyWithCompletionHandler:handler];
             }]
      .thenOn(self.queue, ^FBLPromise<NSString *> *(NSString *keyID) {
        return [self.keyIDStorage setAppAttestKeyID:keyID];
      });
}

- (FBLPromise<FIRAppAttestKeyAttestationResult *> *)attestKey:(NSString *)keyID
                                                    challenge:(NSData *)challenge {
  return [FBLPromise onQueue:self.queue
                          do:^id _Nullable {
                            return [challenge base64EncodedDataWithOptions:0];
                          }]
      .thenOn(
          self.queue,
          ^FBLPromise<NSData *> *(NSData *challengeHash) {
            return [FBLPromise onQueue:self.queue
                wrapObjectOrErrorCompletion:^(FBLPromiseObjectOrErrorCompletion _Nonnull handler) {
                  [self.appAttestService attestKey:keyID
                                    clientDataHash:challengeHash
                                 completionHandler:handler];
                }];
          })
      .thenOn(self.queue, ^FBLPromise<FIRAppAttestKeyAttestationResult *> *(NSData *attestation) {
        FIRAppAttestKeyAttestationResult *result =
            [[FIRAppAttestKeyAttestationResult alloc] initWithKeyID:keyID
                                                          challenge:challenge
                                                        attestation:attestation];
        return [FBLPromise resolvedWith:result];
      });
}

@end

NS_ASSUME_NONNULL_END
