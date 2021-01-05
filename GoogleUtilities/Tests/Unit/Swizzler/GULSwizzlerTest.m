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

#import "GoogleUtilities/MethodSwizzler/Public/GoogleUtilities/GULOriginalIMPConvenienceMacros.h"
#import "GoogleUtilities/MethodSwizzler/Public/GoogleUtilities/GULSwizzler.h"
#import "GoogleUtilities/SwizzlerTestHelpers/Public/GoogleUtilities/GULSwizzler+Unswizzle.h"

@interface TestObject : NSObject

@end

@implementation TestObject

+ (NSString *)description {
  return [[super description] stringByAppendingString:@" and here's my addition: BLAH BLAH"];
}

// This method is used to help test swizzling a method that calls super.
- (NSString *)description {
  return [NSString stringWithFormat:@"TestObject, superclass: %@", [super description]];
}

/** This method is used to test invoking an original instance IMP with one argument.
 * @return A description string.
 */
- (NSString *)descriptionThatSays:(NSString *)something {
  return [@"instance:" stringByAppendingString:something];
}

/** This method is used to test invoking an original class IMP with one argument.
 *  @return A description string.
 */
+ (NSString *)descriptionThatSays:(NSString *)something {
  return [@"class:" stringByAppendingString:something];
}

@end

@interface TestObjectSubclass : TestObject

@end

@implementation TestObjectSubclass

@end

@interface GULSwizzlerTest : XCTestCase

@end

@implementation GULSwizzlerTest

/** Tests originalImplementationForClass:selector:isClassSelector: returns the original instance
 *  IMP.
 */
- (void)testOriginalImpInstanceMethod {
  Method method = class_getInstanceMethod([NSObject class], @selector(description));
  IMP originalImp = method_getImplementation(method);
  NSString * (^newImplementation)(void) = ^NSString *() {
    return @"nonsense";
  };

  [GULSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];
  IMP returnedImp = [GULSwizzler originalImplementationForClass:[NSObject class]
                                                       selector:@selector(description)
                                                isClassSelector:NO];
  XCTAssertEqual(returnedImp, originalImp);
  [GULSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:NO];
}

/** Tests currentImplementationForClass:selector:isClassSelector: returns different IMPs for class
 *  and instance methods.
 */
- (void)testCurrentImplementationReturnsDifferentIMPsForClassAndInstanceMethod {
  Class aClass = [NSObject class];
  SEL aSelector = @selector(description);
  IMP descriptionClassIMP = [GULSwizzler currentImplementationForClass:aClass
                                                              selector:aSelector
                                                       isClassSelector:NO];
  IMP descriptionInstanceIMP = [GULSwizzler currentImplementationForClass:aClass
                                                                 selector:aSelector
                                                          isClassSelector:YES];
  XCTAssertNotEqual(descriptionClassIMP, descriptionInstanceIMP);
}

/** Tests currentImplementationForClass:selector:isClassSelector: returns the same IMP twice when it
 *  hasn't been swizzled.
 */
- (void)testCurrentImplementationReturnsSameIMPsWhenNotSwizzledBetweenInvocations {
  Class aClass = [NSObject class];
  SEL aSelector = @selector(description);
  IMP descriptionClassIMPOne = [GULSwizzler currentImplementationForClass:aClass
                                                                 selector:aSelector
                                                          isClassSelector:NO];
  IMP descriptionClassIMPTwo = [GULSwizzler currentImplementationForClass:aClass
                                                                 selector:aSelector
                                                          isClassSelector:NO];
  XCTAssertEqual(descriptionClassIMPOne, descriptionClassIMPTwo);
}

/** Tests currentImplementationForClass:selector:isClassSelector: returns a different IMP when it
 *  has been swizzled.
 */
