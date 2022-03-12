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

#import "FirebaseStorage/Sources/Public/FirebaseStorage/FIRStorageReference.h"

#ifdef TODO
// Port the component tests to Swift

//#import "FirebaseStorage/Sources/FIRStorageComponent.h"
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

  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:app];
  [storage referenceForURL:@"gs://benwu-test1.storage.firebase.com/child"];
  [storage referenceForURL:@"gs://benwu-test2.storage.firebase.com/child"];
}

- (void)testBucketEnforced {
  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:self.app
                                                      URL:@"gs://benwu-test1.storage.firebase.com"];
  [storage referenceForURL:@"gs://benwu-test1.storage.firebase.com/child"];
  storage = [FIRIMPLStorage storageForApp:self.app URL:@"gs://benwu-test1.storage.firebase.com/"];
  [storage referenceForURL:@"gs://benwu-test1.storage.firebase.com/child"];
  XCTAssertThrows([storage referenceForURL:@"gs://benwu-test2.storage.firebase.com/child"]);
}

- (void)testInitWithCustomUrl {
  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:self.app URL:@"gs://foo-bar.appspot.com"];
  XCTAssertEqualObjects(@"gs://foo-bar.appspot.com/", [[storage reference] description]);
  storage = [FIRIMPLStorage storageForApp:self.app URL:@"gs://foo-bar.appspot.com/"];
  XCTAssertEqualObjects(@"gs://foo-bar.appspot.com/", [[storage reference] description]);
}

- (void)testInitWithWrongScheme {
  XCTAssertThrows([FIRIMPLStorage storageForApp:self.app URL:@"http://foo-bar.appspot.com"]);
}

- (void)testInitWithNoScheme {
  XCTAssertThrows([FIRIMPLStorage storageForApp:self.app URL:@"foo-bar.appspot.com"]);
}

- (void)testInitWithNilURL {
  XCTAssertThrows([FIRIMPLStorage storageForApp:self.app URL:(id _Nonnull)nil]);
}

- (void)testInitWithPath {
  XCTAssertThrows([FIRIMPLStorage storageForApp:self.app URL:@"gs://foo-bar.appspot.com/child"]);
}

- (void)testInitWithDefaultAndCustomUrl {
  FIRIMPLStorage *customInstance = [FIRIMPLStorage storageForApp:self.app
                                                             URL:@"gs://foo-bar.appspot.com"];
  FIRIMPLStorage *defaultInstance = [FIRIMPLStorage storageForApp:self.app];
  XCTAssertEqualObjects(@"gs://foo-bar.appspot.com/", [[customInstance reference] description]);
  XCTAssertEqualObjects(@"gs://bucket/", [[defaultInstance reference] description]);
}

- (void)testStorageDefaultApp {
  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:self.app];
  XCTAssertEqualObjects(storage.app.name, ((FIRApp *)self.app).name);
  [storage reference];  // Initialize Storage
  XCTAssertNotNil(storage.fetcherServiceForApp);
}

- (void)testStorageCustomApp {
  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"bucket");
  id secondApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([secondApp name]).andReturn(@"secondApp");
  OCMStub([(FIRApp *)secondApp options]).andReturn(mockOptions);
  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:secondApp];
  [storage reference];  // Initialize Storage
  XCTAssertNotEqual(storage.app.name, ((FIRApp *)self.app).name);
  XCTAssertNotNil(storage.fetcherServiceForApp);
  XCTAssertNotEqualObjects(storage.fetcherServiceForApp,
                           [FIRIMPLStorage storageForApp:self.app].fetcherServiceForApp);
}

- (void)testStorageNoBucketInConfig {
  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(nil);
  id secondApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([secondApp name]).andReturn(@"secondApp");
  OCMStub([(FIRApp *)secondApp options]).andReturn(mockOptions);
  XCTAssertThrows([FIRIMPLStorage storageForApp:secondApp]);
}

- (void)testStorageEmptyBucketInConfig {
  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"");
  id secondApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([secondApp name]).andReturn(@"secondApp");
  OCMStub([(FIRApp *)secondApp options]).andReturn(mockOptions);
  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:secondApp];
  FIRIMPLStorageReference *storageRef = [storage referenceForURL:@"gs://bucket/path/to/object"];
  XCTAssertEqualObjects(storageRef.bucket, @"bucket");
}

