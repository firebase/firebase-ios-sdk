/*
 * Copyright 2024 Google LLC
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

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckValidator.h"
#import "FirebaseCore/Sources/Public/FirebaseCore/FIROptions.h"

@interface FIRAppCheckValidatorTests : XCTestCase
@end

@implementation FIRAppCheckValidatorTests

- (void)test_tokenExchangeMissingFieldsInOptions_noMissingFields {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"TEST_GoogleAppID"
                                                    GCMSenderID:@"TEST_GCMSenderID"];
  options.APIKey = @"TEST_APIKey";
  options.projectID = @"TEST_ProjectID";

  NSArray *missingFields = [FIRAppCheckValidator tokenExchangeMissingFieldsInOptions:options];

  XCTAssertEqual(missingFields.count, 0);
}

- (void)test_tokenExchangeMissingFieldsInOptions_singleMissingField {
  // Google App ID is empty:
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@""
                                                    GCMSenderID:@"TEST_GCMSenderID"];
  options.APIKey = @"TEST_APIKey";
  options.projectID = @"TEST_ProjectID";

  NSArray *missingFields = [FIRAppCheckValidator tokenExchangeMissingFieldsInOptions:options];

  XCTAssertTrue([missingFields isEqualToArray:@[ @"googleAppID" ]]);
}

- (void)test_tokenExchangeMissingFieldsInOptions_multipleMissingFields {
  // Google App ID is empty, and API Key and Project ID are not set:
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@""
                                                    GCMSenderID:@"TEST_GCMSenderID"];

  NSArray *missingFields = [FIRAppCheckValidator tokenExchangeMissingFieldsInOptions:options];

  NSArray *expectedMissingFields = @[ @"APIKey", @"projectID", @"googleAppID" ];
  XCTAssertTrue([missingFields isEqualToArray:expectedMissingFields]);
}

@end
