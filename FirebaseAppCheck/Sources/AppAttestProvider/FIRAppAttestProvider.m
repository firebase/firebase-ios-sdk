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
#import "FirebaseAppCheck/Sources/AppAttestProvider/API/FIRAppAttestAttestationResponse.h"
#import "FirebaseAppCheck/Sources/AppAttestProvider/FIRAppAttestProviderState.h"
#import "FirebaseAppCheck/Sources/AppAttestProvider/FIRAppAttestService.h"
#import "FirebaseAppCheck/Sources/AppAttestProvider/Storage/FIRAppAttestArtifactStorage.h"
#import "FirebaseAppCheck/Sources/AppAttestProvider/Storage/FIRAppAttestKeyIDStorage.h"
#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"
#import "FirebaseAppCheck/Sources/Core/Backoff/FIRAppCheckBackoffWrapper.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"

#import "FirebaseAppCheck/Sources/Core/Utils/FIRAppCheckCryptoUtils.h"

#import "FirebaseAppCheck/Sources/AppAttestProvider/Errors/FIRAppAttestRejectionError.h"
#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckHTTPError.h"

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

/// A data object that contains information required for assertion request.
@interface FIRAppAttestAssertionData : NSObject

@property(nonatomic, readonly) NSData *challenge;
@property(nonatomic, readonly) NSData *artifact;
@property(nonatomic, readonly) NSData *assertion;

- (instancetype)initWithChallenge:(NSData *)challenge
                         artifact:(NSData *)artifact
                        assertion:(NSData *)assertion;

@end

@implementation FIRAppAttestAssertionData

- (instancetype)initWithChallenge:(NSData *)challenge
                         artifact:(NSData *)artifact
                        assertion:(NSData *)assertion {
  self = [super init];
  if (self) {
    _challenge = challenge;
    _artifact = artifact;
    _assertion = assertion;
  }
  return self;
}

@end

@interface FIRAppAttestProvider ()

@property(nonatomic, readonly) id<FIRAppAttestAPIServiceProtocol> APIService;
@property(nonatomic, readonly) id<FIRAppAttestService> appAttestService;
@property(nonatomic, readonly) id<FIRAppAttestKeyIDStorageProtocol> keyIDStorage;
@property(nonatomic, readonly) id<FIRAppAttestArtifactStorageProtocol> artifactStorage;
@property(nonatomic, readonly) id<FIRAppCheckBackoffWrapperProtocol> backoffWrapper;

@property(nonatomic, nullable) FBLPromise<FIRAppCheckToken *> *ongoingGetTokenOperation;

@property(nonatomic, readonly) dispatch_queue_t queue;

@end

@implementation FIRAppAttestProvider

