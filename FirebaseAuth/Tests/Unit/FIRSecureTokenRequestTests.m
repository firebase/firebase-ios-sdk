/*
 * Copyright 2020 Google LLC
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

#import "FirebaseAuth/Sources/Backend/RPC/FIRSecureTokenRequest.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthRequestConfiguration.h"

/** @var kAPIKey
    @brief A testing API Key.
 */
static NSString *const kAPIKey = @"APIKey";

/** @var kCode
    @brief A testing authorization code.
 */
static NSString *const kCode = @"code";

/** @var kEmulatorHostAndPort
    @brief A testing emulator host and port.
 */
static NSString *const kEmulatorHostAndPort = @"emulatorhost:12345";

/** @class FIRSecureTokenRequestTests
    @brief Tests for @c FIRSecureTokenRequest
 */
@interface FIRSecureTokenRequestTests : XCTestCase
@end

@implementation FIRSecureTokenRequestTests

/** @fn testRequestURL
    @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
   request inputs.
 */
- (void)testRequestURL {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kAPIKey];
  FIRSecureTokenRequest *request =
      [FIRSecureTokenRequest authCodeRequestWithCode:kCode
                                requestConfiguration:requestConfiguration];

  NSString *expectedURL =
      [NSString stringWithFormat:@"https://securetoken.googleapis.com/v1/token?key=%@", kAPIKey];

  XCTAssertEqualObjects(expectedURL, request.requestURL.absoluteString);
}

/** @fn testRequestURLUseEmulator
    @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
   request inputs when using the emulator.
 */
- (void)testRequestURLUseEmulator {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kAPIKey];
  requestConfiguration.emulatorHostAndPort = kEmulatorHostAndPort;
  FIRSecureTokenRequest *request =
      [FIRSecureTokenRequest authCodeRequestWithCode:kCode
                                requestConfiguration:requestConfiguration];

  NSString *expectedURL =
      [NSString stringWithFormat:@"http://%@/securetoken.googleapis.com/v1/token?key=%@",
                                 kEmulatorHostAndPort, kAPIKey];

  XCTAssertEqualObjects(expectedURL, request.requestURL.absoluteString);
}

@end
