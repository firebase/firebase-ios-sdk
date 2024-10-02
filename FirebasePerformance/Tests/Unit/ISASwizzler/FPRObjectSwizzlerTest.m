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

#import "FirebasePerformance/Sources/ISASwizzler/FPRObjectSwizzler+Internal.h"
#import "FirebasePerformance/Sources/ISASwizzler/FPRSwizzledObject.h"

#import "FirebasePerformance/Tests/Unit/ISASwizzler/FPRProxy.h"

@interface FPRObjectSwizzlerTest : XCTestCase

@end

@implementation FPRObjectSwizzlerTest

/** Used as a donor method to add a method that doesn't exist on the superclass. */
- (NSString *)donorDescription {
  return @"SwizzledDonorDescription";
}

/** Used as a donor method to add a method that exists on the superclass. */
- (NSString *)description {
  return @"SwizzledDescription";
}

/** Exists just as a donor method. */
- (void)donorMethod {
}

- (void)testRetainedAssociatedObjects {
  NSObject *object = [[NSObject alloc] init];
  NSObject *associatedObject = [[NSObject alloc] init];
  size_t addressOfAssociatedObject = (size_t)&associatedObject;
  [FPRObjectSwizzler setAssociatedObject:object
                                     key:@"test"
                                   value:associatedObject
                             association:GUL_ASSOCIATION_RETAIN];
  associatedObject = nil;
  associatedObject = [FPRObjectSwizzler getAssociatedObject:object key:@"test"];
  XCTAssertEqual((size_t)&associatedObject, addressOfAssociatedObject);
  XCTAssertNotNil(associatedObject);
}

/** Tests that creating an object swizzler works. */
- (void)testObjectSwizzlerInit {
  NSObject *object = [[NSObject alloc] init];
  FPRObjectSwizzler *objectSwizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
  XCTAssertNotNil(objectSwizzler);
}

/** Tests that you're able to swizzle an object. */
- (void)testSwizzle {
  NSObject *object = [[NSObject alloc] init];
  FPRObjectSwizzler *objectSwizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
  XCTAssertEqual([object class], [NSObject class]);
  [objectSwizzler swizzle];
  XCTAssertNotEqual([object class], [NSObject class]);
  XCTAssertTrue([[object class] isSubclassOfClass:[NSObject class]]);
  XCTAssertTrue([object respondsToSelector:@selector(gul_class)]);
}

/** Tests that swizzling a nil object fails. */
- (void)testSwizzleNil {
  NSObject *object = [[NSObject alloc] init];
  FPRObjectSwizzler *objectSwizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
  XCTAssertEqual([object class], [NSObject class]);
  object = nil;
  XCTAssertThrows([objectSwizzler swizzle]);
}

/** Tests the ability to copy a selector from one class to the swizzled object's generated class. */
- (void)testCopySelectorFromClassIsClassSelectorAndSwizzle {
  NSObject *object = [[NSObject alloc] init];
  FPRObjectSwizzler *objectSwizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
  [objectSwizzler copySelector:@selector(donorMethod) fromClass:[self class] isClassSelector:NO];
  XCTAssertFalse([object respondsToSelector:@selector(donorMethod)]);
  XCTAssertFalse([[object class] instancesRespondToSelector:@selector(donorMethod)]);
  [objectSwizzler swizzle];
  XCTAssertTrue([object respondsToSelector:@selector(donorMethod)]);
  // [object class] should return the original class, not the swizzled class.
  XCTAssertTrue(
      [[(FPRSwizzledObject *)object gul_class] instancesRespondToSelector:@selector(donorMethod)]);
}

/** Tests that some helper methods are always added to swizzled objects. */
- (void)testCommonSelectorsAddedUponSwizzling {
  NSObject *object = [[NSObject alloc] init];
  FPRObjectSwizzler *objectSwizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
  XCTAssertFalse([object respondsToSelector:@selector(gul_class)]);
  [objectSwizzler swizzle];
  XCTAssertTrue([object respondsToSelector:@selector(gul_class)]);
}