- (instancetype)initWithAppAttestService:(id<FIRAppAttestService>)appAttestService
                              APIService:(id<FIRAppAttestAPIServiceProtocol>)APIService
                            keyIDStorage:(id<FIRAppAttestKeyIDStorageProtocol>)keyIDStorage
                         artifactStorage:(id<FIRAppAttestArtifactStorageProtocol>)artifactStorage
                          backoffWrapper:(id<FIRAppCheckBackoffWrapperProtocol>)backoffWrapper {
  self = [super init];
  if (self) {
    _appAttestService = appAttestService;
    _APIService = APIService;
    _keyIDStorage = keyIDStorage;
    _artifactStorage = artifactStorage;
    _backoffWrapper = backoffWrapper;
    _queue = dispatch_queue_create("com.firebase.FIRAppAttestProvider", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (nullable instancetype)initWithApp:(FIRApp *)app {
#if FIR_APP_ATTEST_SUPPORTED_TARGETS
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

  FIRAppCheckBackoffWrapper *backoffWrapper = [[FIRAppCheckBackoffWrapper alloc] init];

  return [self initWithAppAttestService:DCAppAttestService.sharedService
                             APIService:appAttestAPIService
                           keyIDStorage:keyIDStorage
                        artifactStorage:artifactStorage
                         backoffWrapper:backoffWrapper];
#else   // FIR_APP_ATTEST_SUPPORTED_TARGETS
  return nil;
#endif  // FIR_APP_ATTEST_SUPPORTED_TARGETS
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
  return [FBLPromise onQueue:self.queue
                          do:^id _Nullable {
                            if (self.ongoingGetTokenOperation == nil) {
                              // Kick off a new handshake sequence only when there is not an ongoing
                              // handshake to avoid race conditions.
                              self.ongoingGetTokenOperation =
                                  [self createGetTokenSequenceWithBackoffPromise]

                                      // Release the ongoing operation promise on completion.
                                      .then(^FIRAppCheckToken *(FIRAppCheckToken *token) {
                                        self.ongoingGetTokenOperation = nil;
                                        return token;
                                      })
                                      .recover(^NSError *(NSError *error) {
                                        self.ongoingGetTokenOperation = nil;
                                        return error;
                                      });
                            }
                            return self.ongoingGetTokenOperation;
                          }];
}

- (FBLPromise<FIRAppCheckToken *> *)createGetTokenSequenceWithBackoffPromise {
  return [self.backoffWrapper
      applyBackoffToOperation:^FBLPromise *_Nonnull {
        return [self createGetTokenSequencePromise];
      }
                 errorHandler:[self.backoffWrapper defaultAppCheckProviderErrorHandler]];
}

- (FBLPromise<FIRAppCheckToken *> *)createGetTokenSequencePromise {
  // Check attestation state to decide on the next steps.
  return [self attestationState].thenOn(self.queue, ^id(FIRAppAttestProviderState *attestState) {
    switch (attestState.state) {
      case FIRAppAttestAttestationStateUnsupported:
        FIRAppCheckDebugLog(kFIRLoggerAppCheckMessageCodeAppAttestNotSupported,
                            @"App Attest is not supported.");
        return attestState.appAttestUnsupportedError;
        break;

      case FIRAppAttestAttestationStateSupportedInitial:
      case FIRAppAttestAttestationStateKeyGenerated:
        // Initial handshake is required for both the "initial" and the "key generated" states.
        return [self initialHandshakeWithKeyID:attestState.appAttestKeyID];
        break;

      case FIRAppAttestAttestationStateKeyRegistered:
        // Refresh FAC token using the existing registered App Attest key pair.
        return [self refreshTokenWithKeyID:attestState.appAttestKeyID
                                  artifact:attestState.attestationArtifact];
        break;
    }
  });
}

#pragma mark - Initial handshake sequence (attestation)

- (FBLPromise<FIRAppCheckToken *> *)initialHandshakeWithKeyID:(nullable NSString *)keyID {
  // 1. Attest the device. Retry once on 403 from Firebase backend (attestation rejection error).
  __block NSString *keyIDForAttempt = keyID;
  return [FBLPromise onQueue:self.queue
             attempts:1
             delay:0
             condition:^BOOL(NSInteger attemptCount, NSError *_Nonnull error) {
               // Reset keyID before retrying.
               keyIDForAttempt = nil;
               return [error isKindOfClass:[FIRAppAttestRejectionError class]];
             }
             retry:^FBLPromise<NSArray * /*[keyID, attestArtifact]*/> *_Nullable {
               return [self attestKeyGenerateIfNeededWithID:keyIDForAttempt];
             }]
      .thenOn(self.queue, ^FBLPromise<FIRAppCheckToken *> *(NSArray *attestationResults) {
        // 4. Save the artifact and return the received FAC token.

        FIRAppAttestKeyAttestationResult *attestation = attestationResults.firstObject;
        FIRAppAttestAttestationResponse *firebaseAttestationResponse =
            attestationResults.lastObject;

        return [self saveArtifactAndGetAppCheckTokenFromResponse:firebaseAttestationResponse
                                                           keyID:attestation.keyID];
      });
}

- (FBLPromise<FIRAppCheckToken *> *)saveArtifactAndGetAppCheckTokenFromResponse:
                                        (FIRAppAttestAttestationResponse *)response
                                                                          keyID:(NSString *)keyID {
  return [self.artifactStorage setArtifact:response.artifact forKey:keyID].thenOn(
      self.queue, ^FIRAppCheckToken *(id result) {
        return response.token;
      });
}

- (FBLPromise<FIRAppAttestKeyAttestationResult *> *)attestKey:(NSString *)keyID
                                                    challenge:(NSData *)challenge {
  return [FBLPromise onQueue:self.queue
                          do:^NSData *_Nullable {
                            return [FIRAppCheckCryptoUtils sha256HashFromData:challenge];
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

- (FBLPromise<NSArray * /*[keyID, attestArtifact]*/> *)attestKeyGenerateIfNeededWithID:
    (nullable NSString *)keyID {
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
      .thenOn(self.queue,
              ^FBLPromise<NSArray *> *(FIRAppAttestKeyAttestationResult *result) {
                // 3. Exchange the attestation to FAC token and pass the results to the next step.
                NSArray *attestationResults = @[
                  // 3.1. Just pass the attestation result to the next step.
                  [FBLPromise resolvedWith:result],
                  // 3.2. Exchange the attestation to FAC token.
                  [self.APIService attestKeyWithAttestation:result.attestation
                                                      keyID:result.keyID
                                                  challenge:result.challenge]
                ];

                return [FBLPromise onQueue:self.queue all:attestationResults];
              })
      .recoverOn(self.queue, ^id(NSError *error) {
        // If App Attest attestation was rejected then reset the attestation and throw a specific
        // error.
        FIRAppCheckHTTPError *HTTPError = (FIRAppCheckHTTPError *)error;
        if ([HTTPError isKindOfClass:[FIRAppCheckHTTPError class]] &&
            HTTPError.HTTPResponse.statusCode == 403) {
          FIRAppCheckDebugLog(kFIRLoggerAppCheckMessageCodeAttestationRejected,
                              @"App Attest attestation was rejected by backend. The existing "
                              @"attestation will be reset.");
          // Reset the attestation.
          return [self resetAttestation].thenOn(self.queue, ^NSError *(id result) {
            // Throw the rejection error.
            return [[FIRAppAttestRejectionError alloc] init];
          });
        }

        // Otherwise just re-throw the error.
        return error;
      });
}

/// Resets stored key ID and attestation artifact.
- (FBLPromise<NSNull *> *)resetAttestation {
  return [self.keyIDStorage setAppAttestKeyID:nil].thenOn(self.queue, ^id(id result) {
    return [self.artifactStorage setArtifact:nil forKey:@""];
  });
}

#pragma mark - Token refresh sequence (assertion)

- (FBLPromise<FIRAppCheckToken *> *)refreshTokenWithKeyID:(NSString *)keyID
                                                 artifact:(NSData *)artifact {
  return [self.APIService getRandomChallenge]
      .thenOn(self.queue,
              ^FBLPromise<FIRAppAttestAssertionData *> *(NSData *challenge) {
                return [self generateAssertionWithKeyID:keyID
                                               artifact:artifact
                                              challenge:challenge];
              })
      .thenOn(self.queue, ^id(FIRAppAttestAssertionData *assertion) {
        return [self.APIService getAppCheckTokenWithArtifact:assertion.artifact
                                                   challenge:assertion.challenge
                                                   assertion:assertion.assertion];
      });
}

- (FBLPromise<FIRAppAttestAssertionData *> *)generateAssertionWithKeyID:(NSString *)keyID
                                                               artifact:(NSData *)artifact
                                                              challenge:(NSData *)challenge {
  // 1. Calculate the statement and its hash for assertion.
  return [FBLPromise
             onQueue:self.queue
                  do:^NSData *_Nullable {
                    // 1.1. Compose statement to generate assertion for.
                    NSMutableData *statementForAssertion = [artifact mutableCopy];
                    [statementForAssertion appendData:challenge];

                    // 1.2. Get the statement SHA256 hash.
                    return [FIRAppCheckCryptoUtils sha256HashFromData:[statementForAssertion copy]];
                  }]
      .thenOn(
          self.queue,
          ^FBLPromise<NSData *> *(NSData *statementHash) {
            // 2. Generate App Attest assertion.
            return [FBLPromise onQueue:self.queue
                wrapObjectOrErrorCompletion:^(FBLPromiseObjectOrErrorCompletion _Nonnull handler) {
                  [self.appAttestService generateAssertion:keyID
                                            clientDataHash:statementHash
                                         completionHandler:handler];
                }];
          })
      // 3. Compose the result object.
      .thenOn(self.queue, ^FIRAppAttestAssertionData *(NSData *assertion) {
        return [[FIRAppAttestAssertionData alloc] initWithChallenge:challenge
                                                           artifact:artifact
                                                          assertion:assertion];
      });
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
                 FBLPromiseAwait([self.artifactStorage getArtifactForKey:appAttestKeyID], &error);
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

@end

NS_ASSUME_NONNULL_END
