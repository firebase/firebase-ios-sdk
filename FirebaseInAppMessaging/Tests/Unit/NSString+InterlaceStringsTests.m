/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <XCTest/XCTest.h>

#import "FirebaseInAppMessaging/Sources/Private/Util/NSString+FIRInterlaceStrings.h"

@interface NSString_InterlaceStringsTests : XCTestCase

@end

@implementation NSString_InterlaceStringsTests

- (void)testEmptyStrings {
  NSString *stringOne = @"";
  NSString *stringTwo = @"";
  XCTAssertEqualObjects(@"", [NSString fir_interlaceString:stringOne withString:stringTwo]);
}

- (void)testSimpleExample {
  NSString *stringOne = @"fe";
  NSString *stringTwo = @"rd";
  XCTAssertEqualObjects(@"fred", [NSString fir_interlaceString:stringOne withString:stringTwo]);
}

- (void)testLongerExample {
  NSString *stringOne = @"fefittn";
  NSString *stringTwo = @"rdlnsoe";
  XCTAssertEqualObjects(@"fredflintstone", [NSString fir_interlaceString:stringOne
                                                              withString:stringTwo]);
}

- (void)testLongerFirstString {
  NSString *stringOne = @"fe'lastnameisflintstone";
  NSString *stringTwo = @"rds";
  XCTAssertEqualObjects(@"fred'slastnameisflintstone", [NSString fir_interlaceString:stringOne
                                                                          withString:stringTwo]);
}

- (void)testLongerSecondString {
  NSString *stringOne = @"fe'";
  NSString *stringTwo = @"rdslastnameisflintstone";
  XCTAssertEqualObjects(@"fred'slastnameisflintstone", [NSString fir_interlaceString:stringOne
                                                                          withString:stringTwo]);
}

@end
