// Copyright 2019 Google
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

#import "FirebaseStorageInternal/Sources/FIRStorageListTask.h"
#import "FirebaseStorageInternal/Tests/Unit/FIRStorageTestHelpers.h"

NSString *kListPath = @"object";

@interface FIRStorageListTests : XCTestCase

@property(strong, nonatomic) GTMSessionFetcherService *fetcherService;
@property(nonatomic) dispatch_queue_t dispatchQueue;
@property(strong, nonatomic) FIRIMPLStorage *storage;
@property(strong, nonatomic) id mockApp;

@end

@implementation FIRStorageListTests

- (void)setUp {
  [super setUp];

  self.fetcherService = [[GTMSessionFetcherService alloc] init];
  self.fetcherService.authorizer =
      [[FIRStorageTokenAuthorizer alloc] initWithGoogleAppID:@"dummyAppID"
                                              fetcherService:self.fetcherService
                                                authProvider:nil
                                                    appCheck:nil];

  self.dispatchQueue = dispatch_queue_create("Test dispatch queue", DISPATCH_QUEUE_SERIAL);
  self.storage = [FIRStorageTestHelpers storageWithMockedApp];
}

- (void)tearDown {
  self.fetcherService = nil;
  self.storage = nil;
  self.mockApp = nil;
  [super tearDown];
}

