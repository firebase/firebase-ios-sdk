//
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

#import "FirebaseAppDistribution/FIRFADApiService+Private.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

NSString *const kFakeErrorDomain = @"test.failure.domain";

@interface FIRFADApiServiceTests : XCTestCase
@end

@implementation FIRFADApiServiceTests {
  id _mockFIRAppClass;
  id _mockURLSession;
  id _mockFIRInstallations;
  id _mockInstallationToken;
  NSString *_mockAuthToken;
  NSString *_mockInstallationId;
  NSDictionary *_mockReleases;
}

- (void)setUp {
  [super setUp];
  _mockFIRAppClass = OCMClassMock([FIRApp class]);
  _mockURLSession = OCMClassMock([NSURLSession class]);
  _mockFIRInstallations = OCMClassMock([FIRInstallations class]);
  _mockInstallationToken = OCMClassMock([FIRInstallationsAuthTokenResult class]);
  _mockAuthToken = @"this-is-an-auth-token";
  OCMStub([_mockFIRAppClass defaultApp]).andReturn(_mockFIRAppClass);
  OCMStub([_mockURLSession sharedSession]).andReturn(_mockURLSession);
  OCMStub([_mockFIRInstallations installations]).andReturn(_mockFIRInstallations);
  OCMStub([_mockInstallationToken authToken]).andReturn(_mockAuthToken);

  _mockInstallationId = @"this-id-is-fake-ccccc";
  _mockReleases = @{
    @"releases" : @[
      @{
        @"displayVersion" : @"1.0.0",
        @"buildVersion" : @"111",
        @"releaseNotes" : @"This is a release",
        @"downloadURL" : @"http://faketyfakefake.download"
      },
      @{
        @"latest" : @YES,
        @"displayVersion" : @"1.0.1",
        @"buildVersion" : @"112",
        @"releaseNotes" : @"This is a release too",
        @"downloadURL" : @"http://faketyfakefake.download"
      }
    ]
  };
}

- (void)tearDown {
  [super tearDown];
}

- (void)mockInstallationAuthCompletion:(FIRInstallationsAuthTokenResult *_Nullable)token
                                 error:(NSError *_Nullable)error {
  [OCMStub([_mockFIRInstallations authTokenWithCompletion:OCMOCK_ANY])
      andDo:^(NSInvocation *invocation) {
        void (^handler)(FIRInstallationsAuthTokenResult *_Nullable authTokenResult,
                        NSError *_Nullable error);
        [invocation getArgument:&handler atIndex:2];
        handler(token, error);
      }];
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

- (void)mockUrlSessionResponse:(NSDictionary *)dictionary
                      response:(NSURLResponse *)response
                         error:(NSError *)error {
  NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
  [self mockUrlSessionResponseWithData:data response:response error:error];
}

- (void)mockUrlSessionResponseWithData:(NSData *)data
                              response:(NSURLResponse *)response
                                 error:(NSError *)error {
  [OCMStub([_mockURLSession dataTaskWithRequest:[OCMArg any]
                              completionHandler:[OCMArg any]]) andDo:^(NSInvocation *invocation) {
    void (^handler)(NSData *data, NSURLResponse *response, NSError *error);
    [invocation getArgument:&handler atIndex:3];
    handler(data, response, error);
  }];
}

- (void)testGenerateAuthTokenWithCompletionSuccess {
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Generate auth token succeeds."];

  __block FIRInstallationsAuthTokenResult *returnedAuthTokenResult;
  __block NSString *returnedID;
  __block NSError *returnedError;
  [FIRFADApiService
      generateAuthTokenWithCompletion:^(NSString *_Nullable identifier,
                                        FIRInstallationsAuthTokenResult *_Nullable authTokenResult,
                                        NSError *_Nullable error) {
        returnedID = identifier;
        returnedAuthTokenResult = authTokenResult;
        returnedError = error;
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertNotNil(returnedAuthTokenResult);
  XCTAssertNotNil(returnedID);
  XCTAssertNil(returnedError);
  XCTAssertEqual(returnedID, self->_mockInstallationId);
  XCTAssertEqual(returnedAuthTokenResult.authToken, self->_mockAuthToken);
}

- (void)testGenerateAuthTokenWithCompletionAuthTokenFailure {
  [self mockInstallationAuthCompletion:nil
                                 error:[NSError errorWithDomain:kFakeErrorDomain
                                                           code:1
                                                       userInfo:@{}]];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Generate auth token fails to generate auth token."];

  __block FIRInstallationsAuthTokenResult *returnedAuthTokenResult;
  __block NSString *returnedID;
  __block NSError *returnedError;
  [FIRFADApiService
      generateAuthTokenWithCompletion:^(NSString *_Nullable identifier,
                                        FIRInstallationsAuthTokenResult *_Nullable authTokenResult,
                                        NSError *_Nullable error) {
        returnedID = identifier;
        returnedAuthTokenResult = authTokenResult;
        returnedError = error;
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertNil(returnedID);
  XCTAssertNil(returnedAuthTokenResult);
  XCTAssertNotNil(returnedError);
  XCTAssertEqual(returnedError.code, FIRFADApiTokenGenerationFailure);
}

- (void)testGenerateAuthTokenWithCompletionIDFailure {
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:nil
                               error:[NSError errorWithDomain:kFakeErrorDomain
                                                         code:1
                                                     userInfo:@{}]];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Generate auth token fails to find ID."];

  __block FIRInstallationsAuthTokenResult *returnedAuthTokenResult;
  __block NSString *returnedID;
  __block NSError *returnedError;
  [FIRFADApiService
      generateAuthTokenWithCompletion:^(NSString *_Nullable identifier,
                                        FIRInstallationsAuthTokenResult *_Nullable authTokenResult,
                                        NSError *_Nullable error) {
        returnedID = identifier;
        returnedAuthTokenResult = authTokenResult;
        returnedError = error;
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertNil(returnedID);
  XCTAssertNil(returnedAuthTokenResult);
  XCTAssertNotNil(returnedError);
  XCTAssertEqual(returnedError.code, FIRFADApiInstallationIdentifierError);
}

- (void)testFetchReleasesWithCompletionSuccess {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(200);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases succeeds with two releases."];

  __block NSArray *returnedReleases;
  __block NSError *returnedError;
  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        returnedReleases = releases;
        returnedError = error;
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertNil(returnedError);
  XCTAssertNotNil(returnedReleases);
  XCTAssertEqual(returnedReleases.count, 2);
}

- (void)testFetchReleasesWithCompletionUnknownFailure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(200);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases
                      response:fakeResponse
                         error:[NSError errorWithDomain:kFakeErrorDomain code:1 userInfo:@{}]];
  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        XCTAssertNil(releases);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, FIRApiErrorUnknownFailure);
      }];
}

- (void)testFetchReleasesWithCompletionUnauthenticatedFailure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(401);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];
  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        XCTAssertNil(releases);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, FIRFADApiErrorUnauthenticated);
      }];
}

