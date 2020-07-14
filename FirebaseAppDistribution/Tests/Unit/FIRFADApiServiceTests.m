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

#import <FirebaseInstallations/FirebaseInstallations.h>
#import "FirebaseAppDistribution/FIRFADApiService+Private.h"

NSString *const kFakeErrorDomain = @"test.failure.domain";

@interface FIRFADApiServiceTests : XCTestCase
@end

@implementation FIRFADApiServiceTests {
  id _mockUrlSession;
  id _mockFIRInstallations;
  id _mockInstallationToken;
  NSString *_mockAuthToken;
  NSString *_mockInstallationId;
  NSDictionary *_mockReleases;
}

- (void)setUp {
  [super setUp];
  _mockUrlSession = OCMClassMock([NSURLSession class]);
  _mockFIRInstallations = OCMClassMock([FIRInstallations class]);
  _mockInstallationToken = OCMClassMock([FIRInstallationsAuthTokenResult class]);
  _mockAuthToken = @"this-is-an-auth-token";
  OCMStub(ClassMethod([_mockUrlSession sharedSession]))
  .andReturn(_mockUrlSession);
  OCMStub(ClassMethod([_mockFIRInstallations installations])).andReturn(_mockFIRInstallations);
  OCMStub(ClassMethod([_mockInstallationToken authToken]))
  .andReturn(_mockAuthToken);

  _mockInstallationId = @"this-id-is-fake-ccccc";
  _mockReleases = @{
    @"releases": @[
        @{
          @"displayVersion": @"1.0.0",
          @"buildVersion": @"111",
          @"releaseNotes":@"This is a release",
          @"downloadURL":@"http://faketyfakefake.download"
        },
        @{
          @"latest": @YES,
          @"displayVersion": @"1.0.1",
          @"buildVersion": @"112",
          @"releaseNotes":@"This is a release too",
          @"downloadURL":@"http://faketyfakefake.download"
        }
    ]};
}

- (void)tearDown {
  [super tearDown];
}

- (void)mockInstallationAuthCompletion:(FIRInstallationsAuthTokenResult *_Nullable)token
                                 error:(NSError *_Nullable) error {
  [OCMStub(ClassMethod([_mockFIRInstallations authTokenWithCompletion:[OCMArg any]])) andDo:^(NSInvocation *invocation) {
    void(^handler)(FIRInstallationsAuthTokenResult *_Nullable authTokenResult, NSError *_Nullable error);
    [invocation getArgument:&handler atIndex:2];
    handler(token, error);
  }];
}

- (void)mockInstallationIdCompletion:(NSString *_Nullable)identifier
                               error:(NSError *_Nullable) error {
  [OCMStub(ClassMethod([_mockFIRInstallations installationIDWithCompletion:[OCMArg any]])) andDo:^(NSInvocation *invocation) {
    void(^handler)(NSString * identifier, NSError *_Nullable error);
    [invocation getArgument:&handler atIndex:2];
    handler(identifier, error);
  }];
}

- (void)mockUrlSessionResponse:(NSDictionary *)dictionary
                      response:(NSURLResponse *)response
                         error:(NSError *)error{
  NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
  [self mockUrlSessionResponseWithData:data response:response error:error];
}

- (void)mockUrlSessionResponseWithData:(NSData *)data
                      response:(NSURLResponse *)response
                         error:(NSError *)error{
  [OCMStub(ClassMethod([_mockUrlSession dataTaskWithRequest:[OCMArg any]
                                          completionHandler:[OCMArg any]])) andDo:^(NSInvocation *invocation) {
    void(^handler)(NSData *data, NSURLResponse *response, NSError *error);
    [invocation getArgument:&handler atIndex:2];
    handler(data, response, error);
  }];
}

- (void)testGenerateAuthTokenWithCompletionSuccess {
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [FIRFADApiService
   generateAuthTokenWithCompletion:^(NSString *_Nullable identifier,
                                                      FIRInstallationsAuthTokenResult *_Nullable authTokenResult,
                                                      NSError *_Nullable error){
    XCTAssertNotNil(authTokenResult);
    XCTAssertNil(error);
    XCTAssertEqual(identifier, self->_mockInstallationId);
    XCTAssertEqual(authTokenResult.authToken, self->_mockAuthToken);
  }];
}

- (void)testGenerateAuthTokenWithCompletionAuthTokenFailure {
  [self mockInstallationAuthCompletion:nil error:[NSError errorWithDomain:kFakeErrorDomain code:1 userInfo:@{}]];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [FIRFADApiService
   generateAuthTokenWithCompletion:^(NSString *_Nullable identifier,
                                     FIRInstallationsAuthTokenResult *_Nullable authTokenResult,
                                     NSError *_Nullable error){
    XCTAssertNil(authTokenResult);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRFADApiTokenGenerationFailure);
  }];
}

