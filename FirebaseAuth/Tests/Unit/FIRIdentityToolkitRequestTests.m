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

#import "FirebaseAuth/Sources/Backend/FIRIdentityToolkitRequest.h"

/** @var kEndpoint
    @brief The endpoint for the requests.
 */
static NSString *const kEndpoint = @"endpoint";

/** @var kAPIKey
    @brief A testing API Key.
 */
static NSString *const kAPIKey = @"APIKey";

/** @var kEmulatorHostAndPort
    @brief A testing emulator host and port.
 */
static NSString *const kEmulatorHostAndPort = @"emulatorhost:12345";

/** @class FIRIdentityToolkitRequestTests
    @brief Tests for @c FIRIdentityToolkitRequest
 */
@interface FIRIdentityToolkitRequestTests : XCTestCase
@end

@implementation FIRIdentityToolkitRequestTests

/** @fn testInitWithEndpointExpectedRequestURL
    @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
   request inputs.
 */
- (void)testInitWithEndpointExpectedRequestURL {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kAPIKey];
  FIRIdentityToolkitRequest *request =
      [[FIRIdentityToolkitRequest alloc] initWithEndpoint:kEndpoint
                                     requestConfiguration:requestConfiguration];
  NSString *expectedURL = [NSString
      stringWithFormat:@"https://www.googleapis.com/identitytoolkit/v3/relyingparty/%@?key=%@",
                       kEndpoint, kAPIKey];

  XCTAssertEqualObjects(expectedURL, request.requestURL.absoluteString);
}

/** @fn testInitWithEndpointUseStagingExpectedRequestURL
    @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
   request inputs when the staging endpoint is specified.
 */
- (void)testInitWithEndpointUseStagingExpectedRequestURL {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kAPIKey];
  FIRIdentityToolkitRequest *request =
      [[FIRIdentityToolkitRequest alloc] initWithEndpoint:kEndpoint
                                     requestConfiguration:requestConfiguration
                                      useIdentityPlatform:NO
                                               useStaging:YES];
  NSString *expectedURL = [NSString
      stringWithFormat:
          @"https://staging-www.sandbox.googleapis.com/identitytoolkit/v3/relyingparty/%@?key=%@",
          kEndpoint, kAPIKey];

  XCTAssertEqualObjects(expectedURL, request.requestURL.absoluteString);
}

/** @fn testInitWithEndpointUseIdentityPlatformExpectedRequestURL
    @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
   request inputs when the Identity Platform endpoint is specified.
 */
- (void)testInitWithEndpointUseIdentityPlatformExpectedRequestURL {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kAPIKey];
  FIRIdentityToolkitRequest *request =
      [[FIRIdentityToolkitRequest alloc] initWithEndpoint:kEndpoint
                                     requestConfiguration:requestConfiguration
                                      useIdentityPlatform:YES
                                               useStaging:NO];
  NSString *expectedURL = [NSString
      stringWithFormat:@"https://identitytoolkit.googleapis.com/v2/%@?key=%@", kEndpoint, kAPIKey];

  XCTAssertEqualObjects(expectedURL, request.requestURL.absoluteString);
}

/** @fn testInitWithEndpointUseIdentityPlatformUseStagingExpectedRequestURL
    @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
   request inputs when the Identity Platform and staging endpoint is specified.
 */
- (void)testInitWithEndpointUseIdentityPlatformUseStagingExpectedRequestURL {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kAPIKey];
  FIRIdentityToolkitRequest *request =
      [[FIRIdentityToolkitRequest alloc] initWithEndpoint:kEndpoint
                                     requestConfiguration:requestConfiguration
                                      useIdentityPlatform:YES
                                               useStaging:YES];
  NSString *expectedURL = [NSString
      stringWithFormat:@"https://staging-identitytoolkit.sandbox.googleapis.com/v2/%@?key=%@",
                       kEndpoint, kAPIKey];

  XCTAssertEqualObjects(expectedURL, request.requestURL.absoluteString);
}

/** @fn testInitWithEndpointUseEmulatorExpectedRequestURL
    @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
   request inputs when the emulator is used.
 */
- (void)testInitWithEndpointUseEmulatorExpectedRequestURL {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kAPIKey];
  requestConfiguration.emulatorHostAndPort = kEmulatorHostAndPort;
  FIRIdentityToolkitRequest *request =
      [[FIRIdentityToolkitRequest alloc] initWithEndpoint:kEndpoint
                                     requestConfiguration:requestConfiguration];
  NSString *expectedURL = [NSString
      stringWithFormat:@"http://%@/www.googleapis.com/identitytoolkit/v3/relyingparty/%@?key=%@",
                       kEmulatorHostAndPort, kEndpoint, kAPIKey];

  XCTAssertEqualObjects(expectedURL, request.requestURL.absoluteString);
}

/** @fn testInitWithEndpointUseIdentityPlatformUseEmulatorExpectedRequestURL
    @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
   request inputs when the emulator is used with the Identity Platform endpoint.
 */
- (void)testInitWithEndpointUseIdentityPlatformUseEmulatorExpectedRequestURL {
  FIRAuthRequestConfiguration *requestConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kAPIKey];
  requestConfiguration.emulatorHostAndPort = kEmulatorHostAndPort;
  FIRIdentityToolkitRequest *request =
      [[FIRIdentityToolkitRequest alloc] initWithEndpoint:kEndpoint
                                     requestConfiguration:requestConfiguration
                                      useIdentityPlatform:YES
                                               useStaging:NO];
  NSString *expectedURL =
      [NSString stringWithFormat:@"http://%@/identitytoolkit.googleapis.com/v2/%@?key=%@",
                                 kEmulatorHostAndPort, kEndpoint, kAPIKey];

  XCTAssertEqualObjects(expectedURL, request.requestURL.absoluteString);
}

@end
