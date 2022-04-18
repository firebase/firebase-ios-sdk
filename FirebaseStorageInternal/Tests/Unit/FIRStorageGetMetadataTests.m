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

#import "FirebaseStorageInternal/Sources/FIRStorageGetMetadataTask.h"
#import "FirebaseStorageInternal/Tests/Unit/FIRStorageTestHelpers.h"

@interface FIRStorageGetMetadataTests : XCTestCase

@property(strong, nonatomic) GTMSessionFetcherService *fetcherService;
@property(nonatomic) dispatch_queue_t dispatchQueue;
@property(strong, nonatomic) FIRIMPLStorageMetadata *metadata;
@property(strong, nonatomic) FIRIMPLStorage *storage;
@property(strong, nonatomic) id mockApp;

@end

@implementation FIRStorageGetMetadataTests

- (void)setUp {
  [super setUp];

  NSDictionary *metadataDict = @{@"bucket" : @"bucket", @"name" : @"path/to/object"};
  self.metadata = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metadataDict];

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

- (void)testFetcherConfiguration {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testSuccessfulFetch"];

  self.fetcherService.testBlock =
      ^(GTMSessionFetcher *fetcher, GTMSessionFetcherTestResponse response) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        XCTAssertEqualObjects(fetcher.request.URL, [FIRStorageTestHelpers objectURL]);
#pragma clang diagnostic pop
        XCTAssertEqualObjects(fetcher.request.HTTPMethod, @"GET");
        NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:fetcher.request.URL
                                                                      statusCode:200
                                                                     HTTPVersion:kHTTPVersion
                                                                    headerFields:nil];
        response(httpResponse, nil, nil);
      };

  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRIMPLStorageReference *ref = [[FIRIMPLStorageReference alloc] initWithStorage:self.storage
                                                                             path:path];
  FIRStorageGetMetadataTask *task = [[FIRStorageGetMetadataTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
             completion:^(FIRIMPLStorageMetadata *metadata, NSError *error) {
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testSuccessfulFetch {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testSuccessfulFetch"];

  self.fetcherService.testBlock = [FIRStorageTestHelpers successBlockWithMetadata:self.metadata];
  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRIMPLStorageReference *ref = [[FIRIMPLStorageReference alloc] initWithStorage:self.storage
                                                                             path:path];
  FIRStorageGetMetadataTask *task = [[FIRStorageGetMetadataTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
             completion:^(FIRIMPLStorageMetadata *metadata, NSError *error) {
               XCTAssertEqualObjects(self.metadata.bucket, metadata.bucket);
               XCTAssertEqualObjects(self.metadata.name, metadata.name);
               XCTAssertEqual(error, nil);
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testSuccessfulFetchWithEmulator {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testSuccessfulFetchWithEmulator"];

  [self.storage useEmulatorWithHost:@"localhost" port:8080];
  self.fetcherService.allowLocalhostRequest = YES;
  self.fetcherService.testBlock =
      [FIRStorageTestHelpers successBlockWithURL:@"http://localhost:8080/v0/b/bucket/o/object"];

  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRIMPLStorageReference *ref = [[FIRIMPLStorageReference alloc] initWithStorage:self.storage
                                                                             path:path];
  FIRStorageGetMetadataTask *task = [[FIRStorageGetMetadataTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
             completion:^(FIRIMPLStorageMetadata *metadata, NSError *error) {
               XCTAssertNil(error);
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
  FIRIMPLStorageReference *ref = [[FIRIMPLStorageReference alloc] initWithStorage:self.storage
                                                                             path:path];
  FIRStorageGetMetadataTask *task = [[FIRStorageGetMetadataTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
             completion:^(FIRIMPLStorageMetadata *metadata, NSError *error) {
               XCTAssertEqual(metadata, nil);
               XCTAssertEqual(error.code, FIRIMPLStorageErrorCodeUnauthenticated);
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
  FIRIMPLStorageReference *ref = [[FIRIMPLStorageReference alloc] initWithStorage:self.storage
                                                                             path:path];
  FIRStorageGetMetadataTask *task = [[FIRStorageGetMetadataTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
             completion:^(FIRIMPLStorageMetadata *metadata, NSError *error) {
               XCTAssertEqual(metadata, nil);
               XCTAssertEqual(error.code, FIRIMPLStorageErrorCodeUnauthorized);
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
  FIRIMPLStorageReference *ref = [[FIRIMPLStorageReference alloc] initWithStorage:self.storage
                                                                             path:path];
  FIRStorageGetMetadataTask *task = [[FIRStorageGetMetadataTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
             completion:^(FIRIMPLStorageMetadata *metadata, NSError *error) {
               XCTAssertEqual(metadata, nil);
               XCTAssertEqual(error.code, FIRIMPLStorageErrorCodeObjectNotFound);
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

- (void)testUnsuccessfulFetchBadJSON {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnsuccessfulFetchBadJSON"];

  self.fetcherService.testBlock = [FIRStorageTestHelpers invalidJSONBlock];
  FIRStoragePath *path = [FIRStorageTestHelpers objectPath];
  FIRIMPLStorageReference *ref = [[FIRIMPLStorageReference alloc] initWithStorage:self.storage
                                                                             path:path];
  FIRStorageGetMetadataTask *task = [[FIRStorageGetMetadataTask alloc]
      initWithReference:ref
         fetcherService:self.fetcherService
          dispatchQueue:self.dispatchQueue
             completion:^(FIRIMPLStorageMetadata *metadata, NSError *error) {
               XCTAssertEqual(metadata, nil);
               XCTAssertEqual(error.code, FIRIMPLStorageErrorCodeUnknown);
               [expectation fulfill];
             }];
  [task enqueue];

  [FIRStorageTestHelpers waitForExpectation:self];
}

@end
