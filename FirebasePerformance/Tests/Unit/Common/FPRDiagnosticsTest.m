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

#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/Common/FPRDiagnostics_Private.h"

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"

#import "FirebasePerformance/Tests/Unit/Fakes/FPRFakeConfigurations.h"

static BOOL classEmitDiagnosticsCalled = NO;

@interface FPRDiagnosticsTestClass : NSObject <FPRDiagnosticsProtocol>

@property(nonatomic, assign) BOOL instanceEmitDiagnosticsCalled;

@end

@implementation FPRDiagnosticsTestClass

+ (void)emitDiagnostics {
  classEmitDiagnosticsCalled = YES;
}

- (void)emitDiagnostics {
  self.instanceEmitDiagnosticsCalled = YES;
}

- (NSString *)description {
  FPRAssert(NO, @"You should never describe this class! Noooooooo!");
  return [super description];
}

@end

@interface FPRDiagnosticsTest : XCTestCase

@end

@implementation FPRDiagnosticsTest

/** Asserts using NSAssert. */
- (void)regularAssert {
  // Yes, technically this will fail once in a while--done this way to avoid compiler optimizations.
  NSAssert(arc4random_uniform(UINT32_MAX) > 0, @"A regular assert failure!");
}

/** Asserts using FPRAssert. */
- (void)fancyAssert {
  // Yes, technically this will fail once in a while--done this way to avoid compiler optimizations.
  FPRAssert(arc4random_uniform(UINT32_MAX) > 0, @"A fancy assert failure!");
}

/** Tests that FPRAssert's execution time is less than 0.001s. */
- (void)testFPRAssertSpeed {
  NSDate *start = [NSDate date];
  XCTAssertNoThrow([self regularAssert]);
  NSDate *end = [NSDate date];

  start = [NSDate date];
  XCTAssertNoThrow([self fancyAssert]);
  end = [NSDate date];
  NSTimeInterval fancyAssertTime = [end timeIntervalSinceDate:start];
  XCTAssertLessThan(fancyAssertTime, 0.001);
}

/** Tests that FPRAssert actually asserts (when NS_BLOCK_ASSERTIONS=0|undefined). */
- (void)testFPRAssert {
  XCTAssertThrows(FPRAssert(NO, @"This is a failed assert!"));
}

/** Tests emit diagnostics methods. */
- (void)testEmitDiagnostics {
  FPRDiagnosticsTestClass *testObject = [[FPRDiagnosticsTestClass alloc] init];

  FPRFakeConfigurations *fakeConfigs =
      [[FPRFakeConfigurations alloc] initWithSources:FPRConfigurationSourceNone];
  FPRDiagnostics.configuration = fakeConfigs;
  fakeConfigs.diagnosticsEnabled = YES;

#if NS_BLOCK_ASSERTS
  XCTAssertNoThrow([testObject description]);
#else
  XCTAssertThrows([testObject description]);
#endif
  XCTAssertTrue(classEmitDiagnosticsCalled);
  XCTAssertTrue(testObject.instanceEmitDiagnosticsCalled);

  FPRDiagnostics.configuration = [FPRConfigurations sharedInstance];
}

@end
