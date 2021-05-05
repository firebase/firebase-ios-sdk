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
#import "FirebaseAppCheck/Sources/AppAttestProvider/API/FIRAppAttestInitialHandshakeResponse.h"
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

  FIRAppAttestArtifactStorage *artifactStorage =
      [[FIRAppAttestArtifactStorage alloc] initWithAppName:app.name
                                                     appID:app.options.googleAppID
                                               accessGroup:app.options.appGroupID];

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
  [self getToken]
      // Call the handler with the result.
      .then(^FBLPromise *(FIRAppCheckToken *token) {
        handler(token, nil);
        return nil;
      })
      .catch(^(NSError *error) {
        handler(nil, error);
      });
}

- (FBLPromise<FIRAppCheckToken *> *)getToken {
  // Check attestation state to decide on the next steps.
  return [self attestationState].thenOn(self.queue, ^id(FIRAppAttestProviderState *attestState) {
    switch (attestState.state) {
      case FIRAppAttestAttestationStateUnsupported:
        return attestState.appAttestUnsupportedError;
        break;

      case FIRAppAttestAttestationStateSupportedInitial:
      case FIRAppAttestAttestationStateKeyGenerated:
        // Initial handshake is required for both the "initial" and the "key generated" states.
        return [self initialHandshakeWithKeyID:attestState.appAttestKeyID];
        break;

      case FIRAppAttestAttestationStateKeyRegistered:
        // Refresh FAC token using the existing registerred App Attest key pair.
        return [self refreshTokenWithKeyID:attestState.appAttestKeyID
                                  artifact:attestState.attestationArtifact];
        break;
    }
  });
}

#pragma mark - Initial handshake sequence

- (FBLPromise<FIRAppCheckToken *> *)initialHandshakeWithKeyID:(nullable NSString *)keyID {
  // 1. Request a random challenge and get App Attest key ID concurrently.
  return [FBLPromise onQueue:self.queue
                         all:@[
                           // 1.1. Request random challenge.
                           [self.APIService getRandomChallenge],
                           // 1.2. Get App Attest key ID.
                           [self generateAppAttestKeyIDIfNeeded:keyID]
                         ]]
      .thenOn(self.queue,
              ^FBLPromise<FIRAppAttestKeyAttestationResult *> *(NSArray *challengeAndKeyID) {
                // 2. Attest the key.
                NSData *challenge = challengeAndKeyID.firstObject;
                NSString *keyID = challengeAndKeyID.lastObject;

                return [self attestKey:keyID challenge:challenge];
              })
      // TODO: Handle a possible key rejection - generate another key.
      .thenOn(self.queue,
              ^FBLPromise<FIRAppAttestInitialHandshakeResponse *> *(
                  FIRAppAttestKeyAttestationResult *result) {
                // 3. Exchange the attestation to FAC token.
                return [self.APIService attestKeyWithAttestation:result.attestation
                                                           keyID:result.keyID
                                                       challenge:result.challenge];
              })
      .thenOn(self.queue,
              ^FBLPromise<FIRAppCheckToken *> *(FIRAppAttestInitialHandshakeResponse *response) {
                // 4. Save the artifact and return the received FAC token.
                return [self saveArtifactAndGetAppCheckTokenFromResponse:response];
              });
}

- (FBLPromise<FIRAppCheckToken *> *)saveArtifactAndGetAppCheckTokenFromResponse:
    (FIRAppAttestInitialHandshakeResponse *)response {
  return [self.artifactStorage setArtifact:response.artifact].thenOn(
      self.queue, ^FIRAppCheckToken *(id result) {
        return response.token;
      });
}

#pragma mark - Token refresh sequence

- (FBLPromise<FIRAppCheckToken *> *)refreshTokenWithKeyID:(NSString *)keyID
                                                 artifact:(NSData *)artifact {
  // TODO: Implement (b/186438346).
  return [FBLPromise resolvedWith:nil];
}

#pragma mark - State handling

- (FBLPromise<FIRAppAttestProviderState *> *)attestationState {
  dispatch_queue_t stateQueue =
      dispatch_queue_create("FIRAppAttestProvider.state", DISPATCH_QUEUE_SERIAL);

  return [FBLPromise
      onQueue:stateQueue
           do:^id _Nullable {
             NSError *error;

             // 1. Check if App Attest is supported.
             id isSupportedResult = FBLPromiseAwait([self isAppAttestSupported], &error);
             if (isSupportedResult == nil) {
               return [[FIRAppAttestProviderState alloc] initUnsupportedWithError:error];
             }

             // 2. Check for stored key ID of the generated App Attest key pair.
             NSString *appAttestKeyID =
                 FBLPromiseAwait([self.keyIDStorage getAppAttestKeyID], &error);
             if (appAttestKeyID == nil) {
               return [[FIRAppAttestProviderState alloc] initWithSupportedInitialState];
             }

             // 3. Check for stored attestation artifact received from Firebase backend.
             NSData *attestationArtifact =
                 FBLPromiseAwait([self.artifactStorage getArtifact], &error);
             if (attestationArtifact == nil) {
               return [[FIRAppAttestProviderState alloc] initWithGeneratedKeyID:appAttestKeyID];
             }

             // 4. A valid App Attest key pair was generated and registered with Firebase
             // backend. Return the corresponding state.
             return [[FIRAppAttestProviderState alloc] initWithRegisteredKeyID:appAttestKeyID
                                                                      artifact:attestationArtifact];
           }];
}

#pragma mark - Helpers

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

/// Generates a new App Attest key associated with the Firebase app if `storedKeyID == nil`.
- (FBLPromise<NSString *> *)generateAppAttestKeyIDIfNeeded:(nullable NSString *)storedKeyID {
  if (storedKeyID) {
    // The key ID has been fetched already, just return it.
    return [FBLPromise resolvedWith:storedKeyID];
  } else {
    // Generate and save a new key otherwise.
    return [self generateAppAttestKey];
  }
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