/** Tests that there's no retain cycle and that -dealloc causes unswizzling. */
- (void)testRetainCycleDoesntExistAndDeallocCausesUnswizzling {
  NSObject *object = [[NSObject alloc] init];
  FPRObjectSwizzler *objectSwizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
  [objectSwizzler copySelector:@selector(donorMethod) fromClass:[self class] isClassSelector:NO];
  [objectSwizzler swizzle];
  // If objectSwizzler were used, the strong reference would make it live to the end of this test.
  // We want to make sure it dies when the object dies, hence the weak reference.
  __weak FPRObjectSwizzler *weakObjectSwizzler = objectSwizzler;
  objectSwizzler = nil;
  XCTAssertNotNil(weakObjectSwizzler);
  object = nil;
  XCTAssertNil(weakObjectSwizzler);
}

/** Tests the class get/set associated object methods. */
- (void)testClassSetAssociatedObjectCopy {
  NSObject *object = [[NSObject alloc] init];
  NSDictionary *objectToBeAssociated = [[NSDictionary alloc] init];
  [FPRObjectSwizzler setAssociatedObject:object
                                     key:@"fir_key"
                                   value:objectToBeAssociated
                             association:GUL_ASSOCIATION_COPY];
  NSDictionary *returnedObject = [FPRObjectSwizzler getAssociatedObject:object key:@"fir_key"];
  XCTAssertEqualObjects(returnedObject, objectToBeAssociated);
}

/** Tests the class get/set associated object methods. */
- (void)testClassSetAssociatedObjectAssign {
  NSObject *object = [[NSObject alloc] init];
  NSDictionary *objectToBeAssociated = [[NSDictionary alloc] init];
  [FPRObjectSwizzler setAssociatedObject:object
                                     key:@"fir_key"
                                   value:objectToBeAssociated
                             association:GUL_ASSOCIATION_ASSIGN];
  NSDictionary *returnedObject = [FPRObjectSwizzler getAssociatedObject:object key:@"fir_key"];
  XCTAssertEqualObjects(returnedObject, objectToBeAssociated);
}

/** Tests the class get/set associated object methods. */
- (void)testClassSetAssociatedObjectRetain {
  NSObject *object = [[NSObject alloc] init];
  NSDictionary *objectToBeAssociated = [[NSDictionary alloc] init];
  [FPRObjectSwizzler setAssociatedObject:object
                                     key:@"fir_key"
                                   value:objectToBeAssociated
                             association:GUL_ASSOCIATION_RETAIN];
  NSDictionary *returnedObject = [FPRObjectSwizzler getAssociatedObject:object key:@"fir_key"];
  XCTAssertEqualObjects(returnedObject, objectToBeAssociated);
}

/** Tests the class get/set associated object methods. */
- (void)testClassSetAssociatedObjectCopyNonatomic {
  NSObject *object = [[NSObject alloc] init];
  NSDictionary *objectToBeAssociated = [[NSDictionary alloc] init];
  [FPRObjectSwizzler setAssociatedObject:object
                                     key:@"fir_key"
                                   value:objectToBeAssociated
                             association:GUL_ASSOCIATION_COPY_NONATOMIC];
  NSDictionary *returnedObject = [FPRObjectSwizzler getAssociatedObject:object key:@"fir_key"];
  XCTAssertEqualObjects(returnedObject, objectToBeAssociated);
}

/** Tests the class get/set associated object methods. */
- (void)testClassSetAssociatedObjectRetainNonatomic {
  NSObject *object = [[NSObject alloc] init];
  NSDictionary *objectToBeAssociated = [[NSDictionary alloc] init];
  [FPRObjectSwizzler setAssociatedObject:object
                                     key:@"fir_key"
                                   value:objectToBeAssociated
                             association:GUL_ASSOCIATION_RETAIN_NONATOMIC];
  NSDictionary *returnedObject = [FPRObjectSwizzler getAssociatedObject:object key:@"fir_key"];
  XCTAssertEqualObjects(returnedObject, objectToBeAssociated);
}

/** Tests the swizzler get/set associated object methods. */
- (void)testSetGetAssociatedObjectCopy {
  NSObject *object = [[NSObject alloc] init];
  NSDictionary *associatedObject = [[NSDictionary alloc] init];
  FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
  [swizzler setAssociatedObjectWithKey:@"key"
                                 value:associatedObject
                           association:GUL_ASSOCIATION_COPY];
  NSDictionary *returnedObject = [swizzler getAssociatedObjectForKey:@"key"];
  XCTAssertEqualObjects(returnedObject, associatedObject);
}

