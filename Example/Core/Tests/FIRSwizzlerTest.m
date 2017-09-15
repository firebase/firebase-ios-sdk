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

#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#import "FirebaseCommunity/FIRSwizzler.h"

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

@end

@interface TestObjectSubclass : TestObject

@end

@implementation TestObjectSubclass

@end

@interface FIRSwizzlerTest : XCTestCase

@end

@implementation FIRSwizzlerTest

/** Tests originalImplementationForClass:selector:isClassSelector: returns the original instance
 *  IMP.
 */
- (void)testOriginalImpInstanceMethod {
  Method method = class_getInstanceMethod([NSObject class], @selector(description));
  IMP originalImp = method_getImplementation(method);
  NSString * (^newImplementation)() = ^NSString *() {
    return @"nonsense";
  };

  [FIRSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];
  IMP returnedImp = [FIRSwizzler originalImplementationForClass:[NSObject class]
                                                       selector:@selector(description)
                                                isClassSelector:NO];
  XCTAssertEqual(returnedImp, originalImp);
  [FIRSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:NO];
}

/** Tests that invoking an original IMP in a swizzled IMP calls through correctly. */
- (void)testOriginalImpCallThrough {
  SEL selector = @selector(description);
  Class aClass = [NSObject class];
  id newDescription = ^NSString *(id object) {
    IMP originalImp =
        [FIRSwizzler originalImplementationForClass:aClass selector:selector isClassSelector:NO];
    typedef NSString *(*OriginalImp)(id, SEL);
    NSString *originalDescription = ((OriginalImp)(originalImp))(object, selector);
    return [originalDescription stringByAppendingString:@"SWIZZLED!"];
  };

  [FIRSwizzler swizzleClass:aClass selector:selector isClassSelector:NO withBlock:newDescription];
  NSString *result = [[[NSObject alloc] init] description];
  XCTAssertGreaterThan([result rangeOfString:@"SWIZZLED!"].location, 0);
  [FIRSwizzler unswizzleClass:aClass selector:selector isClassSelector:NO];
}

/** Tests originalImplementationForClass:selector:isClassSelector: returns the original class IMP.
 */
- (void)testOriginalImpClassMethod {
  Method method = class_getInstanceMethod([NSObject class], @selector(description));
  IMP originalImp = method_getImplementation(method);
  NSString * (^newImplementation)() = ^NSString *() {
    return @"nonsense";
  };

  [FIRSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];
  IMP returnedImp = [FIRSwizzler originalImplementationForClass:[NSObject class]
                                                       selector:@selector(description)
                                                isClassSelector:NO];
  XCTAssertEqual(returnedImp, originalImp);
  [FIRSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:NO];
}

/** Tests originalImplementationForClass:selector:isClassSelector: returns different IMPs for
 *  instance methods and class methods of the same name (like -/+ description).
 */
