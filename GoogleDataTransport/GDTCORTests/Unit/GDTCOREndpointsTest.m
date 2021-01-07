/*
 * Copyright 2018 Google
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

#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCOREndpoints_Private.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREndpoints.h"

@interface GDTCOREndpointsTest : XCTestCase

@end

@implementation GDTCOREndpointsTest

/* Verify if the upload URLs are not empty for different endpoints. */
- (void)testUploadURLsAreNotEmpty {
  XCTAssertNotNil([GDTCOREndpoints uploadURLForTarget:kGDTCORTargetCCT]);
  XCTAssertNotNil([GDTCOREndpoints uploadURLForTarget:kGDTCORTargetFLL]);
  XCTAssertNotNil([GDTCOREndpoints uploadURLForTarget:kGDTCORTargetCSH]);
  XCTAssertNotNil([GDTCOREndpoints uploadURLForTarget:kGDTCORTargetINT]);
}

/* Verify if the upload URLs are correct for different endpoints. */
- (void)testUploadURLsAreCorrect {
  NSDictionary<NSNumber *, NSURL *> *uploadURLs = [GDTCOREndpoints uploadURLs];
  XCTAssertEqualObjects([GDTCOREndpoints uploadURLForTarget:kGDTCORTargetCCT],
                        uploadURLs[@(kGDTCORTargetCCT)]);
  XCTAssertEqualObjects([GDTCOREndpoints uploadURLForTarget:kGDTCORTargetFLL],
                        uploadURLs[@(kGDTCORTargetFLL)]);
  XCTAssertEqualObjects([GDTCOREndpoints uploadURLForTarget:kGDTCORTargetCSH],
                        uploadURLs[@(kGDTCORTargetCSH)]);
  XCTAssertEqualObjects([GDTCOREndpoints uploadURLForTarget:kGDTCORTargetINT],
                        uploadURLs[@(kGDTCORTargetINT)]);
}

@end
