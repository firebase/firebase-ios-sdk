// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseAppDistribution/Sources/FIRAppDistributionUIService.h"
#import "FirebaseAppDistribution/Sources/FIRAppDistributionMachO.h"
#import "FirebaseAppDistribution/Sources/FIRFADApiService.h"
#import "FirebaseAppDistribution/Sources/Private/FIRAppDistribution.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "GoogleUtilities/AppDelegateSwizzler/Private/GULAppDelegateSwizzler.h"
#import "GoogleUtilities/UserDefaults/Private/GULUserDefaults.h"

@interface FIRAppDistributionTests : XCTestCase

@property(nonatomic, strong) FIRAppDistribution *appDistribution;

@end

@interface FIRAppDistribution (PrivateUnitTesting)

- (instancetype)initWithApp:(FIRApp *)app appInfo:(NSDictionary *)appInfo;

- (void)fetchNewLatestRelease:(FIRAppDistributionUpdateCheckCompletion)completion;

- (NSError *)mapFetchReleasesError:(NSError *)error;

@end

@implementation FIRAppDistributionTests {
  id _mockFIRAppClass;
  id _mockFIRFADApiService;
  id _mockAppDelegateInterceptor;
  id _mockFIRInstallations;
  id _mockInstallationToken;
  id _mockMachO;
  NSString *_mockAuthToken;
  NSString *_mockInstallationId;
  NSArray *_mockReleases;
  NSString *_mockCodeHash;
}

- (void)setUp {
  [super setUp];
  _mockAuthToken = @"this-is-an-auth-token";
  _mockCodeHash = @"this-is-a-fake-code-hash";
  _mockFIRAppClass = OCMClassMock([FIRApp class]);
  _mockFIRFADApiService = OCMClassMock([FIRFADApiService class]);
  _mockAppDelegateInterceptor = OCMClassMock([FIRAppDistributionUIService class]);
  _mockFIRInstallations = OCMClassMock([FIRInstallations class]);
  _mockInstallationToken = OCMClassMock([FIRInstallationsAuthTokenResult class]);
  _mockMachO = OCMClassMock([FIRAppDistributionMachO class]);
  id mockBundle = OCMClassMock([NSBundle class]);
  OCMStub([_mockFIRAppClass defaultApp]).andReturn(_mockFIRAppClass);
  OCMStub([_mockAppDelegateInterceptor sharedInstance]).andReturn(_mockAppDelegateInterceptor);
  OCMStub([_mockAppDelegateInterceptor initializeUIState])
      .andDo(^(NSInvocation *invocation){
      });
  OCMStub([_mockFIRInstallations installations]).andReturn(_mockFIRInstallations);
  OCMStub([_mockInstallationToken authToken]).andReturn(_mockAuthToken);
  OCMStub([_mockMachO alloc]).andReturn(_mockMachO);
  OCMStub([_mockMachO initWithPath:OCMOCK_ANY]).andReturn(_mockMachO);
  OCMStub([mockBundle mainBundle]).andReturn(mockBundle);
  OCMStub([mockBundle executablePath]).andReturn(@"this-is-a-fake-executablePath");

  NSDictionary<NSString *, NSString *> *dict = [[NSDictionary<NSString *, NSString *> alloc] init];
  self.appDistribution = [[FIRAppDistribution alloc] initWithApp:_mockFIRAppClass appInfo:dict];

  _mockInstallationId = @"this-id-is-fake-ccccc";
  _mockReleases = @[
    @{
      @"codeHash" : @"this-is-another-code-hash",
      @"displayVersion" : @"1.0.0",
      @"buildVersion" : @"111",
      @"releaseNotes" : @"This is a release",
      @"downloadUrl" : @"http://faketyfakefake.download"
    },
    @{
      @"latest" : @YES,
      @"codeHash" : _mockCodeHash,
      @"displayVersion" : @"1.0.1",
      @"buildVersion" : @"112",
      @"releaseNotes" : @"This is a release too",
      @"downloadUrl" : @"http://faketyfakefake.download"
    }
  ];
}