- (void)testOriginalImpInstanceAndClassImpsAreDifferent {
  Method instanceMethod = class_getInstanceMethod([NSObject class], @selector(description));
  Method classMethod = class_getClassMethod([NSObject class], @selector(description));
  IMP instanceImp = method_getImplementation(instanceMethod);
  IMP classImp = method_getImplementation(classMethod);

  NSString * (^newImplementation)() = ^NSString *() {
    return @"nonsense";
  };

  [FIRSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];

  [FIRSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertNotEqual(instanceMethod, classMethod);
  IMP returnedInstanceImp = [FIRSwizzler originalImplementationForClass:[NSObject class]
                                                               selector:@selector(description)
                                                        isClassSelector:NO];
  IMP returnedClassImp = [FIRSwizzler originalImplementationForClass:[NSObject class]
                                                            selector:@selector(description)
                                                     isClassSelector:YES];
  XCTAssertNotEqual(instanceImp, classImp);
  XCTAssertNotEqual(returnedInstanceImp, returnedClassImp);
  [FIRSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:NO];
  [FIRSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:YES];
}

/** Tests swizzling an instance method. */
- (void)testSwizzleInstanceMethod {
  NSString *expectedDescription = @"Not what you expected!";
  NSString * (^newImplementation)() = ^NSString *() {
    return expectedDescription;
  };

  [FIRSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];
  NSString *returnedDescription = [[[NSObject alloc] init] description];
  XCTAssertEqualObjects(returnedDescription, expectedDescription);
  [FIRSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:NO];
}

/** Tests swizzling a class method. */
- (void)testSwizzleClassMethod {
  NSString *expectedDescription = @"Swizzled class description";
  NSString * (^newImplementation)() = ^NSString *() {
    return expectedDescription;
  };

  [FIRSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqualObjects([NSObject description], expectedDescription);
  [FIRSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:YES];
}

/** Tests unswizzling an instance method. */
- (void)testUnswizzleInstanceMethod {
  NSObject *object = [[NSObject alloc] init];
  NSString *originalDescription = [object description];
  NSString *swizzledDescription = @"Swizzled description";
  NSString * (^newImplementation)() = ^NSString *() {
    return swizzledDescription;
  };

  [FIRSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];
  NSString *returnedDescription = [object description];
  XCTAssertEqualObjects(returnedDescription, swizzledDescription);
  [FIRSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:NO];
  returnedDescription = [object description];
  XCTAssertEqualObjects(returnedDescription, originalDescription);
}

/** Tests unswizzling a class method. */
- (void)testUnswizzleClassMethod {
  NSString *originalDescription = [NSObject description];
  NSString *swizzledDescription = @"Swizzled class description";
  NSString * (^newImplementation)() = ^NSString *() {
    return swizzledDescription;
  };

  [FIRSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqualObjects([NSObject description], swizzledDescription);
  [FIRSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:YES];
  XCTAssertEqualObjects([NSObject description], originalDescription);
}

/** Tests swizzling a class method doesn't swizzle an instance method of the same name. */
- (void)testSwizzlingAClassMethodDoesntSwizzleAnInstanceMethod {
  NSString *expectedDescription = @"Swizzled class description";
  NSString * (^newImplementation)() = ^NSString *() {
    return expectedDescription;
  };

  [FIRSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqualObjects([NSObject description], expectedDescription);
  XCTAssertNotEqualObjects([[[NSObject alloc] init] description], expectedDescription);
  [FIRSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:YES];
}

/** Tests swizzling an instance method doesn't swizzle a class method of the same name. */
- (void)testSwizzlingAnInstanceMethodDoesntSwizzleAClassMethod {
  NSString *expectedDescription = @"Not what you expected!";
  NSString * (^newImplementation)() = ^NSString *() {
    return expectedDescription;
  };

  [FIRSwizzler swizzleClass:[NSObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];
  NSString *returnedDescription = [[[NSObject alloc] init] description];
  XCTAssertEqual(returnedDescription, expectedDescription);
  XCTAssertNotEqualObjects([NSObject description], expectedDescription);
  [FIRSwizzler unswizzleClass:[NSObject class] selector:@selector(description) isClassSelector:NO];
}

/** Tests swizzling a superclass's instance method. */
- (void)testSwizzlingSuperclassInstanceMethod {
  NSObject *generalObject = [[NSObject alloc] init];
  BOOL generalObjectIsProxyValue = [generalObject isProxy];
  BOOL (^newImplementation)() = ^BOOL() {
    return !generalObjectIsProxyValue;
  };

  [FIRSwizzler swizzleClass:[TestObject class]
                   selector:@selector(isProxy)
            isClassSelector:NO
                  withBlock:newImplementation];
  XCTAssertNotEqual([[[TestObject alloc] init] isProxy], generalObjectIsProxyValue);
  [FIRSwizzler unswizzleClass:[TestObject class] selector:@selector(isProxy) isClassSelector:NO];
}

/** Tests swizzling a superclass's class method. */
- (void)testSwizzlingSuperclassClassMethod {
  NSString *expectedDescription = @"Swizzled class description";
  NSString * (^newImplementation)() = ^NSString *() {
    return expectedDescription;
  };

  [FIRSwizzler swizzleClass:[TestObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqualObjects([TestObject description], expectedDescription);
  [FIRSwizzler unswizzleClass:[TestObject class]
                     selector:@selector(description)
              isClassSelector:YES];
}

/** Tests swizzling an instance method that calls into the superclass implementation. */
- (void)testSwizzlingInstanceMethodThatCallsSuper {
  NSString *expectedDescription = [[[TestObject alloc] init] description];
  NSString * (^newImplementation)() = ^NSString *() {
    return expectedDescription;
  };

  [FIRSwizzler swizzleClass:[TestObject class]
                   selector:@selector(description)
            isClassSelector:NO
                  withBlock:newImplementation];
  XCTAssertEqual([[[TestObject alloc] init] description], expectedDescription);
  [FIRSwizzler unswizzleClass:[TestObject class]
                     selector:@selector(description)
              isClassSelector:NO];
  XCTAssertNotEqual([[[TestObject alloc] init] description], expectedDescription);
}

/** Tests swizzling a method and getting the original IMP of that method. */
- (void)testSwizzleAndGet {
  Class testClass = [NSURL class];
  SEL testSelector = @selector(description);
  IMP baseImp = class_getMethodImplementation(testClass, testSelector);
  [FIRSwizzler swizzleClass:testClass
                   selector:testSelector
            isClassSelector:NO
                  withBlock:^{
                    return @"Swizzled Description";
                  }];
  IMP origImp = [FIRSwizzler originalImplementationForClass:testClass
                                                   selector:testSelector
                                            isClassSelector:NO];
  XCTAssertEqual(origImp, baseImp, @"Original IMP and base IMP are not equal.");
  [FIRSwizzler unswizzleClass:testClass selector:testSelector isClassSelector:NO];
}

/** Tests swizzling more than a single method at a time. */
- (void)testSwizzleMultiple {
  Class testClass = [NSURL class];
  SEL testSelector = @selector(description);
  [FIRSwizzler swizzleClass:testClass
                   selector:testSelector
            isClassSelector:NO
                  withBlock:^{
                    return @"Swizzled Description";
                  }];
  IMP origImp = [FIRSwizzler originalImplementationForClass:testClass
                                                   selector:testSelector
                                            isClassSelector:NO];
  Class testClass2 = [NSURLRequest class];
  SEL testSelector2 = @selector(debugDescription);
  [FIRSwizzler swizzleClass:testClass2
                   selector:testSelector2
            isClassSelector:NO
                  withBlock:^{
                    return @"Swizzled Debug Description";
                  }];
  IMP origImp2 = [FIRSwizzler originalImplementationForClass:testClass2
                                                    selector:testSelector2
                                             isClassSelector:NO];
  XCTAssertNotEqual(origImp2, NULL, @"Original IMP is NULL after swizzle.");
  XCTAssertNotEqual(origImp, origImp2, @"Implementations are the same when they should't be.");

  [FIRSwizzler unswizzleClass:testClass selector:testSelector isClassSelector:NO];
  [FIRSwizzler unswizzleClass:testClass2 selector:testSelector2 isClassSelector:NO];
}

/** Tests swizzling a class method that calls into the superclass implementation. */
- (void)testSwizzlingClassMethodThatCallsSuper {
  NSString *expectedDescription = @"Swizzled class description";
  NSString * (^newImplementation)() = ^NSString *() {
    return expectedDescription;
  };

  [FIRSwizzler swizzleClass:[TestObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqualObjects([TestObject description], expectedDescription);
  [FIRSwizzler unswizzleClass:[TestObject class]
                     selector:@selector(description)
              isClassSelector:YES];
}

/** Tests swizzling an inherited instance method doesn't change the implementation of the
 *  superclass's implementation of that same method.
 */
- (void)testSwizzlingAnInheritedInstanceMethodDoesntAffectTheIMPOfItsSuperclass {
  NSObject *generalObject = [[NSObject alloc] init];
  BOOL expectedGeneralObjectValue = [generalObject isProxy];
  BOOL (^newImplementation)() = ^BOOL() {
    return !expectedGeneralObjectValue;
  };

  [FIRSwizzler swizzleClass:[TestObject class]
                   selector:@selector(isProxy)
            isClassSelector:NO
                  withBlock:newImplementation];
  XCTAssertEqual([generalObject isProxy], expectedGeneralObjectValue);
  XCTAssertNotEqual([[[TestObject alloc] init] isProxy], expectedGeneralObjectValue);
  [FIRSwizzler unswizzleClass:[TestObject class] selector:@selector(isProxy) isClassSelector:NO];
  XCTAssertEqual([[[TestObject alloc] init] isProxy], expectedGeneralObjectValue);
}

/** Tests swizzling an inherited instance method from a superclass a couple of links up in the
 *  chain of superclasses doesn't affect the implementation of the superclass's method.
 */
- (void)testSwizzlingADeeperInheritedInstanceMethodDoesntAffectTheIMPOfItsSuperclass {
  TestObject *testObject = [[TestObject alloc] init];
  BOOL expectedTestObjectValue = [testObject isProxy];
  BOOL (^newImplementation)() = ^BOOL() {
    return !expectedTestObjectValue;
  };

  [FIRSwizzler swizzleClass:[TestObjectSubclass class]
                   selector:@selector(isProxy)
            isClassSelector:NO
                  withBlock:newImplementation];
  XCTAssertEqual([testObject isProxy], expectedTestObjectValue);
  XCTAssertNotEqual([[[TestObjectSubclass alloc] init] isProxy], expectedTestObjectValue);
  [FIRSwizzler unswizzleClass:[TestObjectSubclass class]
                     selector:@selector(isProxy)
              isClassSelector:NO];
  XCTAssertEqual([[[TestObjectSubclass alloc] init] isProxy], expectedTestObjectValue);
}

/** Tests swizzling an inherited class method doesn't change the implementation of the
 *  superclass's implementation of that same method.
 */
- (void)testSwizzlingAnInheritedClassMethodDoesntAffectTheIMPOfItsSuperclass {
  // Fun fact, this won't work on +new. Swizzling +new causes a retain to not be placed correctly.
  NSString *expectedDescription = [TestObject description];
  NSString * (^newImplementation)() = ^NSString *() {
    return expectedDescription;
  };

  [FIRSwizzler swizzleClass:[TestObject class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqual([TestObject description], expectedDescription);
  XCTAssertNotEqual([NSObject description], expectedDescription);
  [FIRSwizzler unswizzleClass:[TestObject class]
                     selector:@selector(description)
              isClassSelector:YES];
  XCTAssertNotEqual([TestObject description], expectedDescription);
  XCTAssertNotEqual([NSObject description], expectedDescription);
}

/** Tests swizzling an inherited class method from a superclass a couple of links up in the
 *  chain of superclasses doesn't affect the implementation of the superclass's method.
 */
- (void)testSwizzlingADeeperInheritedClassMethodDoesntAffectTheIMPOfItsSuperclass {
  NSString *expectedDescription = [TestObjectSubclass description];
  NSString * (^newImplementation)() = ^NSString *() {
    return expectedDescription;
  };

  [FIRSwizzler swizzleClass:[TestObjectSubclass class]
                   selector:@selector(description)
            isClassSelector:YES
                  withBlock:newImplementation];
  XCTAssertEqual([TestObjectSubclass description], expectedDescription);
  XCTAssertNotEqual([TestObject description], expectedDescription);
  XCTAssertNotEqual([NSObject description], expectedDescription);
  [FIRSwizzler unswizzleClass:[TestObjectSubclass class]
                     selector:@selector(description)
              isClassSelector:YES];
  XCTAssertNotEqual([TestObjectSubclass description], expectedDescription);
  XCTAssertNotEqual([TestObject description], expectedDescription);
  XCTAssertNotEqual([NSObject description], expectedDescription);
}

@end
