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

#import "FirebaseStorage/Sources/Public/FIRStorageReference.h"

#import "FirebaseStorage/Sources/FIRStorageComponent.h"
#import "FirebaseStorage/Sources/FIRStorageReference_Private.h"
#import "FirebaseStorage/Sources/FIRStorage_Private.h"
#import "SharedTestUtilities/FIRComponentTestUtilities.h"

@interface FIRStorageTests : XCTestCase

@property(strong, nonatomic) id app;

@end

@implementation FIRStorageTests

- (void)setUp {
  [super setUp];

  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"bucket");

  self.app = [FIRStorageTestHelpers mockedApp];
  OCMStub([self.app name]).andReturn(kFIRStorageAppName);
  OCMStub([(FIRApp *)self.app options]).andReturn(mockOptions);
}

- (void)tearDown {
  self.app = nil;
  [super tearDown];
}

- (void)testBucketNotEnforced {
  FIROptions *mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"");
  FIRApp *app = [FIRStorageTestHelpers mockedApp];
  OCMStub([app name]).andReturn(kFIRStorageAppName);
  OCMStub([(FIRApp *)app options]).andReturn(mockOptions);

  FIRStorage *storage = [FIRStorage storageForApp:app];
  [storage referenceForURL:@"gs://benwu-test1.storage.firebase.com/child"];
  [storage referenceForURL:@"gs://benwu-test2.storage.firebase.com/child"];
}

- (void)testBucketEnforced {
  FIRStorage *storage = [FIRStorage storageForApp:self.app
                                              URL:@"gs://benwu-test1.storage.firebase.com"];
  [storage referenceForURL:@"gs://benwu-test1.storage.firebase.com/child"];
  storage = [FIRStorage storageForApp:self.app URL:@"gs://benwu-test1.storage.firebase.com/"];
  [storage referenceForURL:@"gs://benwu-test1.storage.firebase.com/child"];
  XCTAssertThrows([storage referenceForURL:@"gs://benwu-test2.storage.firebase.com/child"]);
}

- (void)testInitWithCustomUrl {
  FIRStorage *storage = [FIRStorage storageForApp:self.app URL:@"gs://foo-bar.appspot.com"];
  XCTAssertEqualObjects(@"gs://foo-bar.appspot.com/", [[storage reference] description]);
  storage = [FIRStorage storageForApp:self.app URL:@"gs://foo-bar.appspot.com/"];
  XCTAssertEqualObjects(@"gs://foo-bar.appspot.com/", [[storage reference] description]);
}

- (void)testInitWithWrongScheme {
  XCTAssertThrows([FIRStorage storageForApp:self.app URL:@"http://foo-bar.appspot.com"]);
}

- (void)testInitWithNoScheme {
  XCTAssertThrows([FIRStorage storageForApp:self.app URL:@"foo-bar.appspot.com"]);
}

- (void)testInitWithNilURL {
  XCTAssertThrows([FIRStorage storageForApp:self.app URL:(id _Nonnull)nil]);
}

- (void)testInitWithPath {
  XCTAssertThrows([FIRStorage storageForApp:self.app URL:@"gs://foo-bar.appspot.com/child"]);
}

- (void)testInitWithDefaultAndCustomUrl {
  FIRStorage *customInstance = [FIRStorage storageForApp:self.app URL:@"gs://foo-bar.appspot.com"];
  FIRStorage *defaultInstance = [FIRStorage storageForApp:self.app];
  XCTAssertEqualObjects(@"gs://foo-bar.appspot.com/", [[customInstance reference] description]);
  XCTAssertEqualObjects(@"gs://bucket/", [[defaultInstance reference] description]);
}

- (void)testStorageDefaultApp {
  FIRStorage *storage = [FIRStorage storageForApp:self.app];
  XCTAssertEqualObjects(storage.app.name, ((FIRApp *)self.app).name);
  XCTAssertNotNil(storage.fetcherServiceForApp);
}

- (void)testStorageCustomApp {
  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"bucket");
  id secondApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([secondApp name]).andReturn(@"secondApp");
  OCMStub([(FIRApp *)secondApp options]).andReturn(mockOptions);
  FIRStorage *storage = [FIRStorage storageForApp:secondApp];
  XCTAssertNotEqual(storage.app.name, ((FIRApp *)self.app).name);
  XCTAssertNotNil(storage.fetcherServiceForApp);
  XCTAssertNotEqualObjects(storage.fetcherServiceForApp,
                           [FIRStorage storageForApp:self.app].fetcherServiceForApp);
}

