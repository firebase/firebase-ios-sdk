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

#import "FirebaseStorageInternal/Tests/Unit/FIRStorageTestHelpers.h"

#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageReference.h"

#import "FirebaseStorageInternal/Sources/FIRStorageReference_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorage_Private.h"
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

- (void)testRefDefaultApp {
  FIRIMPLStorage *storage = [[FIRIMPLStorage alloc] initWithApp:self.app
                                                         bucket:@"bucket"
                                                           auth:nil
                                                       appCheck:nil];
  FIRIMPLStorageReference *convenienceRef = [storage referenceForURL:@"gs://bucket/path/to/object"];
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  FIRIMPLStorageReference *builtRef = [[FIRIMPLStorageReference alloc] initWithStorage:storage
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
  FIRIMPLStorage *storage2 = [[FIRIMPLStorage alloc] initWithApp:secondApp
                                                          bucket:@"bucket"
                                                            auth:nil
                                                        appCheck:nil];
  FIRIMPLStorageReference *convenienceRef =
      [storage2 referenceForURL:@"gs://bucket/path/to/object"];
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  FIRIMPLStorageReference *builtRef = [[FIRIMPLStorageReference alloc] initWithStorage:storage2
                                                                                  path:path];
  XCTAssertEqualObjects([convenienceRef description], [builtRef description]);
  XCTAssertEqualObjects(convenienceRef.storage.app, builtRef.storage.app);
}

- (void)testRootRefDefaultApp {
  FIRIMPLStorage *storage = [[FIRIMPLStorage alloc] initWithApp:self.app
                                                         bucket:@"bucket"
                                                           auth:nil
                                                       appCheck:nil];
  FIRIMPLStorageReference *convenienceRef = [storage reference];
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRIMPLStorageReference *builtRef = [[FIRIMPLStorageReference alloc] initWithStorage:storage
                                                                                  path:path];
  XCTAssertEqualObjects([convenienceRef description], [builtRef description]);
  XCTAssertEqualObjects(convenienceRef.storage.app, builtRef.storage.app);
}

- (void)testRefWithPathDefaultApp {
  FIRIMPLStorage *storage = [[FIRIMPLStorage alloc] initWithApp:self.app
                                                         bucket:@"bucket"
                                                           auth:nil
                                                       appCheck:nil];
  FIRIMPLStorageReference *convenienceRef = [storage referenceForURL:@"gs://bucket/path/to/object"];
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  FIRIMPLStorageReference *builtRef = [[FIRIMPLStorageReference alloc] initWithStorage:storage
                                                                                  path:path];
  XCTAssertEqualObjects([convenienceRef description], [builtRef description]);
  XCTAssertEqualObjects(convenienceRef.storage.app, builtRef.storage.app);
}

@end
