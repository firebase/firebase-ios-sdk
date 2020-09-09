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

#import "GoogleUtilities/SwizzlerTestHelpers/GULRuntimeClassDiff.h"
#import "GoogleUtilities/SwizzlerTestHelpers/GULRuntimeClassSnapshot.h"

// A variable to be used as a backing store for a dynamic class property. */
static NSString *dynamicClassBacking;

/** Class used for testing the detection of runtime state changes. */
@interface GULRuntimeClassSnapshotTestClass : NSObject {
  /** An ivar to be used as the backing store for an instance property later. */
  NSString *dynamicPropertyIvar;
}

@end

@implementation GULRuntimeClassSnapshotTestClass

+ (NSString *)description {
  return [super description];
}

- (NSString *)description {
  return [super description];
}

@end

@interface GULRuntimeClassSnapshotTests : XCTestCase

@end

@implementation GULRuntimeClassSnapshotTests

/** Tests initialization. */
- (void)testInitWithClass {
  Class NSObjectClass = [NSObject class];
  GULRuntimeClassSnapshot *snapshot = [[GULRuntimeClassSnapshot alloc] initWithClass:NSObjectClass];
  XCTAssertNotNil(snapshot);
}

/** Tests the ability to snapshot without throwing. */
- (void)testCapture {
  Class NSObjectClass = [NSObject class];
  GULRuntimeClassSnapshot *snapshot = [[GULRuntimeClassSnapshot alloc] initWithClass:NSObjectClass];
  XCTAssertNoThrow([snapshot capture]);
}

/** Tests that isEqual: of empty snapshots is YES. */
- (void)testDiffOfNoChanges {
  Class GULRuntimeClassSnapshotTestClassClass = [GULRuntimeClassSnapshotTestClass class];
  GULRuntimeClassSnapshot *snapshot1 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot1 capture];

  GULRuntimeClassSnapshot *snapshot2 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot2 capture];

  GULRuntimeClassDiff *noChangeDiff = [[GULRuntimeClassDiff alloc] init];
  XCTAssertEqualObjects([snapshot1 diff:snapshot2], noChangeDiff);
}

/** Tests that adding a class property is detected between two snapshots. */
- (void)testAddingAClassPropertyDetected {
  Class GULRuntimeClassSnapshotTestClassClass = [GULRuntimeClassSnapshotTestClass class];
  Class GULRuntimeClassSnapshotTestClassMetaClass =
      objc_getMetaClass([NSStringFromClass(GULRuntimeClassSnapshotTestClassClass) UTF8String]);
  GULRuntimeClassSnapshot *snapshot1 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot1 capture];

  // Reference:
  objc_property_attribute_t type = {"T", "@\"NSString\""};
  objc_property_attribute_t ownership = {"C", ""};
  objc_property_attribute_t backingivar = {"V", "dynamicClassBacking"};
  objc_property_attribute_t attributes[] = {type, ownership, backingivar};
  class_addProperty(GULRuntimeClassSnapshotTestClassMetaClass, "dynamicClassProperty", attributes,
                    3);

  GULRuntimeClassSnapshot *snapshot2 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot2 capture];

  GULRuntimeClassDiff *diff = [snapshot1 diff:snapshot2];
  XCTAssertEqual(diff.addedClassProperties.count, 1);
  XCTAssertEqualObjects(diff.addedClassProperties.anyObject, @"dynamicClassProperty");
}

/** Tests that adding an instance property is detected between two snapshots. */
- (void)testAddingAnInstancePropertyDetected {
  Class GULRuntimeClassSnapshotTestClassClass = [GULRuntimeClassSnapshotTestClass class];

  GULRuntimeClassSnapshot *snapshot1 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot1 capture];

  // Reference:
  objc_property_attribute_t type = {"T", "@\"NSString\""};
  objc_property_attribute_t ownership = {"C", ""};
  objc_property_attribute_t backingivar = {"V", "_dynamicPropertyIvar"};
  objc_property_attribute_t attributes[] = {type, ownership, backingivar};
  class_addProperty(GULRuntimeClassSnapshotTestClassClass, "dynamicProperty", attributes, 3);

  GULRuntimeClassSnapshot *snapshot2 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot2 capture];

  GULRuntimeClassDiff *diff = [snapshot1 diff:snapshot2];
  XCTAssertEqual(diff.addedInstanceProperties.count, 1);
  XCTAssertEqualObjects(diff.addedInstanceProperties.anyObject, @"dynamicProperty");
}

/** Tests that adding a class selector is detected between two snapshots. */
- (void)testAddingAClassMethodDetected {
  Class GULRuntimeClassSnapshotTestClassClass = [GULRuntimeClassSnapshotTestClass class];
  Class GULRuntimeClassSnapshotTestClassMetaClass =
      objc_getMetaClass([NSStringFromClass(GULRuntimeClassSnapshotTestClassClass) UTF8String]);

  GULRuntimeClassSnapshot *snapshot1 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot1 capture];

  SEL selector = _cmd;
  Method method = class_getInstanceMethod([self class], selector);
  IMP imp = method_getImplementation(method);
  const char *typeEncoding = method_getTypeEncoding(method);
  class_addMethod(GULRuntimeClassSnapshotTestClassMetaClass, selector, imp, typeEncoding);

  GULRuntimeClassSnapshot *snapshot2 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot2 capture];

  GULRuntimeClassDiff *simpleChangeDiff = [[GULRuntimeClassDiff alloc] init];
  simpleChangeDiff.aClass = GULRuntimeClassSnapshotTestClassClass;
  NSString *selectorString = NSStringFromSelector(selector);
  simpleChangeDiff.addedClassSelectors = [[NSSet alloc] initWithObjects:selectorString, nil];
  GULRuntimeClassDiff *snapShotDiff = [snapshot1 diff:snapshot2];
  XCTAssertEqualObjects(snapShotDiff, simpleChangeDiff);
}

