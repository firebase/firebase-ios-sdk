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

#import <Foundation/Foundation.h>

@class FBLPromise<Result>;
@class FIRAppCheckToken;
@protocol FIRAppCheckAPIServiceProtocol;

NS_ASSUME_NONNULL_BEGIN

@protocol FIRAppAttestAPIServiceProtocol <NSObject>

/// Request a random challenge from server.
- (FBLPromise<NSData *> *)getRandomChallenge;

/// Exchanges attestation data to FAC token.
- (FBLPromise<FIRAppCheckToken *> *)appCheckTokenWithAttestation:(NSData *)attestation
                                                           keyID:(NSString *)keyID
                                                       challenge:(NSData *)challenge;

@end

@interface FIRAppAttestAPIService : NSObject <FIRAppAttestAPIServiceProtocol>

- (instancetype)initWithAPIService:(id<FIRAppCheckAPIServiceProtocol>)APIService
                         projectID:(NSString *)projectID
                             appID:(NSString *)appID;

@end

NS_ASSUME_NONNULL_END
