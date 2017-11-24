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

#import "FIRTestCase.h"

#import <FirebaseCore/FIRBundleUtil.h>

static NSString *const kResultPath = @"resultPath";
static NSString *const kResourceName = @"resourceName";
static NSString *const kFileType = @"fileType";

@interface FIRBundleUtilTest : FIRTestCase

@property(nonatomic, strong) id mockBundle;

@end

@implementation FIRBundleUtilTest

- (void)setUp {
  [super setUp];
  self.mockBundle = OCMClassMock([NSBundle class]);
}

- (void)testRelevantBundles_mainIsFirst {
  // Pointer compare to same instance of main bundle.
  XCTAssertEqual([NSBundle mainBundle], [FIRBundleUtil relevantBundles][0]);
}

// TODO: test that adding a bundle appears in "all bundles"
// once the use-case is understood.

- (void)testFindOptionsDictionaryPath {
  [OCMStub([self.mockBundle pathForResource:kResourceName ofType:kFileType]) andReturn:kResultPath];
  XCTAssertEqualObjects([FIRBundleUtil optionsDictionaryPathWithResourceName:kResourceName
                                                                 andFileType:kFileType
                                                                   inBundles:@[ self.mockBundle ]],
                        kResultPath);
}

- (void)testFindOptionsDictionaryPath_notFound {
  XCTAssertNil([FIRBundleUtil optionsDictionaryPathWithResourceName:kResourceName
                                                        andFileType:kFileType
                                                          inBundles:@[ self.mockBundle ]]);
}

- (void)testFindOptionsDictionaryPath_secondBundle {
  NSBundle *mockBundleEmpty = OCMClassMock([NSBundle class]);
  [OCMStub([self.mockBundle pathForResource:kResourceName ofType:kFileType]) andReturn:kResultPath];

  NSArray *bundles = @[ mockBundleEmpty, self.mockBundle ];
  XCTAssertEqualObjects([FIRBundleUtil optionsDictionaryPathWithResourceName:kResourceName
                                                                 andFileType:kFileType
                                                                   inBundles:bundles],
                        kResultPath);
}

- (void)testBundleIdentifierExistsInBundles {
  NSString *bundleID = @"com.google.test";
  [OCMStub([self.mockBundle bundleIdentifier]) andReturn:bundleID];
  XCTAssertTrue([FIRBundleUtil hasBundleIdentifier:bundleID inBundles:@[ self.mockBundle ]]);
}

- (void)testBundleIdentifierExistsInBundles_notExist {
  [OCMStub([self.mockBundle bundleIdentifier]) andReturn:@"com.google.test"];
  XCTAssertFalse([FIRBundleUtil hasBundleIdentifier:@"not-exist" inBundles:@[ self.mockBundle ]]);
}

- (void)testBundleIdentifierExistsInBundles_emptyBundlesArray {
  XCTAssertFalse([FIRBundleUtil hasBundleIdentifier:@"com.google.test" inBundles:@[]]);
}

@end