- (void)tearDown {
  [super tearDown];
  [[GULUserDefaults standardUserDefaults] removeObjectForKey:@"FIRFADSignInState"];
  [_mockFIRAppClass stopMocking];
  [_mockFIRFADApiService stopMocking];
  [_mockAppDelegateInterceptor stopMocking];
  [_mockFIRInstallations stopMocking];
  [_mockInstallationToken stopMocking];
  [_mockMachO stopMocking];
}

- (void)mockInstallationIdCompletion:(NSString *_Nullable)identifier
                               error:(NSError *_Nullable)error {
  [OCMStub([_mockFIRInstallations installationIDWithCompletion:OCMOCK_ANY])
      andDo:^(NSInvocation *invocation) {
        void (^handler)(NSString *identifier, NSError *_Nullable error);
        [invocation getArgument:&handler atIndex:2];
        handler(identifier, error);
      }];
}

- (void)mockAppDelegateCompletion:(NSError *_Nullable)error {
  [OCMStub([_mockAppDelegateInterceptor appDistributionRegistrationFlow:OCMOCK_ANY
                                                         withCompletion:OCMOCK_ANY])
      andDo:^(NSInvocation *invocation) {
        void (^handler)(NSError *_Nullable error);
        [invocation getArgument:&handler atIndex:3];
        handler(error);
      }];
}

- (void)mockFetchReleasesCompletion:(NSArray *)releases error:(NSError *)error {
  [OCMStub([_mockFIRFADApiService fetchReleasesWithCompletion:OCMOCK_ANY])
      andDo:^(NSInvocation *invocation) {
        void (^handler)(NSArray *releases, NSError *_Nullable error);
        [invocation getArgument:&handler atIndex:2];
        handler(releases, error);
      }];
}

- (void)testInitWithApp {
  XCTAssertNotNil([self appDistribution]);
}

