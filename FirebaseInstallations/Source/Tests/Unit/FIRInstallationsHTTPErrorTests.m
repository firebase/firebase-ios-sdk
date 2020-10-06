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
#import "FirebaseInstallations/Source/Library/Errors/FIRInstallationsHTTPError.h"
#import "FirebaseInstallations/Source/Tests/Utils/FIRKeyedArchivingUtils.h"

@interface FIRInstallationsHTTPErrorTests : XCTestCase

@end

@implementation FIRInstallationsHTTPErrorTests

- (void)testInit {
  NSHTTPURLResponse *HTTPResponse = [self createHTTPResponse];
  NSData *responseData = [self createResponseData];
  FIRInstallationsHTTPError *error =
      [[FIRInstallationsHTTPError alloc] initWithHTTPResponse:HTTPResponse data:responseData];

  XCTAssertNotNil(error);
  XCTAssertEqualObjects(error.HTTPResponse, HTTPResponse);
  XCTAssertEqualObjects(error.data, responseData);
}

- (void)testUserInfoContainsResponseData {
  NSHTTPURLResponse *HTTPResponse = [self createHTTPResponse];
  NSData *responseData = [self createResponseData];
  FIRInstallationsHTTPError *error =
      [[FIRInstallationsHTTPError alloc] initWithHTTPResponse:HTTPResponse data:responseData];

  NSString *failureReason = error.userInfo[NSLocalizedFailureReasonErrorKey];
  XCTAssertNotNil(failureReason);

  // Validate HTTPResponse content.
  XCTAssertTrue([failureReason containsString:HTTPResponse.URL.absoluteString]);
  XCTAssertTrue([failureReason containsString:@(HTTPResponse.statusCode).stringValue]);
  XCTAssertTrue([failureReason containsString:@(HTTPResponse.statusCode).stringValue]);

  // Validate response data content.
  XCTAssertTrue([failureReason containsString:@"invalid request"]);
  XCTAssertTrue([failureReason containsString:@"Invalid parameters"]);
}

- (NSHTTPURLResponse *)createHTTPResponse {
  return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]
                                     statusCode:403
                                    HTTPVersion:@"1.1"
                                   headerFields:@{@"header1" : @"value1"}];
}

- (NSData *)createResponseData {
  NSDictionary *response = @{@"invalid request" : @"Invalid parameters"};
  NSData *responseData = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
  XCTAssertNotNil(responseData);
  return responseData;
}

- (void)testCopying {
  NSHTTPURLResponse *HTTPResponse = [self createHTTPResponse];
  NSData *responseData = [self createResponseData];
  FIRInstallationsHTTPError *error =
      [[FIRInstallationsHTTPError alloc] initWithHTTPResponse:HTTPResponse data:responseData];

  FIRInstallationsHTTPError *clone = [error copy];

  XCTAssertEqualObjects(error, clone);
  XCTAssertEqualObjects(error.HTTPResponse, clone.HTTPResponse);
  XCTAssertEqualObjects(error.data, clone.data);
}

- (void)testCoding {
  NSHTTPURLResponse *HTTPResponse = [self createHTTPResponse];
  NSData *responseData = [self createResponseData];
  FIRInstallationsHTTPError *error =
      [[FIRInstallationsHTTPError alloc] initWithHTTPResponse:HTTPResponse data:responseData];

  NSError *codingError;
  NSData *archive = [FIRKeyedArchivingUtils archivedDataWithRootObject:error error:&codingError];
  XCTAssertNotNil(archive, @"Error: %@", codingError);

  FIRInstallationsHTTPError *unarchivedError =
      [FIRKeyedArchivingUtils unarchivedObjectOfClass:[FIRInstallationsHTTPError class]
                                             fromData:archive
                                                error:&codingError];
  XCTAssertNotNil(unarchivedError, @"Error: %@", codingError);

  // The error will not be equal because two different instances of NSHTTPURLResponse with the same
  // content are not equal. Let's check the content below.
  XCTAssertEqual(error.HTTPResponse.statusCode, unarchivedError.HTTPResponse.statusCode);
  XCTAssertEqualObjects(error.HTTPResponse.allHeaderFields,
                        unarchivedError.HTTPResponse.allHeaderFields);
  XCTAssertEqualObjects(error.HTTPResponse.URL, unarchivedError.HTTPResponse.URL);
  XCTAssertEqualObjects(error.data, unarchivedError.data);
}

@end
