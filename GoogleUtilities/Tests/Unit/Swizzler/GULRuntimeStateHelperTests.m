// Copyright 2018 Google LLC
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

#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#import "GoogleUtilities/SwizzlerTestHelpers/GULRuntimeStateHelper.h"

@interface GULRuntimeStateHelperTestHelperClass : NSObject

@end

@implementation GULRuntimeStateHelperTestHelperClass

@end

@interface GULRuntimeStateHelperTests : XCTestCase

@end

@implementation GULRuntimeStateHelperTests

- (void)testCaptureRuntimeState {
  NSUInteger snapshot1 = 0;
  XCTAssertNoThrow(snapshot1 = [GULRuntimeStateHelper captureRuntimeState]);
}

- (void)testDiffBetweenFirstSnapshotSecondSnapshot {
  NSUInteger snapshot1 = [GULRuntimeStateHelper captureRuntimeState];

  NSString *newClassName = [NSStringFromClass([self class]) stringByAppendingString:@"_gen"];
  Class newSubclass = objc_allocateClassPair([self class], [newClassName UTF8String], 0);
  objc_registerClassPair(newSubclass);

  Method dummyMethod = class_getInstanceMethod([self class], @selector(dummyMethod));
  IMP originalIMP = method_getImplementation(dummyMethod);
  NSString *originalIMPString = [NSString stringWithFormat:@"%p", originalIMP];
  IMP newIMP = imp_implementationWithBlock((NSString *)^(id _self) {
    return @"Goodbye!";
  });
  method_setImplementation(dummyMethod, newIMP);

  NSUInteger snapshot2 = [GULRuntimeStateHelper captureRuntimeState];
  GULRuntimeDiff *diff = [GULRuntimeStateHelper diffBetween:snapshot1 secondSnapshot:snapshot2];

  BOOL found = NO;
  for (NSString *class in diff.addedClasses) {
    if ([class isEqualToString:newClassName]) {
      found = YES;
      break;
    }
  }
  XCTAssertTrue(found, @"The generated class above should be found in the list of added classes");

  found = NO;
  for (GULRuntimeClassDiff *classDiff in diff.classDiffs) {
    for (NSString *modifiedIMP in classDiff.modifiedImps) {
      if ([modifiedIMP containsString:originalIMPString]) {
        found = YES;
        break;
      }
    }
  }
  XCTAssertTrue(found, @"One of the classdiffs should contain the address of the original IMP of "
                        "the method that was modified above");
}

#pragma mark - Helper methods

/** Exists to just be swizzled, to test detection capability.
 *
 *  @return The string "Hello!".
 */
- (NSString *)dummyMethod {
  return @"Hello!";
}

@end
