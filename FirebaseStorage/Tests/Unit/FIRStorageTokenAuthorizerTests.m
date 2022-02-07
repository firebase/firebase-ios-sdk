// Copyright 2017 Google
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

#import "FirebaseStorage/Tests/Unit/FIRStorageTestHelpers.h"

#import "FirebaseCore/Internal/FirebaseCoreInternal.h"

#import "SharedTestUtilities/AppCheckFake/FIRAppCheckFake.h"
#import "SharedTestUtilities/AppCheckFake/FIRAppCheckTokenResultFake.h"
#import "SharedTestUtilities/FIRAuthInteropFake.h"

@interface FIRStorageTokenAuthorizerTests : XCTestCase

@property(strong, nonatomic) GTMSessionFetcher *fetcher;
@property(strong, nonatomic) GTMSessionFetcherService *fetcherService;
@property(strong, nonatomic) FIRAuthInteropFake *auth;
@property(strong, nonatomic) FIRAppCheckFake *appCheck;
@property(strong, nonatomic) FIRAppCheckTokenResultFake *appCheckTokenSuccess;
@property(strong, nonatomic) FIRAppCheckTokenResultFake *appCheckTokenError;

@end

@implementation FIRStorageTokenAuthorizerTests

- (void)setUp {
  [super setUp];

  self.appCheckTokenSuccess = [[FIRAppCheckTokenResultFake alloc] initWithToken:@"token" error:nil];
  self.appCheckTokenError = [[FIRAppCheckTokenResultFake alloc]
      initWithToken:@"dummy token"
              error:[NSError errorWithDomain:@"testAppCheckError" code:-1 userInfo:nil]];

  NSURLRequest *fetchRequest = [NSURLRequest requestWithURL:[FIRStorageTestHelpers objectURL]];
  self.fetcher = [GTMSessionFetcher fetcherWithRequest:fetchRequest];

  self.fetcherService = [[GTMSessionFetcherService alloc] init];
  self.auth = [[FIRAuthInteropFake alloc] initWithToken:kFIRStorageTestAuthToken
                                                 userID:nil
                                                  error:nil];
  self.appCheck = [[FIRAppCheckFake alloc] init];
  self.fetcher.authorizer =
      [[FIRStorageTokenAuthorizer alloc] initWithGoogleAppID:@"dummyAppID"
                                              fetcherService:self.fetcherService
                                                authProvider:self.auth
                                                    appCheck:self.appCheck];
}

- (void)tearDown {
  self.fetcher = nil;
  self.fetcherService = nil;
  self.auth = nil;
  self.appCheck = nil;
  self.appCheckTokenSuccess = nil;
  [super tearDown];
}

