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

#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/FIRPerformance+Internal.h"
#import "FirebasePerformance/Sources/FIRPerformance_Private.h"
#import "FirebasePerformance/Sources/FPRClient+Private.h"
#import "FirebasePerformance/Sources/FPRClient.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"
#import "FirebasePerformance/Tests/Unit/Fakes/FPRFakeClient.h"

#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"

#import "FirebaseCore/Internal/FIRAppInternal.h"

@interface FIRPerformanceTest : FPRTestCase

@property(nonatomic) FIRPerformance *performance;

@end

@implementation FIRPerformanceTest

- (void)setUp {
  [super setUp];
  self.performance = [[FIRPerformance alloc] init];
  self.performance.fprClient = [[FPRFakeClient alloc] init];
  [self.performance setDataCollectionEnabled:YES];
  [self.performance setInstrumentationEnabled:NO];
}

- (void)tearDown {
  [super tearDown];
  [self.performance setDataCollectionEnabled:NO];
  NSArray<NSString *> *allKeys = self.performance.attributes.allKeys;
  [allKeys enumerateObjectsUsingBlock:^(NSString *attribute, NSUInteger idx, BOOL *stop) {
    [self.performance removeAttribute:attribute];
  }];
}

/** Validates that the singleton instance creation works. */
- (void)testSingleton {
  XCTAssertEqual([FIRPerformance sharedInstance], [FIRPerformance sharedInstance]);
}

/** Validates that toggling of enabling/disabling performance collection works. */
- (void)testToggleDisablingPerformanceCollection {
  self.appFake.fakeIsDataCollectionDefaultEnabled = YES;

  [self.performance setDataCollectionEnabled:YES];
  XCTAssertTrue(self.performance.dataCollectionEnabled);
  [self.performance setDataCollectionEnabled:NO];
  XCTAssertFalse(self.performance.dataCollectionEnabled);
  [self.performance setDataCollectionEnabled:YES];
  XCTAssertTrue(self.performance.dataCollectionEnabled);
}

/** Validates that toggling of enabling/disabling performance instrumentation works. */
- (void)testToggleDisablingPerformanceInstrumentation {
  [self.performance setInstrumentationEnabled:YES];
  XCTAssertTrue(self.performance.instrumentationEnabled);

  [self.performance setInstrumentationEnabled:NO];
  XCTAssertFalse([FPRConfigurations sharedInstance].isInstrumentationEnabled);

  XCTAssertTrue(self.performance.isInstrumentationEnabled);

  [self.performance setInstrumentationEnabled:YES];
  XCTAssertTrue([FPRConfigurations sharedInstance].isInstrumentationEnabled);

  XCTAssertTrue(self.performance.instrumentationEnabled);
}

/** Validates that trace creation works on shared instance. */
- (void)testTraceCreationOnSharedInstance {
  XCTAssertNotNil([self.performance traceWithName:@"random"]);
  XCTAssertThrows([self.performance traceWithName:@""]);
  [self.performance setInstrumentationEnabled:YES];
}

/** Validates if trace creation throws exception when SDK is not configured. */
- (void)testTraceCreationThrowsExceptionWhenNotConfigured {
  self.performance.fprClient.configured = NO;
  XCTAssertThrows([self.performance traceWithName:@"random"]);
  self.performance.fprClient.configured = YES;
}

#pragma mark - Custom attributes related tests

/** Validates if setting a valid attribute works. */
- (void)testSettingValidAttribute {
  [self.performance setValue:@"bar" forAttribute:@"foo"];
  XCTAssertEqual([self.performance valueForAttribute:@"foo"], @"bar");
}

/** Validates if attributes property access works. */
- (void)testReadingAttributesFromProperty {
  XCTAssertNotNil(self.performance.attributes);
  XCTAssertEqual(self.performance.attributes.count, 0);
  [self.performance setValue:@"bar" forAttribute:@"foo"];
  NSDictionary<NSString *, NSString *> *attributes = self.performance.attributes;
  XCTAssertEqual(attributes.allKeys.count, 1);
}

/** Validates if attributes property is immutable. */
- (void)testImmutablityOfAttributesProperty {
  [self.performance setValue:@"bar" forAttribute:@"foo"];
  NSMutableDictionary<NSString *, NSString *> *attributes =
      (NSMutableDictionary<NSString *, NSString *> *)self.performance.attributes;
  XCTAssertThrows([attributes setValue:@"bar1" forKey:@"foo"]);
}

/** Validates if updating attribute value works. */
- (void)testUpdatingAttributeValue {
  [self.performance setValue:@"bar" forAttribute:@"foo"];
  [self.performance setValue:@"baz" forAttribute:@"foo"];
  XCTAssertEqual(@"baz", [self.performance valueForAttribute:@"foo"]);
  [self.performance setValue:@"qux" forAttribute:@"foo"];
  XCTAssertEqual(@"qux", [self.performance valueForAttribute:@"foo"]);
}