- (void)testSignInWithCompletionPersistSignInStateSuccess {
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockAppDelegateCompletion:nil];
  [self mockFetchReleasesCompletion:_mockReleases error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Persist sign in state succeeds."];

  [[self appDistribution] signInTesterWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertTrue([[self appDistribution] isTesterSignedIn]);
}

- (void)testSignInWithCompletionInstallationIDNotFoundFailure {
  NSError *mockError =
      [NSError errorWithDomain:@"this.is.fake"
                          code:3
                      userInfo:@{NSLocalizedDescriptionKey : @"This is unfortunate."}];
  [self mockInstallationIdCompletion:_mockInstallationId error:mockError];
  [self mockAppDelegateCompletion:nil];
  [self mockFetchReleasesCompletion:_mockReleases error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Persist sign in state fails."];

  [[self appDistribution] signInTesterWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNotNil(error);
    XCTAssertEqual([error code], FIRAppDistributionErrorUnknown);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertFalse([[self appDistribution] isTesterSignedIn]);
}

- (void)testSignInWithCompletionDelegateFailureDoesNotPersist {
  NSError *mockError =
      [NSError errorWithDomain:@"fake.app.delegate.domain"
                          code:4
                      userInfo:@{NSLocalizedDescriptionKey : @"This is unfortunate."}];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockAppDelegateCompletion:mockError];
  [self mockFetchReleasesCompletion:_mockReleases error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:
                @"Persist sign in state fails when the delegate recieves a failure."];

  [[self appDistribution] signInTesterWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNotNil(error);
    XCTAssertEqual([error code], 4);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertFalse([[self appDistribution] isTesterSignedIn]);
}

- (void)testSignInWithCompletionFetchReleasesFailureDoesNotPersist {
  NSError *mockError =
      [NSError errorWithDomain:kFIRFADApiErrorDomain
                          code:FIRFADApiErrorUnauthenticated
                      userInfo:@{NSLocalizedDescriptionKey : @"This is unfortunate."}];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockAppDelegateCompletion:nil];
  [self mockFetchReleasesCompletion:_mockReleases error:mockError];
  XCTestExpectation *expectation = [self
      expectationWithDescription:@"Persist sign in state fails when we fail to fetch releases."];
  [[self appDistribution] signInTesterWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNotNil(error);
    XCTAssertEqual([error code], FIRAppDistributionErrorAuthenticationFailure);
    XCTAssertEqual([error domain], FIRAppDistributionErrorDomain);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertFalse([[self appDistribution] isTesterSignedIn]);
}

- (void)testSignOutSuccess {
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockAppDelegateCompletion:nil];
  [self mockFetchReleasesCompletion:_mockReleases error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Persist sign out state succeeds."];

  [[self appDistribution] signInTesterWithCompletion:^(NSError *_Nullable error) {
    XCTAssertTrue([[self appDistribution] isTesterSignedIn]);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [[self appDistribution] signOutTester];
  XCTAssertFalse([[self appDistribution] isTesterSignedIn]);
}

- (void)testFetchNewLatestReleaseSuccess {
  [self mockFetchReleasesCompletion:_mockReleases error:nil];
  OCMStub([_mockMachO codeHash]).andReturn(@"this-is-old");
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch latest release succeeds."];
  [[self appDistribution] fetchNewLatestRelease:^(FIRAppDistributionRelease *_Nullable release,
                                                  NSError *_Nullable error) {
    XCTAssertNotNil(release);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:5.0];
}

- (void)testFetchNewLatestReleaseNoNewRelease {
  [self mockFetchReleasesCompletion:_mockReleases error:nil];
  OCMStub([_mockMachO codeHash]).andReturn(_mockCodeHash);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch latest release with no new release succeeds."];
  [expectation setInverted:YES];

  [[self appDistribution] fetchNewLatestRelease:^(FIRAppDistributionRelease *_Nullable release,
                                                  NSError *_Nullable error) {
    XCTAssertNil(release);
    XCTAssertNil(error);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
}

- (void)testFetchNewLatestReleaseFailure {
  NSError *mockError =
      [NSError errorWithDomain:kFIRFADApiErrorDomain
                          code:FIRFADApiErrorTimeout
                      userInfo:@{NSLocalizedDescriptionKey : @"This is unfortunate."}];
  [self mockFetchReleasesCompletion:nil error:mockError];
  OCMStub([_mockMachO codeHash]).andReturn(@"this-is-old");

  XCTestExpectation *expectation = [self expectationWithDescription:@"Fetch latest release fails."];

  [[self appDistribution] fetchNewLatestRelease:^(FIRAppDistributionRelease *_Nullable release,
                                                  NSError *_Nullable error) {
    XCTAssertNil(release);
    XCTAssertNotNil(error);
    XCTAssertEqual([error code], FIRAppDistributionErrorNetworkFailure);
    XCTAssertEqual([error domain], FIRAppDistributionErrorDomain);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
}

- (void)testHandleFetchReleasesErrorTimeout {
  NSError *mockError =
      [NSError errorWithDomain:kFIRFADApiErrorDomain
                          code:FIRFADApiErrorTimeout
                      userInfo:@{NSLocalizedDescriptionKey : @"This is unfortunate."}];
  NSError *handledError = [[self appDistribution] mapFetchReleasesError:mockError];
  XCTAssertNotNil(handledError);
  XCTAssertEqual([handledError code], FIRAppDistributionErrorNetworkFailure);
  XCTAssertEqual([handledError domain], FIRAppDistributionErrorDomain);
}

- (void)testHandleFetchReleasesErrorUnauthenticated {
  NSError *mockError =
      [NSError errorWithDomain:kFIRFADApiErrorDomain
                          code:FIRFADApiErrorUnauthenticated
                      userInfo:@{NSLocalizedDescriptionKey : @"This is unfortunate."}];
  NSError *handledError = [[self appDistribution] mapFetchReleasesError:mockError];
  XCTAssertNotNil(handledError);
  XCTAssertEqual([handledError code], FIRAppDistributionErrorAuthenticationFailure);
  XCTAssertEqual([handledError domain], FIRAppDistributionErrorDomain);
}

- (void)testHandleFetchReleasesErrorUnauthorized {
  NSError *mockError =
      [NSError errorWithDomain:kFIRFADApiErrorDomain
                          code:FIRFADApiErrorUnauthorized
                      userInfo:@{NSLocalizedDescriptionKey : @"This is unfortunate."}];
  NSError *handledError = [[self appDistribution] mapFetchReleasesError:mockError];
  XCTAssertNotNil(handledError);
  XCTAssertEqual([handledError code], FIRAppDistributionErrorAuthenticationFailure);
  XCTAssertEqual([handledError domain], FIRAppDistributionErrorDomain);
}

- (void)testHandleFetchReleasesErrorTokenGenerationFailure {
  NSError *mockError =
      [NSError errorWithDomain:kFIRFADApiErrorDomain
                          code:FIRFADApiTokenGenerationFailure
                      userInfo:@{NSLocalizedDescriptionKey : @"This is unfortunate."}];
  NSError *handledError = [[self appDistribution] mapFetchReleasesError:mockError];
  XCTAssertNotNil(handledError);
  XCTAssertEqual([handledError code], FIRAppDistributionErrorAuthenticationFailure);
  XCTAssertEqual([handledError domain], FIRAppDistributionErrorDomain);
}

- (void)testHandleFetchReleasesErrorInstallationIdentifierFailure {
  NSError *mockError =
      [NSError errorWithDomain:kFIRFADApiErrorDomain
                          code:FIRFADApiInstallationIdentifierError
                      userInfo:@{NSLocalizedDescriptionKey : @"This is unfortunate."}];
  NSError *handledError = [[self appDistribution] mapFetchReleasesError:mockError];
  XCTAssertNotNil(handledError);
  XCTAssertEqual([handledError code], FIRAppDistributionErrorAuthenticationFailure);
  XCTAssertEqual([handledError domain], FIRAppDistributionErrorDomain);
}

- (void)testHandleFetchReleasesErrorNotFound {
  NSError *mockError =
      [NSError errorWithDomain:kFIRFADApiErrorDomain
                          code:FIRFADApiErrorNotFound
                      userInfo:@{NSLocalizedDescriptionKey : @"This is unfortunate."}];
  NSError *handledError = [[self appDistribution] mapFetchReleasesError:mockError];
  XCTAssertNotNil(handledError);
  XCTAssertEqual([handledError code], FIRAppDistributionErrorAuthenticationFailure);
  XCTAssertEqual([handledError domain], FIRAppDistributionErrorDomain);
}

- (void)testHandleFetchReleasesErrorApiDomainErrorUnknown {
  NSError *mockError =
      [NSError errorWithDomain:kFIRFADApiErrorDomain
                          code:209
                      userInfo:@{NSLocalizedDescriptionKey : @"This is unfortunate."}];
  NSError *handledError = [[self appDistribution] mapFetchReleasesError:mockError];
  XCTAssertNotNil(handledError);
  XCTAssertEqual([handledError code], FIRAppDistributionErrorUnknown);
  XCTAssertEqual([handledError domain], FIRAppDistributionErrorDomain);
}

- (void)testHandleFetchReleasesErrorUnknownDomainError {
  NSError *mockError =
      [NSError errorWithDomain:@"this.is.not.an.api.failure"
                          code:4
                      userInfo:@{NSLocalizedDescriptionKey : @"This is unfortunate."}];
  NSError *handledError = [[self appDistribution] mapFetchReleasesError:mockError];
  XCTAssertNotNil(handledError);
  XCTAssertEqual([handledError code], FIRAppDistributionErrorUnknown);
  XCTAssertEqual([handledError domain], FIRAppDistributionErrorDomain);
}

@end