- (void)testFetchReleasesWithCompletionUnauthorized400Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(400);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with a 400."];

  __block NSArray *returnedReleases;
  __block NSError *returnedError;
  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        returnedReleases = releases;
        returnedError = error;
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertNil(returnedReleases);
  XCTAssertNotNil(returnedError);
  XCTAssertEqual(returnedError.code, FIRFADApiErrorUnauthorized);
}

- (void)testFetchReleasesWithCompletionUnauthorized403Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(403);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with a 403."];

  __block NSArray *returnedReleases;
  __block NSError *returnedError;
  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        returnedReleases = releases;
        returnedError = error;
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertNil(returnedReleases);
  XCTAssertNotNil(returnedError);
  XCTAssertEqual(returnedError.code, FIRFADApiErrorUnauthorized);
}

- (void)testFetchReleasesWithCompletionUnauthorized404Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(404);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with a 404."];

  __block NSArray *returnedReleases;
  __block NSError *returnedError;
  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        returnedReleases = releases;
        returnedError = error;
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertNil(returnedReleases);
  XCTAssertNotNil(returnedError);
  XCTAssertEqual(returnedError.code, FIRFADApiErrorUnauthorized);
}

- (void)testFetchReleasesWithCompletionTimeout408Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(408);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with 408."];

  __block NSArray *returnedReleases;
  __block NSError *returnedError;
  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        returnedReleases = releases;
        returnedError = error;
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertNil(returnedReleases);
  XCTAssertNotNil(returnedError);
  XCTAssertEqual(returnedError.code, FIRFADApiErrorTimeout);
}

- (void)testFetchReleasesWithCompletionTimeout504Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(504);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with a 504."];

  __block NSArray *returnedReleases;
  __block NSError *returnedError;
  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        returnedReleases = releases;
        returnedError = error;
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertNil(returnedReleases);
  XCTAssertNotNil(returnedError);
  XCTAssertEqual(returnedError.code, FIRFADApiErrorTimeout);
}

- (void)testFetchReleasesWithCompletionUnknownStatusCodeFailure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(500);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with a 500."];

  __block NSArray *returnedReleases;
  __block NSError *returnedError;
  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        returnedReleases = releases;
        returnedError = error;
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertNil(returnedReleases);
  XCTAssertNotNil(returnedError);
  XCTAssertEqual(returnedError.code, FIRApiErrorUnknownFailure);
}

- (void)testFetchReleasesWithCompletionNoReleasesFoundFailure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(200);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:@{@"releases" : @[]} response:fakeResponse error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with a not found exception."];

  __block NSArray *returnedReleases;
  __block NSError *returnedError;
  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        returnedReleases = releases;
        returnedError = error;
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertNil(returnedReleases);
  XCTAssertNotNil(returnedError);
  XCTAssertEqual(returnedError.code, FIRFADApiErrorNotFound);
}

- (void)testFetchReleasesWithCompletionParsingFailure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(200);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self
      mockUrlSessionResponseWithData:[@"malformed{json[data" dataUsingEncoding:NSUTF8StringEncoding]
                            response:fakeResponse
                               error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with a parsing failure."];

  __block NSArray *returnedReleases;
  __block NSError *returnedError;
  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        returnedReleases = releases;
        returnedError = error;
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  XCTAssertNil(returnedReleases);
  XCTAssertNotNil(returnedError);
  XCTAssertEqual(returnedError.code, FIRApiErrorParseFailure);
}

@end