- (void)testSuccessfulAuth {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testSuccessfulAuth"];

  [self setFetcherTestBlockWithStatusCode:200
                          validationBlock:^(GTMSessionFetcher *fetcher) {
                            XCTAssertTrue([fetcher.authorizer isAuthorizedRequest:fetcher.request]);
                          }];

  [self.fetcher
      beginFetchWithCompletionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
        NSDictionary<NSString *, NSString *> *headers = self.fetcher.request.allHTTPHeaderFields;
        XCTAssertEqualObjects(headers[@"Authorization"], [self validAuthToken]);
        [expectation fulfill];
      }];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testUnsuccessfulAuth {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testUnsuccessfulAuth"];

  NSError *authError = [NSError errorWithDomain:FIRStorageErrorDomain
                                           code:FIRStorageErrorCodeUnauthenticated
                                       userInfo:nil];
  FIRAuthInteropFake *failedAuth = [[FIRAuthInteropFake alloc] initWithToken:nil
                                                                      userID:nil
                                                                       error:authError];
  self.fetcher.authorizer =
      [[FIRStorageTokenAuthorizer alloc] initWithGoogleAppID:@"dummyAppID"
                                              fetcherService:self.fetcherService
                                                authProvider:failedAuth
                                                    appCheck:nil];

  [self
      setFetcherTestBlockWithStatusCode:401
                        validationBlock:^(GTMSessionFetcher *fetcher) {
                          XCTAssertFalse([fetcher.authorizer isAuthorizedRequest:fetcher.request]);
                        }];

  [self.fetcher
      beginFetchWithCompletionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
        NSDictionary<NSString *, NSString *> *headers = self.fetcher.request.allHTTPHeaderFields;
        NSString *authHeader = [headers objectForKey:@"Authorization"];
        XCTAssertNil(authHeader);
        XCTAssertEqualObjects(error.domain, FIRStorageErrorDomain);
        XCTAssertEqual(error.code, FIRStorageErrorCodeUnauthenticated);
        [expectation fulfill];
      }];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testSuccessfulUnauthenticatedAuth {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testSuccessfulUnauthenticatedAuth"];

  // Simulate Auth not being included at all.
  self.fetcher.authorizer =
      [[FIRStorageTokenAuthorizer alloc] initWithGoogleAppID:@"dummyAppID"
                                              fetcherService:self.fetcherService
                                                authProvider:nil
                                                    appCheck:nil];

  [self
      setFetcherTestBlockWithStatusCode:200
                        validationBlock:^(GTMSessionFetcher *fetcher) {
                          XCTAssertFalse([fetcher.authorizer isAuthorizedRequest:fetcher.request]);
                        }];

  [self.fetcher
      beginFetchWithCompletionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
        NSDictionary<NSString *, NSString *> *headers = self.fetcher.request.allHTTPHeaderFields;
        NSString *authHeader = [headers objectForKey:@"Authorization"];
        XCTAssertNil(authHeader);
        XCTAssertNil(error);
        [expectation fulfill];
      }];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testSuccessfulAppCheckNoAuth {
  self.appCheck.tokenResult = self.appCheckTokenSuccess;
  self.fetcher.authorizer =
      [[FIRStorageTokenAuthorizer alloc] initWithGoogleAppID:@"dummyAppID"
                                              fetcherService:self.fetcherService
                                                authProvider:nil
                                                    appCheck:self.appCheck];

  [self
      setFetcherTestBlockWithStatusCode:200
                        validationBlock:^(GTMSessionFetcher *fetcher) {
                          XCTAssertFalse([fetcher.authorizer isAuthorizedRequest:fetcher.request]);
                        }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"fetchCompletion"];

  [self.fetcher
      beginFetchWithCompletionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
        NSDictionary<NSString *, NSString *> *headers = self.fetcher.request.allHTTPHeaderFields;
        XCTAssertEqualObjects(headers[@"X-Firebase-AppCheck"], self.appCheckTokenSuccess.token);
        [expectation fulfill];
      }];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testSuccessfulAppCheckAndAuth {
  self.appCheck.tokenResult = self.appCheckTokenSuccess;

  [self setFetcherTestBlockWithStatusCode:200
                          validationBlock:^(GTMSessionFetcher *fetcher) {
                            XCTAssertTrue([fetcher.authorizer isAuthorizedRequest:fetcher.request]);
                          }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"fetchCompletion"];

  [self.fetcher
      beginFetchWithCompletionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
        NSDictionary<NSString *, NSString *> *headers = self.fetcher.request.allHTTPHeaderFields;
        XCTAssertEqualObjects(headers[@"Authorization"], [self validAuthToken]);
        XCTAssertEqualObjects(headers[@"X-Firebase-AppCheck"], self.appCheckTokenSuccess.token);
        [expectation fulfill];
      }];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testAppCheckError {
  self.appCheck.tokenResult = self.appCheckTokenError;

  [self setFetcherTestBlockWithStatusCode:200
                          validationBlock:^(GTMSessionFetcher *fetcher) {
                            XCTAssertTrue([fetcher.authorizer isAuthorizedRequest:fetcher.request]);
                          }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"fetchCompletion"];

  [self.fetcher
      beginFetchWithCompletionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
        NSDictionary<NSString *, NSString *> *headers = self.fetcher.request.allHTTPHeaderFields;
        XCTAssertEqualObjects(headers[@"Authorization"], [self validAuthToken]);
        XCTAssertEqualObjects(headers[@"X-Firebase-AppCheck"], self.appCheckTokenError.token);
        [expectation fulfill];
      }];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testIsAuthorizing {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testIsAuthorizing"];

  [self
      setFetcherTestBlockWithStatusCode:200
                        validationBlock:^(GTMSessionFetcher *fetcher) {
                          XCTAssertFalse([fetcher.authorizer isAuthorizingRequest:fetcher.request]);
                        }];

  [self.fetcher
      beginFetchWithCompletionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
        [expectation fulfill];
      }];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testStopAuthorizingNoop {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testStopAuthorizingNoop"];

  [self setFetcherTestBlockWithStatusCode:200
                          validationBlock:^(GTMSessionFetcher *fetcher) {
                            // Since both of these are noops, we expect that invoking them
                            // will still result in successful authentication
                            [fetcher.authorizer stopAuthorization];
                            [fetcher.authorizer stopAuthorizationForRequest:fetcher.request];
                          }];

  [self.fetcher
      beginFetchWithCompletionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
        NSDictionary<NSString *, NSString *> *headers = self.fetcher.request.allHTTPHeaderFields;
        NSString *authHeader = [headers objectForKey:@"Authorization"];
        NSString *firebaseToken =
            [NSString stringWithFormat:kFIRStorageAuthTokenFormat, kFIRStorageTestAuthToken];
        XCTAssertEqualObjects(authHeader, firebaseToken);
        [expectation fulfill];
      }];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testEmail {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testEmail"];

  [self setFetcherTestBlockWithStatusCode:200
                          validationBlock:^(GTMSessionFetcher *fetcher) {
                            XCTAssertNil([fetcher.authorizer userEmail]);
                          }];

  [self.fetcher
      beginFetchWithCompletionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
        [expectation fulfill];
      }];

  [FIRStorageTestHelpers waitForExpectation:self];
}

#pragma mark - Helpers

- (void)setFetcherTestBlockWithStatusCode:(NSUInteger)httpStatusCode
                          validationBlock:(void (^)(GTMSessionFetcher *fetcher))validationBlock {
  self.fetcher.testBlock = ^(GTMSessionFetcher *fetcher, GTMSessionFetcherTestResponse response) {
    validationBlock(fetcher);

    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:fetcher.request.URL
                                                                  statusCode:httpStatusCode
                                                                 HTTPVersion:kHTTPVersion
                                                                headerFields:nil];
    response(httpResponse, nil, nil);
  };
}

- (NSString *)validAuthToken {
  return [NSString stringWithFormat:kFIRStorageAuthTokenFormat, kFIRStorageTestAuthToken];
}

@end
