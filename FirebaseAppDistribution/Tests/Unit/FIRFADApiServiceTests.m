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

#import "FirebaseAppDistribution/Sources/FIRFADApiService.h"
#import "FirebaseAppDistribution/Sources/FIRFADLogger.h"
#import "FirebaseCore/Internal/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

NSString *const kFakeErrorDomain = @"test.failure.domain";

@interface FIRFADApiServiceTests : XCTestCase
@end

@interface FIRFADApiService (PrivateUnitTesting)

+ (NSString *)tryParseGoogleAPIErrorFromResponse:(NSData *)data;

@end

@implementation FIRFADApiServiceTests {
  id _mockFIRAppClass;
  id _mockURLSession;
  id _mockFIRInstallations;
  id _mockInstallationToken;
  NSString *_mockAuthToken;
  NSString *_mockInstallationId;
  NSString *_mockAPINotEnabledMessage;
  NSDictionary *_mockReleases;
  NSDictionary *_mockAPINotEnabledResponse;
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

  _mockAPINotEnabledMessage =
      @"This is a long message about what's happening. This is a fake message from the Firebase "
      @"App Testers API in project 123456789. This should be logged.";
  _mockAPINotEnabledResponse = @{
    @"error" : @{
      @"code" : @403,
      @"message" : _mockAPINotEnabledMessage,
      @"status" : @"PERMISSION_DENIED",
      @"details" : @[ @{
        @"type" : @"type.fakeapis.com/appdistro.api.Help",
        @"links" : @[ @{
          @"description" : @"this is a short statement about enabling the api",
          @"url" : @"this should be a link"
        } ],
      } ],
    }
  };
}

- (void)tearDown {
  [super tearDown];
  [_mockFIRAppClass stopMocking];
  [_mockFIRInstallations stopMocking];
  [_mockInstallationToken stopMocking];
  [_mockURLSession stopMocking];
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

- (void)verifyInstallationAuthCompletion {
  OCMVerify([_mockFIRInstallations authTokenWithCompletion:[OCMArg isNotNil]]);
}

- (void)rejectInstallationAuthCompletion {
  OCMReject([_mockFIRInstallations authTokenWithCompletion:[OCMArg isNotNil]]);
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

- (void)verifyInstallationIdCompletion {
  OCMVerify([_mockFIRInstallations installationIDWithCompletion:[OCMArg isNotNil]]);
}

- (void)rejectInstallationIdCompletion {
  OCMReject([_mockFIRInstallations installationIDWithCompletion:[OCMArg isNotNil]]);
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

- (void)verifyUrlSessionResponseWithData {
  OCMVerify([_mockURLSession dataTaskWithRequest:[OCMArg isNotNil]
                               completionHandler:[OCMArg isNotNil]]);
}

- (void)rejectUrlSessionResponseWithData {
  OCMReject([_mockURLSession dataTaskWithRequest:[OCMArg isNotNil]
                               completionHandler:[OCMArg isNotNil]]);
}

- (void)testTryParseGoogleAPIErrorFromResponseSuccess {
  NSData *data = [NSJSONSerialization dataWithJSONObject:_mockAPINotEnabledResponse
                                                 options:0
                                                   error:nil];
  NSString *message = [FIRFADApiService tryParseGoogleAPIErrorFromResponse:data];
  XCTAssertTrue([message isEqualToString:_mockAPINotEnabledMessage]);
}

- (void)testTryParseGoogleAPIErrorFromNilResponse {
  NSString *message = [FIRFADApiService tryParseGoogleAPIErrorFromResponse:nil];
  XCTAssertTrue([message isEqualToString:@"No data in response."]);
}

- (void)testTryParseGoogleAPIErrorFromResponseParseFailure {
  NSData *data = [@"malformed{json[data" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *message = [FIRFADApiService tryParseGoogleAPIErrorFromResponse:data];
  XCTAssertTrue(
      [message isEqualToString:@"Could not parse additional details about this API error."]);
}

- (void)testTryParseGoogleAPIErrorFromResponseNoErrorFailure {
  NSDictionary *errorDictionary = @{@"message" : @"This has no subdict"};
  NSData *data = [NSJSONSerialization dataWithJSONObject:errorDictionary options:0 error:nil];
  NSString *message = [FIRFADApiService tryParseGoogleAPIErrorFromResponse:data];
  XCTAssertTrue(
      [message isEqualToString:@"Could not parse additional details about this API error."]);
}

- (void)testTryParseGoogleAPIErrorFromResponseNoMessageFailure {
  NSDictionary *errorDictionary = @{@"error" : @{@"status" : @"This has no message"}};
  NSData *data = [NSJSONSerialization dataWithJSONObject:errorDictionary options:0 error:nil];
  NSString *message = [FIRFADApiService tryParseGoogleAPIErrorFromResponse:data];
  XCTAssertTrue(
      [message isEqualToString:@"Could not parse additional details about this API error."]);
}

- (void)testGenerateAuthTokenWithCompletionSuccess {
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Generate auth token succeeds."];

  [FIRFADApiService
      generateAuthTokenWithCompletion:^(NSString *_Nullable identifier,
                                        FIRInstallationsAuthTokenResult *_Nullable authTokenResult,
                                        NSError *_Nullable error) {
        XCTAssertNotNil(authTokenResult);
        XCTAssertNotNil(identifier);
        XCTAssertNil(error);
        XCTAssertTrue([identifier isEqualToString:self->_mockInstallationId]);
        XCTAssertTrue([[authTokenResult authToken] isEqualToString:self->_mockAuthToken]);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self verifyInstallationIdCompletion];
}

- (void)testGenerateAuthTokenWithCompletionAuthTokenFailure {
  [self mockInstallationAuthCompletion:nil
                                 error:[NSError errorWithDomain:kFakeErrorDomain
                                                           code:1
                                                       userInfo:@{}]];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Generate auth token fails to generate auth token."];

  [FIRFADApiService
      generateAuthTokenWithCompletion:^(NSString *_Nullable identifier,
                                        FIRInstallationsAuthTokenResult *_Nullable authTokenResult,
                                        NSError *_Nullable error) {
        XCTAssertNil(identifier);
        XCTAssertNil(authTokenResult);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, FIRFADApiTokenGenerationFailure);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self rejectInstallationIdCompletion];
}

- (void)testGenerateAuthTokenWithCompletionIDFailure {
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:nil
                               error:[NSError errorWithDomain:kFakeErrorDomain
                                                         code:1
                                                     userInfo:@{}]];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Generate auth token fails to find ID."];

  [FIRFADApiService
      generateAuthTokenWithCompletion:^(NSString *_Nullable identifier,
                                        FIRInstallationsAuthTokenResult *_Nullable authTokenResult,
                                        NSError *_Nullable error) {
        XCTAssertNil(identifier);
        XCTAssertNil(authTokenResult);
        XCTAssertNotNil(error);
        XCTAssertEqual([error code], FIRFADApiInstallationIdentifierError);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self verifyInstallationIdCompletion];
}

- (void)testFetchReleasesWithCompletionSuccess {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(200);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases succeeds with two releases."];

  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(releases);
        XCTAssertEqual([releases count], 2);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self verifyInstallationIdCompletion];
  [self verifyUrlSessionResponseWithData];
  OCMVerify([fakeResponse statusCode]);
}

- (void)testFetchReleasesWithCompletionUnknownFailure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(200);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases
                      response:fakeResponse
                         error:[NSError errorWithDomain:kFakeErrorDomain code:1 userInfo:@{}]];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases fails with unknown error."];

  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        XCTAssertNil(releases);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, FIRApiErrorUnknownFailure);
        [expectation fulfill];
      }];
  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self verifyInstallationIdCompletion];
  [self verifyUrlSessionResponseWithData];
  OCMVerify([fakeResponse statusCode]);
}