/** Tests that adding an instance selector is detected between two snapshots. */
- (void)testAddingAnInstanceMethodDetected {
  Class GULRuntimeClassSnapshotTestClassClass = [GULRuntimeClassSnapshotTestClass class];
  GULRuntimeClassSnapshot *snapshot1 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot1 capture];

  SEL selector = _cmd;
  Method method = class_getInstanceMethod([self class], selector);
  IMP imp = method_getImplementation(method);
  const char *typeEncoding = method_getTypeEncoding(method);
  class_addMethod(GULRuntimeClassSnapshotTestClassClass, selector, imp, typeEncoding);

  GULRuntimeClassSnapshot *snapshot2 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot2 capture];

  GULRuntimeClassDiff *simpleChangeDiff = [[GULRuntimeClassDiff alloc] init];
  simpleChangeDiff.aClass = GULRuntimeClassSnapshotTestClassClass;
  NSString *selectorString = NSStringFromSelector(selector);
  simpleChangeDiff.addedInstanceSelectors = [[NSSet alloc] initWithObjects:selectorString, nil];
  GULRuntimeClassDiff *snapShotDiff = [snapshot1 diff:snapshot2];
  XCTAssertEqualObjects(snapShotDiff, simpleChangeDiff);
}

/** Tests that modifying the IMP of a class selector is detected between two snapshots. */
- (void)testModifiedClassImp {
  Class GULRuntimeClassSnapshotTestClassClass = [GULRuntimeClassSnapshotTestClass class];
  Class GULRuntimeClassSnapshotTestClassMetaClass =
      objc_getMetaClass([NSStringFromClass(GULRuntimeClassSnapshotTestClassClass) UTF8String]);

  GULRuntimeClassSnapshot *snapshot1 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot1 capture];

  SEL selector = @selector(description);
  Method method = class_getInstanceMethod(GULRuntimeClassSnapshotTestClassMetaClass, selector);
  IMP originalImp = method_getImplementation(method);
  IMP imp = imp_implementationWithBlock(^NSString *(id _self) {
    return @"fakeDescription";
  });

  IMP probableOriginalImp = method_setImplementation(method, imp);
  XCTAssertEqual(probableOriginalImp, originalImp);

  IMP imp2 = method_getImplementation(method);
  XCTAssertEqual(imp2, imp);

  GULRuntimeClassSnapshot *snapshot2 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot2 capture];

  GULRuntimeClassDiff *snapshotDiff = [snapshot1 diff:snapshot2];

  XCTAssertNotNil(snapshotDiff.modifiedImps);
  XCTAssertEqual(snapshotDiff.modifiedImps.count, 1);
  NSString *originalImpAddress = [NSString stringWithFormat:@"%p", originalImp];
  NSString *modifiedImp = [snapshotDiff.modifiedImps anyObject];
  XCTAssertTrue([modifiedImp containsString:@"+["]);
  XCTAssertTrue([modifiedImp containsString:originalImpAddress]);
}

/** Tests that modifying the IMP of an instance selector is detected between two snapshots. */
- (void)testModifiedInstanceImp {
  Class GULRuntimeClassSnapshotTestClassClass = [GULRuntimeClassSnapshotTestClass class];
  GULRuntimeClassSnapshot *snapshot1 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot1 capture];

  SEL selector = @selector(description);
  Method method = class_getInstanceMethod(GULRuntimeClassSnapshotTestClassClass, selector);
  IMP originalImp = method_getImplementation(method);
  IMP imp = imp_implementationWithBlock(^NSString *(id _self) {
    return @"fakeDescription";
  });

  IMP probableOriginalImp = method_setImplementation(method, imp);
  XCTAssertEqual(probableOriginalImp, originalImp);

  IMP imp2 = method_getImplementation(method);
  XCTAssertEqual(imp2, imp);

  GULRuntimeClassSnapshot *snapshot2 =
      [[GULRuntimeClassSnapshot alloc] initWithClass:GULRuntimeClassSnapshotTestClassClass];
  [snapshot2 capture];

  GULRuntimeClassDiff *snapshotDiff = [snapshot1 diff:snapshot2];

  XCTAssertNotNil(snapshotDiff.modifiedImps);
  XCTAssertEqual(snapshotDiff.modifiedImps.count, 1);
  NSString *originalImpAddress = [NSString stringWithFormat:@"%p", originalImp];
  NSString *modifiedImp = [snapshotDiff.modifiedImps anyObject];
  XCTAssertTrue([modifiedImp containsString:@"-["]);
  XCTAssertTrue([modifiedImp containsString:originalImpAddress]);
}

@end
