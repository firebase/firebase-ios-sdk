/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FIRTestCase.h"

#import <FirebaseCore/FIRComponent.h>
#import <FirebaseCore/FIRComponentRegistrant.h>

#import "FIRStorageComponent.h"

// Make FIRComponentRegistrant conformance visible to the tests.
@interface FIRStorageComponent () <FIRComponentRegistrant>
@end

@interface FIRStorageComponentTests : FIRTestCase
@end

@implementation FIRStorageComponentTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark - Interoperability Tests

/** @fn testComponentsBeingRegistered
 @brief Tests that Storage registers as a component registrant to handle instance creation.
 */
- (void)testComponentsBeingRegistered {
  // Verify that the components are registered properly. Check the count, because any time a new
  // component is added it should be added to the test suite as well.
  NSArray<FIRComponent *> *components = [FIRStorageComponent componentsToRegister];
  XCTAssertTrue(components.count == 1);

  FIRComponent *component = [components firstObject];
  XCTAssert(component.protocol == @protocol(FIRStorageMultiBucketProvider));
}

@end