/** Tests the swizzler get/set associated object methods. */
- (void)testSetGetAssociatedObjectAssign {
  NSObject *object = [[NSObject alloc] init];
  NSDictionary *associatedObject = [[NSDictionary alloc] init];
  FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
  [swizzler setAssociatedObjectWithKey:@"key"
                                 value:associatedObject
                           association:GUL_ASSOCIATION_ASSIGN];
  NSDictionary *returnedObject = [swizzler getAssociatedObjectForKey:@"key"];
  XCTAssertEqualObjects(returnedObject, associatedObject);
}

/** Tests the swizzler get/set associated object methods. */
- (void)testSetGetAssociatedObjectRetain {
  NSObject *object = [[NSObject alloc] init];
  NSDictionary *associatedObject = [[NSDictionary alloc] init];
  FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
  [swizzler setAssociatedObjectWithKey:@"key"
                                 value:associatedObject
                           association:GUL_ASSOCIATION_RETAIN];
  NSDictionary *returnedObject = [swizzler getAssociatedObjectForKey:@"key"];
  XCTAssertEqualObjects(returnedObject, associatedObject);
}

/** Tests the swizzler get/set associated object methods. */
- (void)testSetGetAssociatedObjectCopyNonatomic {
  NSObject *object = [[NSObject alloc] init];
  NSDictionary *associatedObject = [[NSDictionary alloc] init];
  FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
  [swizzler setAssociatedObjectWithKey:@"key"
                                 value:associatedObject
                           association:GUL_ASSOCIATION_COPY_NONATOMIC];
  NSDictionary *returnedObject = [swizzler getAssociatedObjectForKey:@"key"];
  XCTAssertEqualObjects(returnedObject, associatedObject);
}

/** Tests the swizzler get/set associated object methods. */
- (void)testSetGetAssociatedObjectRetainNonatomic {
  NSObject *object = [[NSObject alloc] init];
  NSDictionary *associatedObject = [[NSDictionary alloc] init];
  FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
  [swizzler setAssociatedObjectWithKey:@"key"
                                 value:associatedObject
                           association:GUL_ASSOCIATION_RETAIN_NONATOMIC];
  NSDictionary *returnedObject = [swizzler getAssociatedObjectForKey:@"key"];
  XCTAssertEqualObjects(returnedObject, associatedObject);
}

/** Tests getting and setting an associated object with an invalid association type. */
- (void)testSetGetAssociatedObjectWithoutProperAssociation {
  NSObject *object = [[NSObject alloc] init];
  NSDictionary *associatedObject = [[NSDictionary alloc] init];
  FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
  [swizzler setAssociatedObjectWithKey:@"key" value:associatedObject association:1337];
  NSDictionary *returnedObject = [swizzler getAssociatedObjectForKey:@"key"];
  XCTAssertEqualObjects(returnedObject, associatedObject);
}

/** Tests using the FPRObjectSwizzler to swizzle an object wrapped in an NSProxy. */
- (void)testSwizzleProxiedObject {
  NSObject *object = [[NSObject alloc] init];
  FPRProxy *proxyObject = [FPRProxy proxyWithDelegate:object];
  FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:proxyObject];

  XCTAssertNoThrow([swizzler swizzle]);

  XCTAssertNotEqual(object_getClass(proxyObject), [FPRProxy class]);
  XCTAssertTrue([object_getClass(proxyObject) isSubclassOfClass:[FPRProxy class]]);

  XCTAssertTrue([proxyObject respondsToSelector:@selector(gul_objectSwizzler)]);
  XCTAssertNoThrow([proxyObject performSelector:@selector(gul_objectSwizzler)]);

  XCTAssertTrue([proxyObject respondsToSelector:@selector(gul_class)]);
  XCTAssertNoThrow([proxyObject performSelector:@selector(gul_class)]);
}