- (void)testFetchReleasesWithCompletionUnauthenticatedFailure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(401);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases fails with unknown error."];

  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        XCTAssertNil(releases);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, FIRFADApiErrorUnauthenticated);
        [expectation fulfill];
      }];
  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self verifyInstallationIdCompletion];
  [self verifyUrlSessionResponseWithData];
  OCMVerify([fakeResponse statusCode]);
}

- (void)testFetchReleasesWithCompletionUnauthorized400Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(400);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with a 400."];

  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        XCTAssertNil(releases);
        XCTAssertNotNil(error);
        XCTAssertEqual([error code], FIRFADApiErrorUnauthorized);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self verifyInstallationIdCompletion];
  [self verifyUrlSessionResponseWithData];
  OCMVerify([fakeResponse statusCode]);
}

- (void)testFetchReleasesWithCompletionUnauthorized403Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(403);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockAPINotEnabledResponse response:fakeResponse error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with a 403."];

  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        XCTAssertNil(releases);
        XCTAssertNotNil(error);
        XCTAssertEqual([error code], FIRFADApiErrorUnauthorized);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self verifyInstallationIdCompletion];
  [self verifyUrlSessionResponseWithData];
  OCMVerify([fakeResponse statusCode]);
}

- (void)testFetchReleasesWithCompletionUnauthorized404Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(404);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with a 404."];

  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        XCTAssertNil(releases);
        XCTAssertNotNil(error);
        XCTAssertEqual([error code], FIRFADApiErrorUnauthorized);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self verifyInstallationIdCompletion];
  [self verifyUrlSessionResponseWithData];
  OCMVerify([fakeResponse statusCode]);
}

- (void)testFetchReleasesWithCompletionTimeout408Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(408);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with 408."];

  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        XCTAssertNil(releases);
        XCTAssertNotNil(error);
        XCTAssertEqual([error code], FIRFADApiErrorTimeout);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self verifyInstallationIdCompletion];
  [self verifyUrlSessionResponseWithData];
  OCMVerify([fakeResponse statusCode]);
}

- (void)testFetchReleasesWithCompletionTimeout504Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(504);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with a 504."];

  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        XCTAssertNil(releases);
        XCTAssertNotNil(error);
        XCTAssertEqual([error code], FIRFADApiErrorTimeout);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self verifyInstallationIdCompletion];
  [self verifyUrlSessionResponseWithData];
  OCMVerify([fakeResponse statusCode]);
}

- (void)testFetchReleasesWithCompletionUnknownStatusCodeFailure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(500);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with a 500."];

  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        XCTAssertNil(releases);
        XCTAssertNotNil(error);
        XCTAssertEqual([error code], FIRApiErrorUnknownFailure);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self verifyInstallationIdCompletion];
  [self verifyUrlSessionResponseWithData];
  OCMVerify([fakeResponse statusCode]);
}

- (void)testFetchReleasesWithCompletionNoReleasesFoundSuccess {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(200);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:@{@"releases" : @[]} response:fakeResponse error:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Fetch releases rejects with a not found exception."];

  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        XCTAssertNotNil(releases);
        XCTAssertNil(error);
        XCTAssertEqual([releases count], 0);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self verifyInstallationIdCompletion];
  [self verifyUrlSessionResponseWithData];
  OCMVerify([fakeResponse statusCode]);
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

  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        XCTAssertNil(releases);
        XCTAssertNotNil(error);
        XCTAssertEqual([error code], FIRApiErrorParseFailure);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
  [self verifyInstallationAuthCompletion];
  [self verifyInstallationIdCompletion];
  [self verifyUrlSessionResponseWithData];
  OCMVerify([fakeResponse statusCode]);
}

@end