- (void)testGenerateAuthTokenWithCompletionIDFailure {
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:nil
                               error:[NSError errorWithDomain:kFakeErrorDomain
                                                         code:1
                                                     userInfo:@{}]];
  [FIRFADApiService
   generateAuthTokenWithCompletion:^(NSString *_Nullable identifier,
                                     FIRInstallationsAuthTokenResult *_Nullable authTokenResult,
                                     NSError *_Nullable error){
    XCTAssertNil(authTokenResult);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRFADApiInstallationIdentifierError);
  }];
}

- (void)testFetchReleasesWithCompletionSuccess {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(200);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases response:fakeResponse error:nil];
  [FIRFADApiService fetchReleasesWithCompletion:^(NSArray * _Nullable releases, NSError * _Nullable error) {
    XCTAssertNil(error);
    XCTAssertNotNil(releases);
    XCTAssertEqual(releases.count, 2);
  }];
}

- (void)testFetchReleasesWithCompletionUnknownFailure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(200);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases
                      response:fakeResponse
                         error:[NSError errorWithDomain:kFakeErrorDomain
                                                   code:1
                                               userInfo:@{}]];
  [FIRFADApiService fetchReleasesWithCompletion:^(NSArray * _Nullable releases, NSError * _Nullable error) {
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
  [self mockUrlSessionResponse:_mockReleases
                      response:fakeResponse
                         error:nil];
  [FIRFADApiService fetchReleasesWithCompletion:^(NSArray * _Nullable releases, NSError * _Nullable error) {
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
  [self mockUrlSessionResponse:_mockReleases
                      response:fakeResponse
                         error:nil];
  [FIRFADApiService fetchReleasesWithCompletion:^(NSArray * _Nullable releases, NSError * _Nullable error) {
    XCTAssertNil(releases);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRFADApiErrorUnauthorized);
  }];
}

- (void)testFetchReleasesWithCompletionUnauthorized403Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(403);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases
                      response:fakeResponse
                         error:nil];
  [FIRFADApiService fetchReleasesWithCompletion:^(NSArray * _Nullable releases, NSError * _Nullable error) {
    XCTAssertNil(releases);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRFADApiErrorUnauthorized);
  }];
}

- (void)testFetchReleasesWithCompletionUnauthorized404Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(404);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases
                      response:fakeResponse
                         error:nil];
  [FIRFADApiService fetchReleasesWithCompletion:^(NSArray * _Nullable releases, NSError * _Nullable error) {
    XCTAssertNil(releases);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRFADApiErrorUnauthorized);
  }];
}

- (void)testFetchReleasesWithCompletionTimeout408Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(408);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases
                      response:fakeResponse
                         error:nil];
  [FIRFADApiService fetchReleasesWithCompletion:^(NSArray * _Nullable releases, NSError * _Nullable error) {
    XCTAssertNil(releases);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRFADApiErrorTimeout);
  }];
}

- (void)testFetchReleasesWithCompletionTimeout504Failure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(504);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases
                      response:fakeResponse
                         error:nil];
  [FIRFADApiService fetchReleasesWithCompletion:^(NSArray * _Nullable releases, NSError * _Nullable error) {
    XCTAssertNil(releases);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRFADApiErrorTimeout);
  }];
}

- (void)testFetchReleasesWithCompletionUnknownStatusCodeFailure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(500);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:_mockReleases
                      response:fakeResponse
                         error:nil];
  [FIRFADApiService fetchReleasesWithCompletion:^(NSArray * _Nullable releases, NSError * _Nullable error) {
    XCTAssertNil(releases);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRApiErrorUnknownFailure);
  }];
}

- (void)testFetchReleasesWithCompletionNoReleasesFoundFailure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(200);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponse:@{@"releases":@[]}
                      response:fakeResponse
                         error:nil];
  [FIRFADApiService fetchReleasesWithCompletion:^(NSArray * _Nullable releases, NSError * _Nullable error) {
    XCTAssertNil(releases);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRFADApiErrorNotFound);
  }];
}

- (void)testFetchReleasesWithCompletionParsingFailure {
  NSHTTPURLResponse *fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
  OCMStub([fakeResponse statusCode]).andReturn(200);
  [self mockInstallationAuthCompletion:_mockInstallationToken error:nil];
  [self mockInstallationIdCompletion:_mockInstallationId error:nil];
  [self mockUrlSessionResponseWithData:[@"malformed{json[data" dataUsingEncoding:NSUTF8StringEncoding]
                      response:fakeResponse
                         error:nil];
  [FIRFADApiService fetchReleasesWithCompletion:^(NSArray * _Nullable releases, NSError * _Nullable error) {
    XCTAssertNil(releases);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRFADApiErrorNotFound);
  }];
}

@end