/** Tests overriding a method that already exists on a proxied object works as expected. */
- (void)testSwizzleProxiedObjectInvokesInjectedMethodWhenOverridingMethod {
  NSObject *object = [[NSObject alloc] init];
  FPRProxy *proxyObject = [FPRProxy proxyWithDelegate:object];

  FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:proxyObject];
  [swizzler copySelector:@selector(description)
               fromClass:[FPRObjectSwizzlerTest class]
         isClassSelector:NO];
  [swizzler swizzle];

  XCTAssertEqual([proxyObject performSelector:@selector(description)], @"SwizzledDescription");
}

/** Tests adding a method that doesn't exist on a proxied object works as expected. */
- (void)testSwizzleProxiedObjectInvokesInjectedMethodWhenAddingMethod {
  NSObject *object = [[NSObject alloc] init];
  FPRProxy *proxyObject = [FPRProxy proxyWithDelegate:object];

  FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:proxyObject];
  [swizzler copySelector:@selector(donorDescription)
               fromClass:[FPRObjectSwizzlerTest class]
         isClassSelector:NO];
  [swizzler swizzle];

  XCTAssertEqual([proxyObject performSelector:@selector(donorDescription)],
                 @"SwizzledDonorDescription");
}

/** Tests KVOing a proxy object that we've ISA Swizzled works as expected. */
- (void)testRespondsToSelectorWorksEvenIfSwizzledProxyIsKVOd {
  NSObject *object = [[NSObject alloc] init];
  FPRProxy *proxyObject = [FPRProxy proxyWithDelegate:object];

  FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:proxyObject];
  [swizzler copySelector:@selector(donorDescription)
               fromClass:[FPRObjectSwizzlerTest class]
         isClassSelector:NO];
  [swizzler swizzle];

  [(NSObject *)proxyObject addObserver:self
                            forKeyPath:NSStringFromSelector(@selector(description))
                               options:0
                               context:NULL];

  XCTAssertTrue([proxyObject respondsToSelector:@selector(donorDescription)]);
  XCTAssertEqual([proxyObject performSelector:@selector(donorDescription)],
                 @"SwizzledDonorDescription");

  [(NSObject *)proxyObject removeObserver:self
                               forKeyPath:NSStringFromSelector(@selector(description))];
}

// TODO: Investigate why this test fails in Swift PM build.

/** Tests that -[NSObjectProtocol respondsToSelector:] works as expected after someone else ISA
 *  swizzles a proxy object that we've also ISA Swizzled.
 */
- (void)testRespondsToSelectorWorksEvenIfSwizzledProxyISASwizzledBySomeoneElse {
  Class generatedClass = nil;
  __weak FPRObjectSwizzler *weakSwizzler;

  @autoreleasepool {
    NSObject *object = [[NSObject alloc] init];
    FPRProxy *proxyObject = [FPRProxy proxyWithDelegate:object];

    FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:proxyObject];
    weakSwizzler = swizzler;
    [swizzler copySelector:@selector(donorDescription)
                 fromClass:[FPRObjectSwizzlerTest class]
           isClassSelector:NO];
    [swizzler swizzle];

    // Someone else ISA Swizzles the same object after FPRObjectSwizzler.
    Class originalClass = object_getClass(proxyObject);
    NSString *newClassName = [NSString
        stringWithFormat:@"gul_test_%p_%@", proxyObject, NSStringFromClass(originalClass)];
    generatedClass = objc_allocateClassPair(originalClass, newClassName.UTF8String, 0);
    objc_registerClassPair(generatedClass);
    object_setClass(proxyObject, generatedClass);

    XCTAssertTrue([proxyObject respondsToSelector:@selector(donorDescription)]);
    XCTAssertEqual([proxyObject performSelector:@selector(donorDescription)],
                   @"SwizzledDonorDescription");

    // Release FPRObjectSwizzler
    [FPRObjectSwizzler setAssociatedObject:proxyObject
                                       key:&kGULSwizzlerAssociatedObjectKey
                                     value:nil
                               association:GUL_ASSOCIATION_RETAIN];
  }
  XCTAssertNil(weakSwizzler);

  // Clean up.
  objc_disposeClassPair(generatedClass);
}

#if !TARGET_OS_MACCATALYST
// Test fails on Catalyst due to an interaction with GULSceneDelegateSwizzlerTests.

