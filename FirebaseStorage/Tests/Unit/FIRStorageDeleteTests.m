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

#import "FirebaseStorage/Sources/FIRStorageDeleteTask.h"
#import "FirebaseStorage/Tests/Unit/FIRStorageTestHelpers.h"

@interface FIRStorageDeleteTests : XCTestCase

@property(strong, nonatomic) GTMSessionFetcherService *fetcherService;
@property(nonatomic) dispatch_queue_t dispatchQueue;
@property(strong, nonatomic) FIRStorage *storage;
@property(strong, nonatomic) id mockApp;

@end

@implementation FIRStorageDeleteTests

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

- (void)testFetcherConfiguration {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testFetcherConfiguration"];

  self.fetcherService.testBlock =
      ^(GTMSessionFetcher *fetcher, GTMSessionFetcherTestResponse response) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        XCTAssertEqualObjects(fetcher.request.URL, [FIRStorageTestHelpers objectURL]);
#pragma clang diagnostic pop
        XCTAssertEqualObjects(fetcher.request.HTTPMethod, @"DELETE");
        NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:fetcher.request.URL
                                                                      statusCode:200
                                                                     HTTPVersion:kHTTPVersion
                                                                    headerFields:nil];
        response(httpResponse, nil, nil);
      };

  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRStorageReference *ref = [[FIRStorageReference alloc] initWithStorage:self.storage path:path];
  FIRStorageDeleteTask *task = [[FIRStorageDeleteTask alloc] initWithReference:ref
                                                                fetcherService:self.fetcherService
                                                                 dispatchQueue:self.dispatchQueue
                                                                    completion:^(NSError *error) {
                                                                      [expectation fulfill];
                                                                    }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testSuccessfulFetch {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testSuccessfulFetch"];

  self.fetcherService.testBlock = [FIRStorageTestHelpers successBlock];
  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRStorageReference *ref = [[FIRStorageReference alloc] initWithStorage:self.storage path:path];
  FIRStorageDeleteTask *task = [[FIRStorageDeleteTask alloc] initWithReference:ref
                                                                fetcherService:self.fetcherService
                                                                 dispatchQueue:self.dispatchQueue
                                                                    completion:^(NSError *error) {
                                                                      XCTAssertEqual(error, nil);
                                                                      [expectation fulfill];
                                                                    }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testUnsuccessfulFetchUnauthenticated {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnsuccessfulFetchUnauthenticated"];

  self.fetcherService.testBlock = [FIRStorageTestHelpers unauthenticatedBlock];
  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRStorageReference *ref = [[FIRStorageReference alloc] initWithStorage:self.storage path:path];
  FIRStorageDeleteTask *task = [[FIRStorageDeleteTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
             completion:^(NSError *error) {
               XCTAssertEqual(error.code, FIRStorageErrorCodeUnauthenticated);
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testUnsuccessfulFetchUnauthorized {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnsuccessfulFetchUnauthorized"];

  self.fetcherService.testBlock = [FIRStorageTestHelpers unauthorizedBlock];
  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRStorageReference *ref = [[FIRStorageReference alloc] initWithStorage:self.storage path:path];
  FIRStorageDeleteTask *task = [[FIRStorageDeleteTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
             completion:^(NSError *error) {
               XCTAssertEqual(error.code, FIRStorageErrorCodeUnauthorized);
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testUnsuccessfulFetchObjectDoesntExist {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnsuccessfulFetchObjectDoesntExist"];

  self.fetcherService.testBlock = [FIRStorageTestHelpers notFoundBlock];
  FIRStoragePath *path = [FIRStorageTestHelpers notFoundPath];
  FIRStorageReference *ref = [[FIRStorageReference alloc] initWithStorage:self.storage path:path];
  FIRStorageDeleteTask *task = [[FIRStorageDeleteTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
             completion:^(NSError *error) {
               XCTAssertEqual(error.code, FIRStorageErrorCodeObjectNotFound);
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

@end