- (void)testStorageWrongBucketInConfig {
  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"notMyBucket");
  id secondApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([secondApp name]).andReturn(@"secondApp");
  OCMStub([(FIRApp *)secondApp options]).andReturn(mockOptions);
  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:secondApp];
  XCTAssertEqualObjects([(FIRApp *)secondApp options].storageBucket, @"notMyBucket");
  XCTAssertThrows([storage referenceForURL:@"gs://bucket/path/to/object"]);
}

- (void)testUseEmulator {
  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:self.app URL:@"gs://foo-bar.appspot.com"];
  [storage useEmulatorWithHost:@"localhost" port:8080];
  XCTAssertNoThrow([storage reference]);
}

- (void)testUseEmulatorValidatesHost {
  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:self.app URL:@"gs://foo-bar.appspot.com"];
  XCTAssertThrows([storage useEmulatorWithHost:@"" port:8080]);
}

- (void)testUseEmulatorValidatesPort {
  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:self.app URL:@"gs://foo-bar.appspot.com"];
  XCTAssertThrows([storage useEmulatorWithHost:@"localhost" port:-1]);
}

- (void)testUseEmulatorCannotBeCalledAfterObtainingReference {
  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:self.app
                                                      URL:@"gs://benwu-test1.storage.firebase.com"];
  [storage reference];
  XCTAssertThrows([storage useEmulatorWithHost:@"localhost" port:8080]);
}

- (void)testRefDefaultApp {
  FIRIMPLStorageReference *convenienceRef =
      [[FIRIMPLStorage storageForApp:self.app] referenceForURL:@"gs://bucket/path/to/object"];
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  FIRIMPLStorageReference *builtRef =
      [[FIRIMPLStorageReference alloc] initWithStorage:[FIRIMPLStorage storageForApp:self.app]
                                                  path:path];
  XCTAssertEqualObjects([convenienceRef description], [builtRef description]);
  XCTAssertEqualObjects(convenienceRef.storage.app, builtRef.storage.app);
}

- (void)testRefCustomApp {
  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"bucket");
  id secondApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([secondApp name]).andReturn(@"secondApp");
  OCMStub([(FIRApp *)secondApp options]).andReturn(mockOptions);
  FIRIMPLStorageReference *convenienceRef =
      [[FIRIMPLStorage storageForApp:secondApp] referenceForURL:@"gs://bucket/path/to/object"];
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  FIRIMPLStorageReference *builtRef =
      [[FIRIMPLStorageReference alloc] initWithStorage:[FIRIMPLStorage storageForApp:secondApp]
                                                  path:path];
  XCTAssertEqualObjects([convenienceRef description], [builtRef description]);
  XCTAssertEqualObjects(convenienceRef.storage.app, builtRef.storage.app);
}

- (void)testRootRefDefaultApp {
  FIRIMPLStorageReference *convenienceRef = [[FIRIMPLStorage storageForApp:self.app] reference];
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRIMPLStorageReference *builtRef =
      [[FIRIMPLStorageReference alloc] initWithStorage:[FIRIMPLStorage storageForApp:self.app]
                                                  path:path];
  XCTAssertEqualObjects([convenienceRef description], [builtRef description]);
  XCTAssertEqualObjects(convenienceRef.storage.app, builtRef.storage.app);
}

- (void)testRefWithPathDefaultApp {
  FIRIMPLStorageReference *convenienceRef =
      [[FIRIMPLStorage storageForApp:self.app] referenceWithPath:@"path/to/object"];
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  FIRIMPLStorageReference *builtRef =
      [[FIRIMPLStorageReference alloc] initWithStorage:[FIRIMPLStorage storageForApp:self.app]
                                                  path:path];
  XCTAssertEqualObjects([convenienceRef description], [builtRef description]);
  XCTAssertEqualObjects(convenienceRef.storage.app, builtRef.storage.app);
}

- (void)testEqual {
  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:self.app];
  FIRIMPLStorage *copy = [storage copy];
  XCTAssertEqualObjects(storage.app.name, copy.app.name);
}

- (void)testNotEqual {
  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:self.app];
  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"bucket");
  id secondApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([secondApp name]).andReturn(@"secondApp");
  OCMStub([(FIRApp *)secondApp options]).andReturn(mockOptions);
  FIRIMPLStorage *secondStorage = [FIRIMPLStorage storageForApp:secondApp];
  XCTAssertNotEqualObjects(storage, secondStorage);
}

- (void)testHash {
  FIRIMPLStorage *storage = [FIRIMPLStorage storageForApp:self.app];
  FIRIMPLStorage *copy = [storage copy];
  XCTAssertEqual([storage hash], [copy hash]);
}

@end

#endif
