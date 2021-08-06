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
#import "FirebasePerformance/Sources/Instrumentation/FPRInstrument.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRInstrument_Private.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRSelectorInstrumentor.h"

#import <OCMock/OCMock.h>

@interface FPRInstrumentTest : XCTestCase

@end

@implementation FPRInstrumentTest

- (void)testInit {
  FPRInstrument *instrument = [[FPRInstrument alloc] init];
  XCTAssertNotNil(instrument);
  XCTAssertNotNil(instrument.classInstrumentors);
  XCTAssertNotNil(instrument.instrumentedClasses);
}

- (void)testRegisterInstrumentorsThrows {
  FPRInstrument *instrument = [[FPRInstrument alloc] init];
  XCTAssertThrows([instrument registerInstrumentors]);
}

- (void)testRegisterClassInstrumentor {
  FPRInstrument *instrument = [[FPRInstrument alloc] init];
  FPRClassInstrumentor *instrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  BOOL success = [instrument registerClassInstrumentor:instrumentor];
  XCTAssertTrue(success);
  XCTAssertGreaterThan(instrument.classInstrumentors.count, 0);
  XCTAssertGreaterThan(instrument.instrumentedClasses.count, 0);
  [instrument deregisterInstrumentors];
}

- (void)testRegisterAlreadyRegisteredClassInstrumentor {
  FPRInstrument *instrument = [[FPRInstrument alloc] init];
  FPRClassInstrumentor *instrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  FPRClassInstrumentor *secondInstrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  BOOL succeedsTheFirstTime = [instrument registerClassInstrumentor:instrumentor];
  BOOL succeedsTheSecondTime = [instrument registerClassInstrumentor:secondInstrumentor];
  XCTAssertTrue(succeedsTheFirstTime);
  XCTAssertFalse(succeedsTheSecondTime);
  [instrument deregisterInstrumentors];
}

#pragma mark - Unswizzle based tests

#if !SWIFT_PACKAGE

- (void)testDeregisterInstrumentors {
  FPRInstrument *instrument = [[FPRInstrument alloc] init];
  FPRClassInstrumentor *classInstrumentor =
      [[FPRClassInstrumentor alloc] initWithClass:[NSObject class]];
  FPRSelectorInstrumentor *selectorInstrumentor =
      [classInstrumentor instrumentorForInstanceSelector:@selector(description)];
  [selectorInstrumentor setReplacingBlock:^NSString *(id _self) {
    return @"testing";
  }];
  [instrument registerClassInstrumentor:classInstrumentor];
  [classInstrumentor swizzle];
  XCTAssertGreaterThan(instrument.classInstrumentors.count, 0);
  XCTAssertGreaterThan(instrument.instrumentedClasses.count, 0);
  [instrument deregisterInstrumentors];
  XCTAssertEqual(instrument.classInstrumentors.count, 0);
  XCTAssertEqual(instrument.instrumentedClasses.count, 0);
  [classInstrumentor unswizzle];
}

#endif  // SWIFT_PACKAGE

@end