- (void)testStorageNoBucketInConfig {
  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(nil);
  id secondApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([secondApp name]).andReturn(@"secondApp");
  OCMStub([(FIRApp *)secondApp options]).andReturn(mockOptions);
  XCTAssertThrows([FIRStorage storageForApp:secondApp]);
}

- (void)testStorageEmptyBucketInConfig {
  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"");
  id secondApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([secondApp name]).andReturn(@"secondApp");
  OCMStub([(FIRApp *)secondApp options]).andReturn(mockOptions);
  FIRStorage *storage = [FIRStorage storageForApp:secondApp];
  FIRStorageReference *storageRef = [storage referenceForURL:@"gs://bucket/path/to/object"];
  XCTAssertEqualObjects(storageRef.bucket, @"bucket");
}

- (void)testStorageWrongBucketInConfig {
  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"notMyBucket");
  id secondApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([secondApp name]).andReturn(@"secondApp");
  OCMStub([(FIRApp *)secondApp options]).andReturn(mockOptions);
  FIRStorage *storage = [FIRStorage storageForApp:secondApp];
  XCTAssertEqualObjects([(FIRApp *)secondApp options].storageBucket, @"notMyBucket");
  XCTAssertThrows([storage referenceForURL:@"gs://bucket/path/to/object"]);
}

- (void)testRefDefaultApp {
  FIRStorageReference *convenienceRef =
      [[FIRStorage storageForApp:self.app] referenceForURL:@"gs://bucket/path/to/object"];
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  FIRStorageReference *builtRef =
      [[FIRStorageReference alloc] initWithStorage:[FIRStorage storageForApp:self.app] path:path];
  XCTAssertEqualObjects([convenienceRef description], [builtRef description]);
  XCTAssertEqualObjects(convenienceRef.storage.app, builtRef.storage.app);
}

- (void)testRefCustomApp {
  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"bucket");
  id secondApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([secondApp name]).andReturn(@"secondApp");
  OCMStub([(FIRApp *)secondApp options]).andReturn(mockOptions);
  FIRStorageReference *convenienceRef =
      [[FIRStorage storageForApp:secondApp] referenceForURL:@"gs://bucket/path/to/object"];
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  FIRStorageReference *builtRef =
      [[FIRStorageReference alloc] initWithStorage:[FIRStorage storageForApp:secondApp] path:path];
  XCTAssertEqualObjects([convenienceRef description], [builtRef description]);
  XCTAssertEqualObjects(convenienceRef.storage.app, builtRef.storage.app);
}

- (void)testRootRefDefaultApp {
  FIRStorageReference *convenienceRef = [[FIRStorage storageForApp:self.app] reference];
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRStorageReference *builtRef =
      [[FIRStorageReference alloc] initWithStorage:[FIRStorage storageForApp:self.app] path:path];
  XCTAssertEqualObjects([convenienceRef description], [builtRef description]);
  XCTAssertEqualObjects(convenienceRef.storage.app, builtRef.storage.app);
}

- (void)testRefWithPathDefaultApp {
  FIRStorageReference *convenienceRef =
      [[FIRStorage storageForApp:self.app] referenceWithPath:@"path/to/object"];
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  FIRStorageReference *builtRef =
      [[FIRStorageReference alloc] initWithStorage:[FIRStorage storageForApp:self.app] path:path];
  XCTAssertEqualObjects([convenienceRef description], [builtRef description]);
  XCTAssertEqualObjects(convenienceRef.storage.app, builtRef.storage.app);
}

- (void)testEqual {
  FIRStorage *storage = [FIRStorage storageForApp:self.app];
  FIRStorage *copy = [storage copy];
  XCTAssertEqualObjects(storage.app.name, copy.app.name);
}

- (void)testNotEqual {
  FIRStorage *storage = [FIRStorage storageForApp:self.app];
  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"bucket");
  id secondApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([secondApp name]).andReturn(@"secondApp");
  OCMStub([(FIRApp *)secondApp options]).andReturn(mockOptions);
  FIRStorage *secondStorage = [FIRStorage storageForApp:secondApp];
  XCTAssertNotEqualObjects(storage, secondStorage);
}

- (void)testHash {
  FIRStorage *storage = [FIRStorage storageForApp:self.app];
  FIRStorage *copy = [storage copy];
  XCTAssertEqual([storage hash], [copy hash]);
}

@end