- (void)testValidatesInput {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testValidatesInput"];
  expectation.expectedFulfillmentCount = 4;

  FIRStorageVoidListError errorBlock = ^(FIRIMPLStorageListResult *result, NSError *error) {
    XCTAssertNil(result);
    XCTAssertNotNil(error);

    XCTAssertEqualObjects(error.domain, @"FIRStorageErrorDomain");
    XCTAssertEqual(error.code, FIRIMPLStorageErrorCodeInvalidArgument);

    [expectation fulfill];
  };

  FIRIMPLStorageReference *ref = [self.storage referenceWithPath:kListPath];
  [ref listWithMaxResults:0 completion:errorBlock];
  [ref listWithMaxResults:1001 completion:errorBlock];
  [ref listWithMaxResults:0 pageToken:@"foo" completion:errorBlock];
  [ref listWithMaxResults:1001 pageToken:@"foo" completion:errorBlock];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testListAllCallbackOnlyCalledOnce {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testListAllCallbackOnlyCalledOnce"];
  expectation.expectedFulfillmentCount = 1;

  FIRStorageVoidListError errorBlock = ^(FIRIMPLStorageListResult *result, NSError *error) {
    XCTAssertNil(result);
    XCTAssertNotNil(error);

    XCTAssertEqualObjects(error.domain, @"FIRStorageErrorDomain");
    XCTAssertEqual(error.code, FIRIMPLStorageErrorCodeUnknown);

    [expectation fulfill];
  };

  FIRIMPLStorageReference *ref = [self.storage referenceWithPath:kListPath];
  [ref listAllWithCompletion:errorBlock];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testDefaultList {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testDefaultList"];
  NSURL *expectedURL = [NSURL
      URLWithString:
          @"https://firebasestorage.googleapis.com:443/v0/b/bucket/o?prefix=object/&delimiter=/"];

  self.fetcherService.testBlock =
      ^(GTMSessionFetcher *fetcher, GTMSessionFetcherTestResponse response) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        XCTAssertEqualObjects(fetcher.request.URL, expectedURL);  // Implicitly retains self
        XCTAssertEqualObjects(fetcher.request.HTTPMethod, @"GET");
#pragma clang diagnostic pop
        NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:fetcher.request.URL
                                                                      statusCode:200
                                                                     HTTPVersion:kHTTPVersion
                                                                    headerFields:nil];
        response(httpResponse, nil, nil);
      };

  FIRIMPLStorageReference *ref = [self.storage referenceWithPath:kListPath];
  FIRStorageListTask *task = [[FIRStorageListTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               pageSize:nil
      previousPageToken:nil
             completion:^(FIRIMPLStorageListResult *result, NSError *error) {
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testDefaultListWithEmulator {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testDefaultListWithEmulator"];

  [self.storage useEmulatorWithHost:@"localhost" port:8080];
  self.fetcherService.allowLocalhostRequest = YES;
  self.fetcherService.testBlock = [FIRStorageTestHelpers
      successBlockWithURL:@"http://localhost:8080/v0/b/bucket/o?prefix=object/&delimiter=/"];

  FIRIMPLStorageReference *ref = [self.storage referenceWithPath:kListPath];
  FIRStorageListTask *task = [[FIRStorageListTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               pageSize:nil
      previousPageToken:nil
             completion:^(FIRIMPLStorageListResult *result, NSError *error) {
               XCTAssertNil(error);
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testListWithPageSizeAndPageToken {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testListWithPageSizeAndPageToken"];
  NSURL *expectedURL =
      [NSURL URLWithString:@"https://firebasestorage.googleapis.com:443/v0/b/bucket/"
                           @"o?maxResults=42&delimiter=/&prefix=object/&pageToken=foo"];

  self.fetcherService.testBlock =
      ^(GTMSessionFetcher *fetcher, GTMSessionFetcherTestResponse response) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        XCTAssertEqualObjects(fetcher.request.URL, expectedURL);  // Implicitly retains self
        XCTAssertEqualObjects(fetcher.request.HTTPMethod, @"GET");
#pragma clang diagnostic pop
        NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:fetcher.request.URL
                                                                      statusCode:200
                                                                     HTTPVersion:kHTTPVersion
                                                                    headerFields:nil];
        response(httpResponse, nil, nil);
      };

  FIRIMPLStorageReference *ref = [self.storage referenceWithPath:kListPath];
  FIRStorageListTask *task = [[FIRStorageListTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               pageSize:@(42)
      previousPageToken:@"foo"
             completion:^(FIRIMPLStorageListResult *result, NSError *error) {
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testPercentEncodesPlusToken {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testPercentEncodesPlusToken"];
  NSURL *expectedURL =
      [NSURL URLWithString:@"https://firebasestorage.googleapis.com:443/v0/b/bucket/"
                           @"o?prefix=%2Bfoo/&delimiter=/"];

  self.fetcherService.testBlock =
      ^(GTMSessionFetcher *fetcher, GTMSessionFetcherTestResponse response) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        XCTAssertEqualObjects(fetcher.request.URL, expectedURL);  // Implicitly retains self
        XCTAssertEqualObjects(fetcher.request.HTTPMethod, @"GET");
#pragma clang diagnostic pop
        NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:fetcher.request.URL
                                                                      statusCode:200
                                                                     HTTPVersion:kHTTPVersion
                                                                    headerFields:nil];
        response(httpResponse, nil, nil);
      };

  FIRIMPLStorageReference *ref = [self.storage referenceWithPath:@"+foo"];
  FIRStorageListTask *task = [[FIRStorageListTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               pageSize:nil
      previousPageToken:nil
             completion:^(FIRIMPLStorageListResult *result, NSError *error) {
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testListWithResponse {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testListWithErrorResponse"];

  NSString *jsonString = @"{\n"
                          "  \"prefixes\": [\n"
                          "    \"object/prefixWithoutSlash\",\n"
                          "    \"object/prefixWithSlash/\"\n"
                          "  ],\n"
                          "  \"items\": [\n"
                          "    {\n"
                          "      \"name\": \"object/data1.dat\",\n"
                          "      \"bucket\": \"bucket.appspot.com\"\n"
                          "    },\n"
                          "    {\n"
                          "      \"name\": \"object/data2.dat\",\n"
                          "      \"bucket\": \"bucket.appspot.com\"\n"
                          "    },\n"
                          "  ],\n"
                          "  \"nextPageToken\": \"foo\""
                          "}";
  NSData *responseData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];

  self.fetcherService.testBlock =
      ^(GTMSessionFetcher *fetcher, GTMSessionFetcherTestResponse response) {
        NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:fetcher.request.URL
                                                                      statusCode:200
                                                                     HTTPVersion:kHTTPVersion

                                                                    headerFields:nil];
        response(httpResponse, responseData, nil);
      };

  FIRIMPLStorageReference *ref = [self.storage referenceWithPath:kListPath];
  FIRStorageListTask *task = [[FIRStorageListTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               pageSize:nil
      previousPageToken:nil
             completion:^(FIRIMPLStorageListResult *result, NSError *error) {
               XCTAssertNotNil(result);
               XCTAssertNil(error);

               XCTAssertEqualObjects(result.items,
                                     (@[ [ref child:@"data1.dat"], [ref child:@"data2.dat"] ]));
               XCTAssertEqualObjects(
                   result.prefixes, (@[
                     [ref child:@"prefixWithoutSlash"],
                     [ref child:@"prefixWithSlash"]  // The slash has been trimmed.
                   ]));
               XCTAssertEqualObjects(result.pageToken, @"foo");

               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testListWithErrorResponse {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testListWithErrorResponse"];

  NSError *error = [NSError errorWithDomain:@"com.google.firebase.storage" code:404 userInfo:nil];

  self.fetcherService.testBlock =
      ^(GTMSessionFetcher *fetcher, GTMSessionFetcherTestResponse response) {
        NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:fetcher.request.URL
                                                                      statusCode:403
                                                                     HTTPVersion:kHTTPVersion

                                                                    headerFields:nil];
        response(httpResponse, nil, error);
      };

  FIRIMPLStorageReference *ref = [self.storage referenceWithPath:kListPath];
  FIRStorageListTask *task = [[FIRStorageListTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               pageSize:nil
      previousPageToken:nil
             completion:^(FIRIMPLStorageListResult *result, NSError *error) {
               XCTAssertNotNil(error);
               XCTAssertNil(result);

               XCTAssertEqualObjects(error.domain, @"FIRStorageErrorDomain");
               XCTAssertEqual(error.code, FIRIMPLStorageErrorCodeObjectNotFound);

               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

@end
