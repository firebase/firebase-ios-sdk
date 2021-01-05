/*
 * Copyright 2017 Google
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

#import "FirebaseInAppMessaging/Sources/Util/UIColor+FIRIAMHexString.h"

@interface UIColor_FIRIAMHexStringTests : XCTestCase

@end

@implementation UIColor_FIRIAMHexStringTests

- (void)setUp {
  [super setUp];
  // Put setup code here. This method is called before the invocation of each test method in the
  // class.
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
  [super tearDown];
}

- (void)testNilHexString {
  UIColor *color = [UIColor firiam_colorWithHexString:nil];
  XCTAssertNil(color);
}

- (void)testEmptyHexString {
  UIColor *color = [UIColor firiam_colorWithHexString:@""];
  XCTAssertNil(color);
}

- (void)testInvalidHexString {
  UIColor *color = [UIColor firiam_colorWithHexString:@"#sssfsss"];
  XCTAssertNil(color);
}

- (void)testValidHexString {
  UIColor *color = [UIColor firiam_colorWithHexString:@"#00FFEE"];
  XCTAssertNotNil(color);
}

@end
