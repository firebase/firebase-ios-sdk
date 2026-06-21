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

#import "FirebasePerformance/Sources/Instrumentation/FPRObjectInstrumentor.h"

@interface FPRObjectInstrumentorTest : XCTestCase

@end

@implementation FPRObjectInstrumentorTest

/** Exists only as a donor method. */
- (void)donorMethod {
}

/** Tests initialization works. */
- (void)testInitWithObject {
  NSObject *object = [[NSObject alloc] init];
  FPRObjectInstrumentor *instrumentor = [[FPRObjectInstrumentor alloc] initWithObject:object];
  XCTAssertNotNil(instrumentor);
  XCTAssertNotNil(instrumentor.instrumentedObject);
  XCTAssertFalse(instrumentor.hasModifications);
}

/** Tests copying a selector that's not present on the target object. */
- (void)testCopySelectorFromClassThatModifies {
  NSObject *object = [[NSObject alloc] init];
  FPRObjectInstrumentor *instrumentor = [[FPRObjectInstrumentor alloc] initWithObject:object];
  __weak FPRObjectInstrumentor *weakInstrumentor = instrumentor;
  [instrumentor copySelector:@selector(donorMethod) fromClass:[self class] isClassSelector:NO];
  XCTAssertTrue([instrumentor hasModifications]);
  [instrumentor swizzle];
  XCTAssertNoThrow([object performSelector:@selector(donorMethod) withObject:nil]);
  XCTAssertNotEqual([object class], [NSObject class]);
  XCTAssertTrue([[object class] isSubclassOfClass:[NSObject class]]);
  instrumentor = nil;
  XCTAssertNil(weakInstrumentor);
  XCTAssertNotNil([(FPRSwizzledObject *)object gul_objectSwizzler]);
  XCTAssertNoThrow([(FPRSwizzledObject *)object gul_class]);
  XCTAssertEqual([object class], [(FPRSwizzledObject *)object gul_class]);
}

/** Tests copying a selector that already exists on the object doesn't work. */
- (void)testCopySelectorFromClassThatDoesNotModify {
  NSObject *object = [[NSObject alloc] init];
  FPRObjectInstrumentor *instrumentor = [[FPRObjectInstrumentor alloc] initWithObject:object];
  [instrumentor copySelector:@selector(description) fromClass:[self class] isClassSelector:NO];
  XCTAssertFalse([instrumentor hasModifications]);
  [instrumentor swizzle];
  XCTAssertEqual([object class], [NSObject class]);
}

@end
