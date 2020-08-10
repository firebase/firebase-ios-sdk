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

#import "FirebaseStorage/Sources/FIRStorageListTask.h"
#import "FirebaseStorage/Tests/Unit/FIRStorageTestHelpers.h"

@interface FIRStorageListTests : XCTestCase

@property(strong, nonatomic) GTMSessionFetcherService *fetcherService;
@property(nonatomic) dispatch_queue_t dispatchQueue;
@property(strong, nonatomic) FIRStorage *storage;
@property(strong, nonatomic) id mockApp;

@end

@implementation FIRStorageListTests

- (void)setUp {
  [super setUp];

  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"bucket.appspot.com");

  self.mockApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([self.mockApp name]).andReturn(kFIRStorageAppName);
  OCMStub([(FIRApp *)self.mockApp options]).andReturn(mockOptions);

  self.fetcherService = [[GTMSessionFetcherService alloc] init];
  self.fetcherService.authorizer =
      [[FIRStorageTokenAuthorizer alloc] initWithGoogleAppID:@"dummyAppID"
                                              fetcherService:self.fetcherService
                                                authProvider:nil];

  self.dispatchQueue = dispatch_queue_create("Test dispatch queue", DISPATCH_QUEUE_SERIAL);

  self.storage = [FIRStorage storageForApp:self.mockApp];
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

  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRStorageReference *ref = [[FIRStorageReference alloc] initWithStorage:self.storage path:path];

  FIRStorageVoidListError errorBlock = ^(FIRStorageListResult *result, NSError *error) {
    XCTAssertNil(result);
    XCTAssertNotNil(error);

    XCTAssertEqualObjects(error.domain, @"FIRStorageErrorDomain");
    XCTAssertEqual(error.code, FIRStorageErrorCodeInvalidArgument);

    [expectation fulfill];
  };

  [ref listWithMaxResults:0 completion:errorBlock];
  [ref listWithMaxResults:1001 completion:errorBlock];
  [ref listWithMaxResults:0 pageToken:@"foo" completion:errorBlock];
  [ref listWithMaxResults:1001 pageToken:@"foo" completion:errorBlock];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testDefaultList {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testDefaultList"];
  NSURL *expectedURL = [NSURL
      URLWithString:
          @"https://firebasestorage.googleapis.com/v0/b/bucket/o?prefix=object/&delimiter=/"];

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

  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRStorageReference *ref = [[FIRStorageReference alloc] initWithStorage:self.storage path:path];
  FIRStorageListTask *task = [[FIRStorageListTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               pageSize:nil
      previousPageToken:nil
             completion:^(FIRStorageListResult *result, NSError *error) {
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testListWithPageSizeAndPageToken {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testListWithPageSizeAndPageToken"];
  NSURL *expectedURL =
      [NSURL URLWithString:@"https://firebasestorage.googleapis.com/v0/b/bucket/"
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

  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRStorageReference *ref = [[FIRStorageReference alloc] initWithStorage:self.storage path:path];
  FIRStorageListTask *task = [[FIRStorageListTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               pageSize:@(42)
      previousPageToken:@"foo"
             completion:^(FIRStorageListResult *result, NSError *error) {
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

  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRStorageReference *ref = [[FIRStorageReference alloc] initWithStorage:self.storage path:path];
  FIRStorageListTask *task = [[FIRStorageListTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               pageSize:nil
      previousPageToken:nil
             completion:^(FIRStorageListResult *result, NSError *error) {
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

  NSError *error = [NSError errorWithDomain:@"com.google.firebase.storage" code:-1 userInfo:nil];

  self.fetcherService.testBlock =
      ^(GTMSessionFetcher *fetcher, GTMSessionFetcherTestResponse response) {
        NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:fetcher.request.URL
                                                                      statusCode:403
                                                                     HTTPVersion:kHTTPVersion

                                                                    headerFields:nil];
        response(httpResponse, nil, error);
      };

  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRStorageReference *ref = [[FIRStorageReference alloc] initWithStorage:self.storage path:path];
  FIRStorageListTask *task = [[FIRStorageListTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
               pageSize:nil
      previousPageToken:nil
             completion:^(FIRStorageListResult *result, NSError *error) {
               XCTAssertNotNil(error);
               XCTAssertNil(result);

               XCTAssertEqualObjects(error.domain, @"FIRStorageErrorDomain");

               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

@end
