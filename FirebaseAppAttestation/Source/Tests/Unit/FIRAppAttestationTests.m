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

#import <XCTest/XCTest.h>

#import <FirebaseAppAttestation/FirebaseAppAttestation.h>
#import <FirebaseAppAttestationInterop/FIRAppAttestationInterop.h>
#import <FirebaseAppAttestationInterop/FIRAppAttestationTokenInterop.h>

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FirebaseCore.h>

@interface DummyAttestationProvider : NSObject <FIRAppAttestationProvider>
@end

@implementation DummyAttestationProvider
- (void)getTokenWithCompletion:(nonnull FIRAppAttestationTokenHandler)handler {
  FIRAppAttestationToken *token =
      [[FIRAppAttestationToken alloc] initWithToken:@"Token" expirationDate:[NSDate distantFuture]];
  handler(token, nil);
}
@end

@interface AttestationProviderFactory : NSObject <FIRAppAttestationProviderFactory>
@end

@implementation AttestationProviderFactory

- (nullable id<FIRAppAttestationProvider>)createProviderWithApp:(nonnull FIRApp *)app {
  return [[DummyAttestationProvider alloc] init];
}

@end

@interface FIRAppAttestationTests : XCTestCase

@end

@implementation FIRAppAttestationTests

// TODO: Remove usage example once API review approval obtained.
- (void)usageExample {
  // Set a custom attestation provider factory for the default FIRApp.
  [FIRAppAttestation setAttestationProviderFactory:[[AttestationProviderFactory alloc] init]];
  [FIRApp configure];

  [FIRAppAttestation setAttestationProviderFactory:[[AttestationProviderFactory alloc] init]
                                        forAppName:@"AppName"];

  FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:@"path"];
  [FIRApp configureWithName:@"AppName" options:options];

  FIRApp *defaultApp = [FIRApp defaultApp];

  id<FIRAppAttestationInterop> defaultAppAttestation =
      FIR_COMPONENT(FIRAppAttestationInterop, defaultApp.container);

  [defaultAppAttestation getTokenWithCompletion:^(id<FIRAppAttestationTokenInterop> _Nullable token,
                                                  NSError *_Nullable error) {
    if (token) {
      NSLog(@"Token: %@", token.token);
    } else {
      NSLog(@"Error: %@", error);
    }
  }];
}

@end