/** Validates if removing attributes work. */
- (void)testRemovingAttribute {
  [self.performance setValue:@"bar" forAttribute:@"foo"];
  [self.performance removeAttribute:@"foo"];
  XCTAssertNil([self.performance valueForAttribute:@"foo"]);
  [self.performance removeAttribute:@"foo"];
  XCTAssertNil([self.performance valueForAttribute:@"foo"]);
}

/** Validates if removing non-existing attributes works. */
- (void)testRemovingNonExistingAttribute {
  [self.performance removeAttribute:@"foo"];
  XCTAssertNil([self.performance valueForAttribute:@"foo"]);
  [self.performance removeAttribute:@"foo"];
  XCTAssertNil([self.performance valueForAttribute:@"foo"]);
}

/** Validates if using reserved prefix in attribute prefix will drop the attribute. */
- (void)testAttributeNamePrefixSrtipped {
  NSArray<NSString *> *reservedPrefix = @[ @"firebase_", @"google_", @"ga_" ];

  [reservedPrefix enumerateObjectsUsingBlock:^(NSString *prefix, NSUInteger idx, BOOL *stop) {
    NSString *attributeName = [NSString stringWithFormat:@"%@name", prefix];
    NSString *attributeValue = @"value";

    [self.performance setValue:attributeValue forAttribute:attributeName];
    XCTAssertNil([self.performance valueForAttribute:attributeName]);
  }];
}

/** Validates if long attribute names gets dropped. */
- (void)testMaxLengthForAttributeName {
  NSString *testName = [@"abc" stringByPaddingToLength:kFPRMaxAttributeNameLength + 1
                                            withString:@"-"
                                       startingAtIndex:0];
  [self.performance setValue:@"bar" forAttribute:testName];
  XCTAssertNil([self.performance valueForAttribute:testName]);
}

/** Validates if attribute names with illegal characters gets dropped. */
- (void)testIllegalCharactersInAttributeName {
  [self.performance setValue:@"bar" forAttribute:@"foo_"];
  XCTAssertEqual([self.performance valueForAttribute:@"foo_"], @"bar");
  [self.performance setValue:@"bar" forAttribute:@"foo_$"];
  XCTAssertNil([self.performance valueForAttribute:@"foo_$"]);
  [self.performance setValue:@"bar" forAttribute:@"FOO_$"];
  XCTAssertNil([self.performance valueForAttribute:@"FOO_$"]);
  [self.performance setValue:@"bar" forAttribute:@"FOO_"];
  XCTAssertEqual([self.performance valueForAttribute:@"FOO_"], @"bar");
}

/** Validates if long attribute values gets truncated. */
- (void)testMaxLengthForAttributeValue {
  NSString *testValue = [@"abc" stringByPaddingToLength:kFPRMaxAttributeValueLength + 1
                                             withString:@"-"
                                        startingAtIndex:0];
  [self.performance setValue:testValue forAttribute:@"foo"];
  XCTAssertNil([self.performance valueForAttribute:@"foo"]);
}

/** Validates if empty name or value of the attributes are getting dropped. */
- (void)testAttributesWithEmptyValues {
  [self.performance setValue:@"" forAttribute:@"foo"];
  XCTAssertNil([self.performance valueForAttribute:@"foo"]);
  [self.performance setValue:@"bar" forAttribute:@""];
  XCTAssertNil([self.performance valueForAttribute:@""]);
}

/** Validates if the limit the maximum number of attributes work. */
- (void)testMaximumNumberOfAttributes {
  for (int i = 0; i < kFPRMaxGlobalCustomAttributesCount; i++) {
    NSString *attributeName = [NSString stringWithFormat:@"dim%d", i];
    [self.performance setValue:@"bar" forAttribute:attributeName];
    XCTAssertEqual([self.performance valueForAttribute:attributeName], @"bar");
  }
  [self.performance setValue:@"bar" forAttribute:@"foo"];
  XCTAssertNil([self.performance valueForAttribute:@"foo"]);
}

/** Validates if removing old attributes and adding new attributes work. */
- (void)testRemovingAndAddingAttributes {
  for (int i = 0; i < kFPRMaxGlobalCustomAttributesCount; i++) {
    NSString *attributeName = [NSString stringWithFormat:@"dim%d", i];
    [self.performance setValue:@"bar" forAttribute:attributeName];
    XCTAssertEqual([self.performance valueForAttribute:attributeName], @"bar");
  }
  [self.performance removeAttribute:@"dim1"];
  [self.performance setValue:@"bar" forAttribute:@"foo"];
  XCTAssertEqual([self.performance valueForAttribute:@"foo"], @"bar");
}

@end
