// Copyright 2020 Google LLC
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

#import "FirebasePerformance/Sources/Instrumentation/FPRClassInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRClassInstrumentor_Private.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRSelectorInstrumentor.h"

@interface FPRClassInstrumentorTest : XCTestCase

@end

@implementation FPRClassInstrumentorTest

/** Tests calling the designated initializer. */
- (void)testDesignatedInitializer {
  FPRClassInstrumentor *classInstrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  XCTAssertEqual(classInstrumentor.instrumentedClass, [NSObject class]);
}

/** Tests building and adding a selector instrumentor for an instance method. */
- (void)testBuildAndAddSelectorInstrumentorForInstanceSelector {
  FPRClassInstrumentor *classInstrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  [classInstrumentor instrumentorForInstanceSelector:@selector(description)];
  XCTAssertEqual([classInstrumentor selectorInstrumentors].count, 1);
}

/** Tests building and adding a selector instrumentor for a class method. */
- (void)testBuildAndAddSelectorInstrumentorForClassSelector {
  FPRClassInstrumentor *classInstrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  [classInstrumentor instrumentorForClassSelector:@selector(description)];
  XCTAssertEqual([classInstrumentor selectorInstrumentors].count, 1);
}

/** Tests that you cannot attempt to instrument the same selector twice. */
- (void)testCannotInstrumentSameSelectorTwice {
  FPRClassInstrumentor *classInstrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  [classInstrumentor instrumentorForClassSelector:@selector(description)];
  XCTAssertThrows([classInstrumentor instrumentorForClassSelector:@selector(description)]);
}

#pragma mark - Unswizzle based tests

#if !SWIFT_PACKAGE

/** Tests swizzling an instance selector. */
- (void)testSwizzleInstanceSelector {
  FPRClassInstrumentor *classInstrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  FPRSelectorInstrumentor *selectorInstrumentor =
      [classInstrumentor instrumentorForInstanceSelector:@selector(description)];
  NSString *expectedString = @"Swizzled!";
  [selectorInstrumentor setReplacingBlock:^NSString *(id _self) {
    return expectedString;
  }];
  [classInstrumentor swizzle];
  XCTAssertEqualObjects([[[NSObject alloc] init] description], expectedString);
  [classInstrumentor unswizzle];
}

/** Tests unswizzling an instance selector. */
- (void)testUnswizzleInstanceSelector {
  FPRClassInstrumentor *classInstrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  FPRSelectorInstrumentor *selectorInstrumentor =
      [classInstrumentor instrumentorForInstanceSelector:@selector(description)];
  [selectorInstrumentor setReplacingBlock:^NSString *(id _self) {
    return @"Swizzled!";
  }];
  [classInstrumentor swizzle];
  [classInstrumentor unswizzle];
  XCTAssertEqual(classInstrumentor.selectorInstrumentors.count, 0);
}

/** Tests swizzling a class selector. */
- (void)testSwizzleClassSelector {
  FPRClassInstrumentor *classInstrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  FPRSelectorInstrumentor *selectorInstrumentor =
      [classInstrumentor instrumentorForClassSelector:@selector(description)];
  [selectorInstrumentor setReplacingBlock:^NSString *(id _self) {
    return @"Swizzled!";
  }];
  [classInstrumentor swizzle];
  XCTAssertEqualObjects([NSObject description], @"Swizzled!");
  [classInstrumentor unswizzle];
}

/** Tests unswizzling a class selector. */
- (void)testUnswizzleClassSelector {
  FPRClassInstrumentor *classInstrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  FPRSelectorInstrumentor *selectorInstrumentor =
      [classInstrumentor instrumentorForClassSelector:@selector(description)];
  [selectorInstrumentor setReplacingBlock:^NSString *(id _self) {
    return @"Swizzled!";
  }];
  [classInstrumentor swizzle];
  [classInstrumentor unswizzle];
  XCTAssertEqual(classInstrumentor.selectorInstrumentors.count, 0);
}

/** Tests swizzling an instance method with a call-through that doesn't return anything. */
- (void)testVoidReturnInstanceSelector {
  __block BOOL wasInvoked = NO;
  FPRClassInstrumentor *classInstrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  SEL instrumentedSelector = @selector(doesNotRecognizeSelector:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [classInstrumentor instrumentorForInstanceSelector:instrumentedSelector];
  IMP originalIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id object, SEL selector) {
    wasInvoked = YES;
    typedef void (*OriginalImp)(id, SEL, SEL);
    ((OriginalImp)originalIMP)(object, instrumentedSelector, selector);
  }];
  [classInstrumentor swizzle];

  XCTAssertThrows([[[NSObject alloc] init] doesNotRecognizeSelector:@selector(setValue:forKey:)]);
  XCTAssertTrue(wasInvoked);
  [classInstrumentor unswizzle];
}

/** Tests swizzling a class method with a call-through that doesn't return anything. */
- (void)testVoidReturnClassSelector {
  __block BOOL wasInvoked = NO;
  FPRClassInstrumentor *classInstrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  SEL selector = @selector(setVersion:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [classInstrumentor instrumentorForClassSelector:selector];
  IMP originalIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id object, NSInteger version) {
    wasInvoked = YES;
    typedef void (*OriginalImp)(Class, SEL, NSInteger);
    ((OriginalImp)originalIMP)(object, selector, version);
  }];
  [classInstrumentor swizzle];

  [NSObject setVersion:1];
  XCTAssertTrue(wasInvoked);
  [classInstrumentor unswizzle];
}

#endif  // SWIFT_PACKAGE

@end
