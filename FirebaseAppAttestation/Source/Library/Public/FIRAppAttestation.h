/*
 * Copyright 2020 Google
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

#import <FirebaseAppAttestation/FIRAppAttestationTokenHandler.h>

@class FIRApp;
@protocol FIRAppAttestationProviderFactory;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AppAttestation)
@interface FIRAppAttestation : NSObject
/// AppAttestation instance for the default FirebaseApp.
+ (instancetype)appAttestation NS_SWIFT_NAME(appAttestation());

/// AppAttestation instance for the specified FirebaseApp.
+ (nullable instancetype)appAttestationWithApp:(FIRApp *)application
    NS_SWIFT_NAME(appAttestation(app:));

/// Retrieve a cached or generate a new FAA Token.
- (void)getTokenWithCompletion:(FIRAppAttestationTokenHandler)handler
    NS_SWIFT_NAME(getToken(completion:));

/// Retrieve a cached or generate a new FAA Token. If forcingRefresh == YES always generates a new
/// token and updates the cache.
- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(FIRAppAttestationTokenHandler)handler;
NS_SWIFT_NAME(getToken(forcingRefresh:completion:));

/// Set Attestation Provider Factory for default FirebaseApp.
+ (void)setAttestationProviderFactory:(nullable id<FIRAppAttestationProviderFactory>)factory;

/// Set Attestation Provider Factory for FirebaseApp with the specified name.
+ (void)setAttestationProviderFactory:(nullable id<FIRAppAttestationProviderFactory>)factory
                           forAppName:(NSString *)firebaseAppName;

@end

NS_ASSUME_NONNULL_END
