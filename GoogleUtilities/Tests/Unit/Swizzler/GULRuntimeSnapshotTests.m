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

#import "GoogleUtilities/SwizzlerTestHelpers/GULRuntimeDiff.h"
#import "GoogleUtilities/SwizzlerTestHelpers/GULRuntimeSnapshot.h"

@interface GULRuntimeSnapshotTestsTestClass : NSObject

@end

@implementation GULRuntimeSnapshotTestsTestClass

- (NSString *)description {
  return [super description];
}

@end

@interface GULRuntimeSnapshotTests : XCTestCase

@end

@implementation GULRuntimeSnapshotTests

/** Tests default init. */
- (void)testInitDoesntThrow {
  XCTAssertNoThrow([[GULRuntimeSnapshot alloc] init]);
}

/** Tests the designated initializer. */
- (void)testDesignatedInitializer {
  XCTAssertNoThrow([[GULRuntimeSnapshot alloc] initWithClasses:nil]);
  NSSet *classes = [NSSet setWithObjects:[NSString class], [NSObject class], [self class], nil];
  XCTAssertNoThrow([[GULRuntimeSnapshot alloc] initWithClasses:classes]);
}

/** Tests equality of snapshots. */
- (void)testEquality {
  GULRuntimeSnapshot *snapshot1 = [[GULRuntimeSnapshot alloc] initWithClasses:nil];
  GULRuntimeSnapshot *snapshot2 = [[GULRuntimeSnapshot alloc] initWithClasses:nil];
  XCTAssertEqualObjects(snapshot1, snapshot2);
  snapshot1 = nil;
  snapshot2 = nil;

  NSSet *classSet = [NSSet setWithObject:[GULRuntimeSnapshotTestsTestClass class]];
  snapshot1 = [[GULRuntimeSnapshot alloc] initWithClasses:classSet];
  snapshot2 = [[GULRuntimeSnapshot alloc] initWithClasses:classSet];
  XCTAssertEqualObjects(snapshot1, snapshot2);

  [snapshot1 capture];
  [snapshot2 capture];
  XCTAssertEqualObjects(snapshot1, snapshot2);

  SEL selector = @selector(description);
  Method description = class_getInstanceMethod([GULRuntimeSnapshotTestsTestClass class], selector);
  IMP newDescriptionIMP = imp_implementationWithBlock(^(id _self) {
    return @"swizzled description";
  });
  IMP originalDescriptionIMP = method_getImplementation(description);
  IMP probableOriginalDescriptionIMP = method_setImplementation(description, newDescriptionIMP);
  XCTAssertEqual(probableOriginalDescriptionIMP, originalDescriptionIMP);

  [snapshot1 capture];
  [snapshot2 capture];
  XCTAssertEqualObjects(snapshot1, snapshot2);

  method_setImplementation(description, originalDescriptionIMP);

  [snapshot2 capture];
  XCTAssertNotEqualObjects(snapshot2, snapshot1);
  [snapshot1 capture];
  XCTAssertEqualObjects(snapshot1, snapshot2);
}

/** Tests capturing snapshots doesn't throw. */
- (void)testCapture {
  GULRuntimeSnapshot *snapshot1 = [[GULRuntimeSnapshot alloc] initWithClasses:nil];
  XCTAssertNoThrow([snapshot1 capture]);

  GULRuntimeSnapshot *snapshot2 = [[GULRuntimeSnapshot alloc] initWithClasses:nil];
  XCTAssertNoThrow([snapshot2 capture]);
}

/** Tests detecting a new class works. */
- (void)testNewClassDetected {
  GULRuntimeSnapshot *snapshot1 = [[GULRuntimeSnapshot alloc] initWithClasses:nil];
  [snapshot1 capture];

  Class newClass = objc_allocateClassPair([NSObject class], "GULNewClass", 0);
  objc_registerClassPair(newClass);

  GULRuntimeSnapshot *snapshot2 = [[GULRuntimeSnapshot alloc] initWithClasses:nil];
  [snapshot2 capture];

  GULRuntimeDiff *diff = [snapshot1 diff:snapshot2];
  XCTAssertGreaterThan(diff.addedClasses.count, 0);
  BOOL found = NO;
  for (NSString *class in diff.addedClasses) {
    if ([class isEqualToString:@"GULNewClass"]) {
      found = YES;
      break;
    }
  }
  XCTAssertTrue(found);
}

/** Tests detecting a class deletion works. */
- (void)testClassRemovedDetected {
  Class newClass = objc_allocateClassPair([NSObject class], "GULNewClass2", 0);
  objc_registerClassPair(newClass);

  GULRuntimeSnapshot *snapshot1 = [[GULRuntimeSnapshot alloc] initWithClasses:nil];
  [snapshot1 capture];

  objc_disposeClassPair(NSClassFromString(@"GULNewClass2"));

  GULRuntimeSnapshot *snapshot2 = [[GULRuntimeSnapshot alloc] initWithClasses:nil];
  [snapshot2 capture];

  GULRuntimeDiff *diff = [snapshot1 diff:snapshot2];
  XCTAssertGreaterThan(diff.removedClasses.count, 0);
  BOOL found = NO;
  for (NSString *class in diff.removedClasses) {
    if ([class isEqualToString:@"GULNewClass2"]) {
      found = YES;
      break;
    }
  }
  XCTAssertTrue(found);
}

@end