- (void)testCurrentImplementationReturnsDifferentIMPsWhenSwizzledBetweenInvocations {
  Class aClass = [NSObject class];
  SEL aSelector = @selector(description);
  IMP originalIMP = [GULSwizzler currentImplementationForClass:aClass
                                                      selector:aSelector
                                               isClassSelector:NO];
  NSString * (^newImplementation)(id) = ^NSString *(id _self) {
    return @"nonsense";
  };
  [GULSwizzler swizzleClass:aClass
                   selector:aSelector
            isClassSelector:NO
                  withBlock:newImplementation];
  IMP newIMP = [GULSwizzler currentImplementationForClass:aClass
                                                 selector:aSelector
                                          isClassSelector:NO];
  XCTAssertNotEqual(newIMP, originalIMP);
  [GULSwizzler unswizzleClass:aClass selector:aSelector isClassSelector:NO];
}

/** Tests that invoking an original IMP in a swizzled IMP calls through correctly. */
- (void)testOriginalImpCallThrough {
  SEL selector = @selector(description);
  Class aClass = [NSObject class];
  id newDescription = ^NSString *(id object) {
    IMP originalImp = [GULSwizzler originalImplementationForClass:aClass
                                                         selector:selector
                                                  isClassSelector:NO];
    NSString *originalDescription =
        GUL_INVOKE_ORIGINAL_IMP0(object, selector, NSString *, originalImp);

    return [originalDescription stringByAppendingString:@"SWIZZLED!"];
  };

  [GULSwizzler swizzleClass:aClass selector:selector isClassSelector:NO withBlock:newDescription];
  NSString *result = [[[NSObject alloc] init] description];
  XCTAssertGreaterThan([result rangeOfString:@"SWIZZLED!"].location, 0);
  [GULSwizzler unswizzleClass:aClass selector:selector isClassSelector:NO];
}

/** Tests originalImplementationForClass:selector:isClassSelector: returns the original class IMP.
 */
- (void)testOriginalImpClassMethod {
  Method method = class_getInstanceMethod([NSObject class], @selector(description));
  IMP originalImp = method_getImplementation(method);
  NSString * (^newImplementation)(void) = ^NSString *() {
    return @"nonsense";
  };

  [GULSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];
  IMP returnedImp = [GULSwizzler originalImplementationForClass:[NSObject class]
                                                       selector:@selector(description)
                                                isClassSelector:NO];
  XCTAssertEqual(returnedImp, originalImp);
  [GULSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:NO];
}

/** Tests originalImplementationForClass:selector:isClassSelector: returns different IMPs for
 *  instance methods and class methods of the same name (like -/+ description).
 */
