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

#import "FirebaseCore/Tests/Unit/FIRTestCase.h"

#import <GoogleUtilities/GULAppEnvironmentUtil.h>
#import "FirebaseCore/Sources/FIRBundleUtil.h"
#import "SharedTestUtilities/FIROptionsMock.h"

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
  XCTAssertTrue([FIRBundleUtil hasBundleIdentifierPrefix:bundleID inBundles:@[ self.mockBundle ]]);
}

- (void)testBundleIdentifierExistsInBundles_notExist {
  [OCMStub([self.mockBundle bundleIdentifier]) andReturn:@"com.google.test"];
  XCTAssertFalse([FIRBundleUtil hasBundleIdentifierPrefix:@"not-exist"
                                                inBundles:@[ self.mockBundle ]]);
}

- (void)testBundleIdentifierExistsInBundles_emptyBundlesArray {
  XCTAssertFalse([FIRBundleUtil hasBundleIdentifierPrefix:@"com.google.test" inBundles:@[]]);
}

- (void)testBundleIdentifierHasPrefixInBundlesForExtension {
  id environmentUtilsMock = [OCMockObject mockForClass:[GULAppEnvironmentUtil class]];
  [[[environmentUtilsMock stub] andReturnValue:@(YES)] isAppExtension];

  // Mock bundle should have what app extension has, the extension bundle ID.
  [OCMStub([self.mockBundle bundleIdentifier]) andReturn:@"com.google.test.someextension"];
  XCTAssertTrue([FIRBundleUtil hasBundleIdentifierPrefix:@"com.google.test"
                                               inBundles:@[ self.mockBundle ]]);

  [environmentUtilsMock stopMocking];
}

- (void)testBundleIdentifierExistsInBundlesForExtensions_exactMatch {
  id environmentUtilsMock = [OCMockObject mockForClass:[GULAppEnvironmentUtil class]];
  [[[environmentUtilsMock stub] andReturnValue:@(YES)] isAppExtension];

  // Mock bundle should have what app extension has, the extension bundle ID.
  [OCMStub([self.mockBundle bundleIdentifier]) andReturn:@"com.google.test.someextension"];
  XCTAssertTrue([FIRBundleUtil hasBundleIdentifierPrefix:@"com.google.test.someextension"
                                               inBundles:@[ self.mockBundle ]]);

  [environmentUtilsMock stopMocking];
}

- (void)testBundleIdentifierHasPrefixInBundlesNotValidExtension {
  id environmentUtilsMock = [OCMockObject mockForClass:[GULAppEnvironmentUtil class]];
  [[[environmentUtilsMock stub] andReturnValue:@(YES)] isAppExtension];

  [OCMStub([self.mockBundle bundleIdentifier]) andReturn:@"com.google.test.someextension.some"];
  XCTAssertFalse([FIRBundleUtil hasBundleIdentifierPrefix:@"com.google.test"
                                                inBundles:@[ self.mockBundle ]]);

  [OCMStub([self.mockBundle bundleIdentifier]) andReturn:@"com.google.testsomeextension"];
  XCTAssertFalse([FIRBundleUtil hasBundleIdentifierPrefix:@"com.google.test"
                                                inBundles:@[ self.mockBundle ]]);

  [OCMStub([self.mockBundle bundleIdentifier]) andReturn:@"com.google.testsomeextension.some"];
  XCTAssertFalse([FIRBundleUtil hasBundleIdentifierPrefix:@"com.google.test"
                                                inBundles:@[ self.mockBundle ]]);

  [OCMStub([self.mockBundle bundleIdentifier]) andReturn:@"not-exist"];
  XCTAssertFalse([FIRBundleUtil hasBundleIdentifierPrefix:@"com.google.test"
                                                inBundles:@[ self.mockBundle ]]);

  // Should be NO, since if @"com.google.tests" is an app extension identifier, then the app bundle
  // identifier is @"com.google"
  XCTAssertFalse([FIRBundleUtil hasBundleIdentifierPrefix:@"com.google.tests"
                                                inBundles:@[ self.mockBundle ]]);

  [environmentUtilsMock stopMocking];
}

@end
