// Copyright 2019 Google
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

#import "Crashlytics/Shared/FIRCLSNetworking/FIRCLSURLBuilder.h"

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

@interface FIRCLSURLBuilder (Testing)
- (NSString *)escapeString:(NSString *)string;
@end

@interface FABURLBuilderTests : XCTestCase

@end

@implementation FABURLBuilderTests

- (void)setUp {
  [super setUp];
}

- (void)tearDown {
  [super tearDown];
}
#if !TARGET_OS_WATCH
- (void)testTheRightUrlEncodingIsUsed {
  NSString *actual =
      @"https://settings.crashlytics.com/spi/v2/platforms/ios/apps/"
      @"com.dogs.testingappforfunandprofit/"
      @"settings?icon_hash=277530e7595e8ff02a163905942a24dd14747fcb&display_version=1.0 "
      @"#1234&source=1&instance=d8b2e102647d9cbdc67a650d23bcefd445874a2c&build_version=1";

  NSString *expected =
      @"https://settings.crashlytics.com/spi/v2/platforms/ios/apps/"
      @"com.dogs.testingappforfunandprofit/"
      @"settings?icon_hash=277530e7595e8ff02a163905942a24dd14747fcb&display_version=1.0%20%231234&"
      @"source=1&instance=d8b2e102647d9cbdc67a650d23bcefd445874a2c&build_version=1";

  FIRCLSURLBuilder *urlBuilder = [FIRCLSURLBuilder new];
  NSString *encoded = [urlBuilder escapeString:actual];
  XCTAssertEqualObjects(encoded, expected);
}
#endif
@end