- (void)testSwizzlerDoesntDisposeGeneratedClassWhenObjectIsISASwizzledBySomeoneElse {
  Class generatedClass = nil;
  __weak FPRObjectSwizzler *weakSwizzler;

  XCTestExpectation *swizzlerDeallocatedExpectation =
      [self expectationWithDescription:@"swizzlerDeallocatedExpectation"];

  @autoreleasepool {
    NSObject *object = [[NSObject alloc] init];

    @autoreleasepool {
      FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
      weakSwizzler = swizzler;
      [swizzler copySelector:@selector(donorDescription)
                   fromClass:[FPRObjectSwizzlerTest class]
             isClassSelector:NO];
      [swizzler swizzle];
    }

    // Someone else ISA Swizzles the same object after FPRObjectSwizzler.
    Class originalClass = object_getClass(object);
    NSString *newClassName =
        [NSString stringWithFormat:@"gul_test_%p_%@", object, NSStringFromClass(originalClass)];
    generatedClass = objc_allocateClassPair(originalClass, newClassName.UTF8String, 0);
    objc_registerClassPair(generatedClass);
    object_setClass(object, generatedClass);

    // Release FPRObjectSwizzler
    [FPRObjectSwizzler setAssociatedObject:object
                                       key:&kGULSwizzlerAssociatedObjectKey
                                     value:nil
                               association:GUL_ASSOCIATION_RETAIN];

    // Wait for a while
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     [swizzlerDeallocatedExpectation fulfill];
                   });

    [self waitForExpectations:@[ swizzlerDeallocatedExpectation ] timeout:2];

    XCTAssertNil(weakSwizzler);
    // A class generated by FPRObjectSwizzler must not be disposed if there is its subclass.
    XCTAssertNoThrow([generatedClass description]);
  }

  // Clean up.
  objc_disposeClassPair(generatedClass);
}
#endif

// The test is disabled because in the case of success it should crash with SIGABRT, so it is not
// suitable for CI.
- (void)disabledForCI_testSwizzlerDisposesGeneratedClass {
  __weak FPRObjectSwizzler *weakSwizzler;

  XCTestExpectation *swizzlerDeallocatedExpectation =
      [self expectationWithDescription:@"swizzlerDeallocatedExpectation"];

  @autoreleasepool {
    NSObject *object = [[NSObject alloc] init];

    @autoreleasepool {
      FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:object];
      weakSwizzler = swizzler;
      [swizzler copySelector:@selector(donorDescription)
                   fromClass:[FPRObjectSwizzlerTest class]
             isClassSelector:NO];
      [swizzler swizzle];
    }

    // Release FPRObjectSwizzler
    [FPRObjectSwizzler setAssociatedObject:object
                                       key:&kGULSwizzlerAssociatedObjectKey
                                     value:nil
                               association:GUL_ASSOCIATION_RETAIN];

    // Wait for a while until FPRObjectSwizzler has disposed the generated class.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     [swizzlerDeallocatedExpectation fulfill];
                   });

    [self waitForExpectations:@[ swizzlerDeallocatedExpectation ] timeout:2];

    XCTAssertNil(weakSwizzler);

    // Must crash here with SIGABRT.
    XCTAssertThrows([object description]);
    XCTFail(@"The test must have crashed on the previous line.");
  }
}

- (void)testMultiSwizzling {
  NSObject *object = [[NSObject alloc] init];

  __weak FPRObjectSwizzler *existingSwizzler;

  // Use @autoreleasepool to make the memory management in the test more deterministic.
  @autoreleasepool {
    NSInteger swizzleCount = 10;
    for (NSInteger i = 0; i < swizzleCount; i++) {
      FPRObjectSwizzler *swizzler = [[FPRObjectSwizzler alloc] initWithObject:object];

      if (i > 0) {
        XCTAssertEqualObjects(swizzler, existingSwizzler,
                              @"There must be a single swizzler per object.");
      } else {
        existingSwizzler = swizzler;
      }

      [swizzler copySelector:@selector(donorDescription)
                   fromClass:[FPRObjectSwizzlerTest class]
             isClassSelector:NO];
      [swizzler swizzle];
    }

    XCTAssertNoThrow([object performSelector:@selector(donorDescription)]);
    object = nil;
  }

  XCTAssertNil(existingSwizzler,
               @"FPRObjectSwizzler must be deallocated after the object deallocation.");
}

@end
