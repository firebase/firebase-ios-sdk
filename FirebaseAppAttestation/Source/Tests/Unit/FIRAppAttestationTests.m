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

// TODO: Consider using manually implemented fakes instead of OCMock
// (see also go/srl-dev/why-fakes#no-ocmock)
#import <OCMock/OCMock.h>

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

@property(nonatomic) id mockProviderFactory;
@property(nonatomic) id mockAttestationProvider;

@end

@implementation FIRAppAttestationTests

- (void)setUp {
  [super setUp];

  self.mockAttestationProvider = OCMProtocolMock(@protocol(FIRAppAttestationProvider));
  self.mockProviderFactory = OCMProtocolMock(@protocol(FIRAppAttestationProviderFactory));
}

- (void)tearDown {
  [FIRApp resetApps];
  [FIRAppAttestation setAttestationProviderFactory:nil];

  [self.mockProviderFactory stopMocking];
  self.mockProviderFactory = nil;
  [self.mockAttestationProvider stopMocking];
  self.mockAttestationProvider = nil;

  [super tearDown];
}

// TODO: Consider moving it to integration tests since it requires `[FIRApp configure]`
- (void)testSetAttestationProviderFactoryWithDefaultApp {
  NSString *appName = kFIRDefaultAppName;

  // 1. Set Attestation Provider Factory.
  [FIRAppAttestation setAttestationProviderFactory:self.mockProviderFactory];

  // 2. Expect factory to be used on [FIRApp configure].
  id appValidationArg = [OCMArg checkWithBlock:^BOOL(FIRApp *app) {
    XCTAssertEqual(app.name, appName);
    return YES;
  }];
  OCMExpect([self.mockProviderFactory createProviderWithApp:appValidationArg])
      .andReturn(self.mockAttestationProvider);

  // 3. Configure FIRApp.
  [self configureAppWithName:appName];

  // 4. Expect Attestation Provider to be called on getToken.
  FIRAppAttestationToken *fakeToken =
      [[FIRAppAttestationToken alloc] initWithToken:@"token" expirationDate:[NSDate distantFuture]];
  id completionBlockArg = [OCMArg invokeBlockWithArgs:fakeToken, [NSNull null], nil];
  OCMExpect([self.mockAttestationProvider getTokenWithCompletion:completionBlockArg]);

  // 5. Call getToken and check the result.
  FIRApp *app = [FIRApp appNamed:appName];
  id<FIRAppAttestationInterop> appAttestation =
      FIR_COMPONENT(FIRAppAttestationInterop, app.container);

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [appAttestation
      getTokenForcingRefresh:YES
                  completion:^(id<FIRAppAttestationTokenInterop> _Nullable token,
                               NSError *_Nullable error) {
                    [completionExpectation fulfill];
                    XCTAssertNil(error);
                    XCTAssertNotNil(token);
                    XCTAssertEqualObjects(token.token, fakeToken.token);
                    XCTAssertEqualObjects(token.expirationDate, fakeToken.expirationDate);
                  }];
  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 6. Verify mocks
  OCMVerifyAll(self.mockProviderFactory);
  OCMVerifyAll(self.mockAttestationProvider);
}

- (void)testSetAttestationProviderFactoryWithNonDefaultApp {
  NSString *appName = @"custom_app";

  // 1. Set Attestation Provider Factory.
  [FIRAppAttestation setAttestationProviderFactory:self.mockProviderFactory forAppName:appName];

  // 2. Expect factory to be used on [FIRApp configure].
  id appValidationArg = [OCMArg checkWithBlock:^BOOL(FIRApp *app) {
    XCTAssertEqual(app.name, appName);
    return YES;
  }];
  OCMExpect([self.mockProviderFactory createProviderWithApp:appValidationArg])
      .andReturn(self.mockAttestationProvider);

  // 3. Configure FIRApp.
  [self configureAppWithName:appName];

  // 4. Expect Attestation Provider to be called on getToken.
  FIRAppAttestationToken *fakeToken =
      [[FIRAppAttestationToken alloc] initWithToken:@"token" expirationDate:[NSDate distantFuture]];
  id completionBlockArg = [OCMArg invokeBlockWithArgs:fakeToken, [NSNull null], nil];
  OCMExpect([self.mockAttestationProvider getTokenWithCompletion:completionBlockArg]);

  // 5. Call getToken and check the result.
  FIRApp *app = [FIRApp appNamed:appName];
  id<FIRAppAttestationInterop> appAttestation =
      FIR_COMPONENT(FIRAppAttestationInterop, app.container);

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [appAttestation
      getTokenForcingRefresh:YES
                  completion:^(id<FIRAppAttestationTokenInterop> _Nullable token,
                               NSError *_Nullable error) {
                    [completionExpectation fulfill];
                    XCTAssertNil(error);
                    XCTAssertNotNil(token);
                    XCTAssertEqualObjects(token.token, fakeToken.token);
                    XCTAssertEqualObjects(token.expirationDate, fakeToken.expirationDate);
                  }];
  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 6. Verify mocks
  OCMVerifyAll(self.mockProviderFactory);
  OCMVerifyAll(self.mockAttestationProvider);
}

#pragma mark - Helpers

- (void)configureAppWithName:(NSString *)appName {
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"
                                  GCMSenderID:@"sender_id"];
  [FIRApp configureWithName:appName options:options];
}

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