- (void)testOriginalImpInstanceAndClassImpsAreDifferent {
  Method instanceMethod = class_getInstanceMethod([NSObject class], @selector(description));
  Method classMethod = class_getClassMethod([NSObject class], @selector(description));
  IMP instanceImp = method_getImplementation(instanceMethod);
  IMP classImp = method_getImplementation(classMethod);

  NSString * (^newImplementation)(void) = ^NSString *() {
    return @"nonsense";
  };

  [GULSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];

  [GULSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertNotEqual(instanceMethod, classMethod);
  IMP returnedInstanceImp = [GULSwizzler originalImplementationForClass:[NSObject class]
                                                               selector:@selector(description)
                                                        isClassSelector:NO];
  IMP returnedClassImp = [GULSwizzler originalImplementationForClass:[NSObject class]
                                                            selector:@selector(description)
                                                     isClassSelector:YES];
  XCTAssertNotEqual(instanceImp, classImp);
  XCTAssertNotEqual(returnedInstanceImp, returnedClassImp);
  [GULSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:NO];
  [GULSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:YES];
}

/** Tests swizzling an instance method. */
- (void)testSwizzleInstanceMethod {
  NSString *swizzledDescription = @"Not what you expected!";
  NSString * (^newImplementation)(void) = ^NSString *() {
    return swizzledDescription;
  };

  [GULSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];
  NSString *returnedDescription = [[[NSObject alloc] init] description];
  XCTAssertEqualObjects(returnedDescription, swizzledDescription);
  [GULSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:NO];
}

/** Tests swizzling a class method. */
- (void)testSwizzleClassMethod {
  NSString *swizzledDescription = @"Swizzled class description";
  NSString * (^newImplementation)(void) = ^NSString *() {
    return swizzledDescription;
  };

  [GULSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqualObjects([NSObject description], swizzledDescription);
  [GULSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:YES];
}

/** Tests unswizzling an instance method. */
- (void)testUnswizzleInstanceMethod {
  NSObject *object = [[NSObject alloc] init];
  NSString *originalDescription = [object description];
  NSString *swizzledDescription = @"Swizzled description";
  NSString * (^newImplementation)(void) = ^NSString *() {
    return swizzledDescription;
  };

  [GULSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];
  NSString *returnedDescription = [object description];
  XCTAssertEqualObjects(returnedDescription, swizzledDescription);
  [GULSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:NO];
  returnedDescription = [object description];
  XCTAssertEqualObjects(returnedDescription, originalDescription);
}

/** Tests unswizzling a class method. */
- (void)testUnswizzleClassMethod {
  NSString *originalDescription = [NSObject description];
  NSString *swizzledDescription = @"Swizzled class description";
  NSString * (^newImplementation)(void) = ^NSString *() {
    return swizzledDescription;
  };

  [GULSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqualObjects([NSObject description], swizzledDescription);
  [GULSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:YES];
  XCTAssertEqualObjects([NSObject description], originalDescription);
}

/** Tests swizzling a class method doesn't swizzle an instance method of the same name. */
- (void)testSwizzlingAClassMethodDoesntSwizzleAnInstanceMethod {
  NSString *swizzledDescription = @"Swizzled class description";
  NSString * (^newImplementation)(void) = ^NSString *() {
    return swizzledDescription;
  };

  [GULSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqualObjects([NSObject description], swizzledDescription);
  XCTAssertNotEqualObjects([[[NSObject alloc] init] description], swizzledDescription);
  [GULSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:YES];
}

/** Tests swizzling an instance method doesn't swizzle a class method of the same name. */
- (void)testSwizzlingAnInstanceMethodDoesntSwizzleAClassMethod {
  NSString *swizzledDescription = @"Not what you expected!";
  NSString * (^newImplementation)(void) = ^NSString *() {
    return swizzledDescription;
  };

  [GULSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];
  NSString *returnedDescription = [[[NSObject alloc] init] description];
  XCTAssertEqual(returnedDescription, swizzledDescription);
  XCTAssertNotEqualObjects([NSObject description], swizzledDescription);
  [GULSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:NO];
}

/** Tests swizzling a superclass's instance method. */
- (void)testSwizzlingSuperclassInstanceMethod {
  NSObject *generalObject = [[NSObject alloc] init];
  BOOL generalObjectIsProxyValue = [generalObject isProxy];
  BOOL (^newImplementation)(void) = ^BOOL() {
    return !generalObjectIsProxyValue;
  };

  [GULSwizzler swizzleClass:[TestObject class]
                   selector:@selector(isProxy)
            isClassSelector:NO
                  withBlock:newImplementation];
  XCTAssertNotEqual([[[TestObject alloc] init] isProxy], generalObjectIsProxyValue);
  [GULSwizzler unswizzleClass:[TestObject class] selector:@selector(isProxy) isClassSelector:NO];
}

/** Tests swizzling a superclass's class method. */
- (void)testSwizzlingSuperclassClassMethod {
  NSString *swizzledDescription = @"Swizzled class description";
  NSString * (^newImplementation)(void) = ^NSString *() {
    return swizzledDescription;
  };

  [GULSwizzler swizzleClass:[TestObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqualObjects([TestObject description], swizzledDescription);
  [GULSwizzler unswizzleClass:[TestObject class]
                     selector:@selector(description)
              isClassSelector:YES];
}

/** Tests swizzling an instance method that calls into the superclass implementation. */
- (void)testSwizzlingInstanceMethodThatCallsSuper {
  TestObject *testObject = [[TestObject alloc] init];
  NSString *originalDescription = [testObject description];
  NSString *swizzledDescription = [originalDescription stringByAppendingString:@"SWIZZLED!"];
  NSString * (^newImplementation)(void) = ^NSString *() {
    return swizzledDescription;
  };

  [GULSwizzler swizzleClass:[TestObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];
  XCTAssertEqualObjects([testObject description], swizzledDescription);
  [GULSwizzler unswizzleClass:[TestObject class]
                     selector:@selector(description)
              isClassSelector:NO];
  XCTAssertEqualObjects([testObject description], originalDescription);
}

/** Tests swizzling a method and getting the original IMP of that method. */
- (void)testSwizzleAndGet {
  Class testClass = [NSURL class];
  SEL testSelector = @selector(description);
  IMP baseImp = class_getMethodImplementation(testClass, testSelector);
  [GULSwizzler swizzleClass:testClass
                   selector:testSelector
            isClassSelector:NO
                  withBlock:^{
                    return @"Swizzled Description";
                  }];
  IMP origImp = [GULSwizzler originalImplementationForClass:testClass
                                                   selector:testSelector
                                            isClassSelector:NO];
  XCTAssertEqual(origImp, baseImp, @"Original IMP and base IMP are not equal.");
  [GULSwizzler unswizzleClass:testClass selector:testSelector isClassSelector:NO];
}

/** Tests swizzling more than a single method at a time. */
- (void)testSwizzleMultiple {
  Class testClass = [NSURL class];
  SEL testSelector = @selector(description);
  [GULSwizzler swizzleClass:testClass
                   selector:testSelector
            isClassSelector:NO
                  withBlock:^{
                    return @"Swizzled Description";
                  }];
  IMP origImp = [GULSwizzler originalImplementationForClass:testClass
                                                   selector:testSelector
                                            isClassSelector:NO];
  Class testClass2 = [NSURLRequest class];
  SEL testSelector2 = @selector(debugDescription);
  [GULSwizzler swizzleClass:testClass2
                   selector:testSelector2
            isClassSelector:NO
                  withBlock:^{
                    return @"Swizzled Debug Description";
                  }];
  IMP origImp2 = [GULSwizzler originalImplementationForClass:testClass2
                                                    selector:testSelector2
                                             isClassSelector:NO];
  XCTAssertNotEqual(origImp2, NULL, @"Original IMP is NULL after swizzle.");
  XCTAssertNotEqual(origImp, origImp2, @"Implementations are the same when they should't be.");

  [GULSwizzler unswizzleClass:testClass selector:testSelector isClassSelector:NO];
  [GULSwizzler unswizzleClass:testClass2 selector:testSelector2 isClassSelector:NO];
}

/** Tests swizzling multiple instance methods on the same class at the same time */
- (void)testSwizzleMultipleInstanceMethodsOnSameClass {
  Class testClass = [TestObject class];
  SEL selectorOne = @selector(description);
  SEL selectorTwo = @selector(descriptionThatSays:);
  NSString * (^newImplementationDescription)(id, SEL) = ^NSString *(id _self, SEL cmd) {
    return @"SWIZZLED!";
  };
  NSString * (^newImplementationDescriptionThatSays)(TestObject *, NSString *) =
      ^NSString *(TestObject *_self, NSString *something) {
    return [something stringByAppendingString:@"SWIZZLED!"];
  };
  [GULSwizzler swizzleClass:testClass
                   selector:selectorOne
            isClassSelector:NO
                  withBlock:newImplementationDescription];
  [GULSwizzler swizzleClass:testClass
                   selector:selectorTwo
            isClassSelector:NO
                  withBlock:newImplementationDescriptionThatSays];
  TestObject *sampleObject = [[TestObject alloc] init];

  XCTAssertEqualObjects([sampleObject description], @"SWIZZLED!");
  XCTAssertEqualObjects([sampleObject descriptionThatSays:@"Name"], @"NameSWIZZLED!");

  [GULSwizzler unswizzleClass:testClass selector:selectorOne isClassSelector:NO];
  [GULSwizzler unswizzleClass:testClass selector:selectorTwo isClassSelector:NO];
}

/** Tests swizzling multiple class methods on the same class at the same time */
- (void)testSwizzleMultipleClassMethodsOnSameClass {
  Class testClass = [TestObject class];
  SEL selectorOne = @selector(description);
  SEL selectorTwo = @selector(descriptionThatSays:);
  NSString * (^newImplementationDescription)(id, SEL) = ^NSString *(id _self, SEL cmd) {
    return @"SWIZZLED!";
  };
  NSString * (^newImplementationDescriptionThatSays)(TestObject *, NSString *) =
      ^NSString *(TestObject *_self, NSString *something) {
    return [something stringByAppendingString:@"SWIZZLED!"];
  };
  [GULSwizzler swizzleClass:testClass
                   selector:selectorOne
            isClassSelector:YES
                  withBlock:newImplementationDescription];
  [GULSwizzler swizzleClass:testClass
                   selector:selectorTwo
            isClassSelector:YES
                  withBlock:newImplementationDescriptionThatSays];

  XCTAssertEqualObjects([TestObject description], @"SWIZZLED!");
  XCTAssertEqualObjects([TestObject descriptionThatSays:@"Name"], @"NameSWIZZLED!");

  [GULSwizzler unswizzleClass:testClass selector:selectorOne isClassSelector:YES];
  [GULSwizzler unswizzleClass:testClass selector:selectorTwo isClassSelector:YES];
}

/** Tests swizzling an instance method is correctly swizzled on multiple instances of the same
 *  class.
 */
- (void)testSwizzlingInstanceMethodIsEffectiveOnMultipleInstancesOfSameClass {
  Class testClass = [TestObject class];
  SEL selector = @selector(description);
  NSString * (^newImplementationDescription)(id, SEL) = ^NSString *(id _self, SEL cmd) {
    return @"SWIZZLED!";
  };
  [GULSwizzler swizzleClass:testClass
                   selector:selector
            isClassSelector:NO
                  withBlock:newImplementationDescription];

  TestObject *sampleObjectOne = [[TestObject alloc] init];
  TestObject *sampleObjectTwo = [[TestObject alloc] init];

  XCTAssertEqualObjects([sampleObjectOne description], @"SWIZZLED!");
  XCTAssertEqualObjects([sampleObjectTwo description], @"SWIZZLED!");

  [GULSwizzler unswizzleClass:testClass selector:selector isClassSelector:NO];
}

/** Tests swizzling a class method that calls into the superclass implementation. */
- (void)testSwizzlingClassMethodThatCallsSuper {
  NSString *originalDescription = [TestObject description];
  NSString *swizzledDescription = @"Swizzled class description";
  NSString * (^newImplementation)(void) = ^NSString *() {
    return swizzledDescription;
  };

  [GULSwizzler swizzleClass:[TestObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqualObjects([TestObject description], swizzledDescription);
  [GULSwizzler unswizzleClass:[TestObject class]
                     selector:@selector(description)
              isClassSelector:YES];
  XCTAssertEqualObjects([TestObject description], originalDescription);
}

/** Tests swizzling an inherited instance method doesn't change the implementation of the
 *  superclass's implementation of that same method.
 */
- (void)testSwizzlingAnInheritedInstanceMethodDoesntAffectTheIMPOfItsSuperclass {
  NSObject *generalObject = [[NSObject alloc] init];
  BOOL originalGeneralObjectValue = [generalObject isProxy];
  BOOL (^newImplementation)(void) = ^BOOL(void) {
    return !originalGeneralObjectValue;
  };

  [GULSwizzler swizzleClass:[TestObject class]
                   selector:@selector(isProxy)
            isClassSelector:NO
                  withBlock:newImplementation];
  XCTAssertEqual([generalObject isProxy], originalGeneralObjectValue);
  XCTAssertNotEqual([[[TestObject alloc] init] isProxy], originalGeneralObjectValue);
  [GULSwizzler unswizzleClass:[TestObject class] selector:@selector(isProxy) isClassSelector:NO];
  XCTAssertEqual([[[TestObject alloc] init] isProxy], originalGeneralObjectValue);
}

/** Tests swizzling an inherited instance method from a superclass a couple of links up in the
 *  chain of superclasses doesn't affect the implementation of the superclass's method.
 */
- (void)testSwizzlingADeeperInheritedInstanceMethodDoesntAffectTheIMPOfItsSuperclass {
  TestObject *testObject = [[TestObject alloc] init];
  BOOL originalTestObjectValue = [testObject isProxy];
  BOOL (^newImplementation)(void) = ^BOOL(void) {
    return !originalTestObjectValue;
  };

  [GULSwizzler swizzleClass:[TestObjectSubclass class]
                   selector:@selector(isProxy)
            isClassSelector:NO
                  withBlock:newImplementation];
  XCTAssertEqual([testObject isProxy], originalTestObjectValue);
  XCTAssertNotEqual([[[TestObjectSubclass alloc] init] isProxy], originalTestObjectValue);
  [GULSwizzler unswizzleClass:[TestObjectSubclass class]
                     selector:@selector(isProxy)
              isClassSelector:NO];
  XCTAssertEqual([[[TestObjectSubclass alloc] init] isProxy], originalTestObjectValue);
}

/** Tests swizzling an inherited class method doesn't change the implementation of the
 *  superclass's implementation of that same method.
 */
- (void)testSwizzlingAnInheritedClassMethodDoesntAffectTheIMPOfItsSuperclass {
  // Fun fact, this won't work on +new. Swizzling +new causes a retain to not be placed correctly.
  NSString *originalDescription = [TestObject description];
  NSString *swizzledDescription = [originalDescription stringByAppendingString:@"SWIZZLED!"];
  NSString * (^newImplementation)(void) = ^NSString *() {
    return swizzledDescription;
  };

  [GULSwizzler swizzleClass:[TestObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqualObjects([TestObject description], swizzledDescription);
  XCTAssertNotEqualObjects([NSObject description], swizzledDescription);
  [GULSwizzler unswizzleClass:[TestObject class]
                     selector:@selector(description)
              isClassSelector:YES];
  XCTAssertNotEqualObjects([TestObject description], swizzledDescription);
  XCTAssertNotEqualObjects([NSObject description], originalDescription);
}

/** Tests swizzling an inherited class method from a superclass a couple of links up in the
 *  chain of superclasses doesn't affect the implementation of the superclass's method.
 */
- (void)testSwizzlingADeeperInheritedClassMethodDoesntAffectTheIMPOfItsSuperclass {
  NSString *originalDescription = [TestObjectSubclass description];
  NSString *swizzledDescription = [originalDescription stringByAppendingString:@"SWIZZLED!"];
  NSString * (^newImplementation)(void) = ^NSString *() {
    return swizzledDescription;
  };

  [GULSwizzler swizzleClass:[TestObjectSubclass class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqualObjects([TestObjectSubclass description], swizzledDescription);
  XCTAssertNotEqualObjects([TestObject description], swizzledDescription);
  XCTAssertNotEqualObjects([NSObject description], swizzledDescription);
  [GULSwizzler unswizzleClass:[TestObjectSubclass class]
                     selector:@selector(description)
              isClassSelector:YES];
  XCTAssertNotEqualObjects([TestObjectSubclass description], swizzledDescription);
  XCTAssertNotEqualObjects([TestObject description], originalDescription);
  XCTAssertNotEqualObjects([NSObject description], originalDescription);
}

/** Tests invoking an original instance IMP that takes one argument. */
- (void)testInvokingOriginalInstanceIMPWithOneArgument {
  TestObject *testObject = [[TestObject alloc] init];
  NSString * (^replacingBlock)(TestObject *, NSString *) =
      ^NSString *(TestObject *_self, NSString *something) {
    return [something stringByAppendingString:@"SWIZZLED!"];
  };

  SEL swizzledSelector = @selector(descriptionThatSays:);
  [GULSwizzler swizzleClass:[TestObject class]
                   selector:swizzledSelector
            isClassSelector:NO
                  withBlock:replacingBlock];
  XCTAssertEqualObjects([testObject descriptionThatSays:@"something"], @"somethingSWIZZLED!");
  IMP originalIMP = [GULSwizzler originalImplementationForClass:[TestObject class]
                                                       selector:swizzledSelector
                                                isClassSelector:NO];
  NSString *originalDescriptionThatSaysSomething =
      GUL_INVOKE_ORIGINAL_IMP1(testObject, swizzledSelector, NSString *, originalIMP, @"something");
  XCTAssertEqualObjects(originalDescriptionThatSaysSomething, @"instance:something");
  [GULSwizzler unswizzleClass:[TestObject class] selector:swizzledSelector isClassSelector:NO];
}

/** Tests invoking an original class IMP that takes one argument. */
- (void)testInvokingOriginalClassIMPWithOneArgument {
  NSString * (^replacingBlock)(id, NSString *) = ^NSString *(id _self, NSString *something) {
    return [something stringByAppendingString:@"SWIZZLED!"];
  };

  SEL swizzledSelector = @selector(descriptionThatSays:);
  [GULSwizzler swizzleClass:[TestObject class]
                   selector:swizzledSelector
            isClassSelector:YES
                  withBlock:replacingBlock];
  XCTAssertEqualObjects([TestObject descriptionThatSays:@"something"], @"somethingSWIZZLED!");
  IMP originalIMP = [GULSwizzler originalImplementationForClass:[TestObject class]
                                                       selector:swizzledSelector
                                                isClassSelector:YES];
  NSString *originalDescriptionThatSaysSomething = GUL_INVOKE_ORIGINAL_IMP1(
      [TestObject class], swizzledSelector, NSString *, originalIMP, @"something");
  XCTAssertEqualObjects(originalDescriptionThatSaysSomething, @"class:something");
  [GULSwizzler unswizzleClass:[TestObject class] selector:swizzledSelector isClassSelector:YES];
}

/** Tests swizzling the same class SEL pair again works for class methods. */
- (void)testSwizzlingSameClassSELPairOnClassMethodWorksCorrectly {
  NSString * (^replacingBlock1)(id, NSString *) = ^NSString *(id _self, NSString *something) {
    return [something stringByAppendingString:@"SWIZZLED!"];
  };

  NSString * (^replacingBlock2)(id, NSString *) = ^NSString *(id _self, NSString *something) {
    return [something stringByAppendingString:@"SWIZZLED2!"];
  };

  SEL swizzledSelector = @selector(descriptionThatSays:);
  Class swizzledClass = [TestObject class];

  [GULSwizzler swizzleClass:swizzledClass
                   selector:swizzledSelector
            isClassSelector:YES
                  withBlock:replacingBlock1];

  XCTAssertEqualObjects([TestObject descriptionThatSays:@"something"], @"somethingSWIZZLED!");

  [GULSwizzler swizzleClass:swizzledClass
                   selector:swizzledSelector
            isClassSelector:YES
                  withBlock:replacingBlock2];

  XCTAssertEqualObjects([TestObject descriptionThatSays:@"something"], @"somethingSWIZZLED2!");

  [GULSwizzler unswizzleClass:[TestObject class] selector:swizzledSelector isClassSelector:YES];
}

/** Tests swizzling the same class SEL pair again works for instance methods. */
- (void)testSwizzlingSameClassSELPairOnInstanceMethodWorksCorrectly {
  NSString * (^replacingBlock1)(id, NSString *) = ^NSString *(id _self, NSString *something) {
    return [something stringByAppendingString:@"SWIZZLED!"];
  };

  NSString * (^replacingBlock2)(id, NSString *) = ^NSString *(id _self, NSString *something) {
    return [something stringByAppendingString:@"SWIZZLED2!"];
  };

  TestObject *testObject = [[TestObject alloc] init];

  SEL swizzledSelector = @selector(descriptionThatSays:);
  Class swizzledClass = [TestObject class];

  [GULSwizzler swizzleClass:swizzledClass
                   selector:swizzledSelector
            isClassSelector:NO
                  withBlock:replacingBlock1];

  XCTAssertEqualObjects([testObject descriptionThatSays:@"something"], @"somethingSWIZZLED!");

  [GULSwizzler swizzleClass:swizzledClass
                   selector:swizzledSelector
            isClassSelector:NO
                  withBlock:replacingBlock2];

  XCTAssertEqualObjects([testObject descriptionThatSays:@"something"], @"somethingSWIZZLED2!");

  [GULSwizzler unswizzleClass:[TestObject class] selector:swizzledSelector isClassSelector:NO];
}

/** Tests calling an IMP which was previously put in place by a consumer of GULSwizzler from inside
 *  a new IMP that a consumer of GULSwizzler is putting in place of that old IMP works correctly
 *  in case of instance methods.
 */
- (void)testWrappingAPreviouslySwizzledClassSELPairWithANewOneWorksOnInstanceMethods {
  NSString * (^replacingBlock1)(id, NSString *) = ^NSString *(id _self, NSString *something) {
    return [something stringByAppendingString:@"SWIZZLED!"];
  };
  TestObject *testObject = [[TestObject alloc] init];
  SEL swizzledSelector = @selector(descriptionThatSays:);
  Class swizzledClass = [TestObject class];

  [GULSwizzler swizzleClass:swizzledClass
                   selector:swizzledSelector
            isClassSelector:NO
                  withBlock:replacingBlock1];
  XCTAssertEqualObjects([testObject descriptionThatSays:@"something"], @"somethingSWIZZLED!");

  IMP previouslySwizzledIMP = [GULSwizzler currentImplementationForClass:swizzledClass
                                                                selector:swizzledSelector
                                                         isClassSelector:NO];
  NSString * (^replacingBlock2)(id, NSString *) = ^NSString *(id _self, NSString *something) {
    NSString *previousResult = GUL_INVOKE_ORIGINAL_IMP1(testObject, swizzledSelector, NSString *,
                                                        previouslySwizzledIMP, something);

    NSString *currentResult = [something stringByAppendingString:@"SWIZZLED2!"];
    return [previousResult stringByAppendingString:currentResult];
  };

  [GULSwizzler swizzleClass:swizzledClass
                   selector:swizzledSelector
            isClassSelector:NO
                  withBlock:replacingBlock2];
  XCTAssertEqualObjects([testObject descriptionThatSays:@"something"],
                        @"somethingSWIZZLED!somethingSWIZZLED2!");
  XCTAssertEqualObjects([testObject descriptionThatSays:@"anything"],
                        @"anythingSWIZZLED!anythingSWIZZLED2!");

  [GULSwizzler unswizzleClass:[TestObject class] selector:swizzledSelector isClassSelector:NO];
}

/** Tests calling an IMP which was previously put in place by a consumer of GULSwizzler from inside
 *  a new IMP that a consumer of GULSwizzler is putting in place of that old IMP works correctly
 *  in case of class methods.
 */

- (void)testWrappingAPreviouslySwizzledClassSELPairWithANewOneWorksOnClassMethods {
  NSString * (^replacingBlock1)(id, NSString *) = ^NSString *(id _self, NSString *something) {
    return [something stringByAppendingString:@"SWIZZLED!"];
  };

  SEL swizzledSelector = @selector(descriptionThatSays:);
  Class swizzledClass = [TestObject class];

  [GULSwizzler swizzleClass:swizzledClass
                   selector:swizzledSelector
            isClassSelector:YES
                  withBlock:replacingBlock1];

  XCTAssertEqualObjects([TestObject descriptionThatSays:@"something"], @"somethingSWIZZLED!");

  IMP previouslySwizzledIMP = [GULSwizzler currentImplementationForClass:swizzledClass
                                                                selector:swizzledSelector
                                                         isClassSelector:YES];
  NSString * (^replacingBlock2)(id, NSString *) = ^NSString *(id _self, NSString *something) {
    NSString *previousResult = GUL_INVOKE_ORIGINAL_IMP1(
        [TestObject class], swizzledSelector, NSString *, previouslySwizzledIMP, something);

    NSString *currentResult = [something stringByAppendingString:@"SWIZZLED2!"];
    return [previousResult stringByAppendingString:currentResult];
  };

  [GULSwizzler swizzleClass:swizzledClass
                   selector:swizzledSelector
            isClassSelector:YES
                  withBlock:replacingBlock2];
  XCTAssertEqualObjects([TestObject descriptionThatSays:@"something"],
                        @"somethingSWIZZLED!somethingSWIZZLED2!");
  XCTAssertEqualObjects([TestObject descriptionThatSays:@"anything"],
                        @"anythingSWIZZLED!anythingSWIZZLED2!");

  [GULSwizzler unswizzleClass:[TestObject class] selector:swizzledSelector isClassSelector:YES];
}

@end
