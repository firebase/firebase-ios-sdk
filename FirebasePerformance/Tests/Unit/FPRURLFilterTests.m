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

#import "FirebasePerformance/Sources/FPRURLFilter.h"
#import "FirebasePerformance/Sources/FPRURLFilter_Private.h"

#import "FirebasePerformance/Tests/Unit/FPRTestUtils.h"
#import "FirebasePerformance/Tests/Unit/Fakes/NSBundleFake.h"

#import <GoogleDataTransport/GoogleDataTransport.h>

@interface FPRURLFilterTest : XCTestCase

@end

@implementation FPRURLFilterTest

- (void)tearDown {
  [FPRURLFilter sharedInstance].disablePlist = YES;
}

/** Tests that the Clearcut upload URL is denied. */
- (void)testFllClearcutURLDenied {
  XCTAssertFalse([[FPRURLFilter sharedInstance]
      shouldInstrumentURL:[GDTCOREndpoints uploadURLForTarget:kGDTCORTargetCCT].absoluteString]);
}

/** Tests that the FLL upload URL is denied. */
- (void)testFllServiceURLDenied {
  XCTAssertFalse([[FPRURLFilter sharedInstance]
      shouldInstrumentURL:[GDTCOREndpoints uploadURLForTarget:kGDTCORTargetFLL].absoluteString]);
}

/** Tests shouldInstrument when the plist file is not being used. */
- (void)testShouldInstrumentEverythingWithoutPlist {
  FPRURLFilter *filter = [FPRURLFilter sharedInstance];
  filter.disablePlist = YES;
  XCTAssertTrue([filter shouldInstrumentURL:@"https://google.com"]);
  XCTAssertTrue([filter shouldInstrumentURL:@"https://gooogle.com"]);

  XCTAssertTrue([filter shouldInstrumentURL:@"http://mail.google.com"]);
  XCTAssertTrue([filter shouldInstrumentURL:@"http://super.mail.google.com"]);

  XCTAssertTrue([filter shouldInstrumentURL:@"https://www.google.com"]);
  XCTAssertTrue([filter shouldInstrumentURL:@"https://www.gooogle.com"]);

  XCTAssertTrue([filter shouldInstrumentURL:@"http://www.mail.google.com"]);
  XCTAssertTrue([filter shouldInstrumentURL:@"http://www.super.mail.google.com"]);
  filter.disablePlist = NO;
}

/** Tests shouldInstrument when the plist file is being used. */
- (void)testShouldInstrumentUsingPlist {
  NSBundle *bundle = [FPRTestUtils getBundle];
  NSString *plistPath = [bundle pathForResource:@"FPRURLFilterTests-Info" ofType:@"plist"];

  NSDictionary *plistContent = [NSDictionary dictionaryWithContentsOfFile:plistPath];

  NSBundleFake *mainBundle = [[NSBundleFake alloc] init];
  mainBundle.customInfoDictionary = plistContent;

  FPRURLFilter *filter = [[FPRURLFilter alloc] initWithBundle:mainBundle];

  filter.disablePlist = NO;
  XCTAssertTrue([filter shouldInstrumentURL:@"https://google.com"]);
  XCTAssertFalse([filter shouldInstrumentURL:@"https://gooogle.com"]);

  XCTAssertTrue([filter shouldInstrumentURL:@"http://mail.google.com"]);
  XCTAssertTrue([filter shouldInstrumentURL:@"http://super.mail.google.com"]);

  XCTAssertTrue([filter shouldInstrumentURL:@"https://www.google.com"]);
  XCTAssertFalse([filter shouldInstrumentURL:@"https://www.gooogle.com"]);

  XCTAssertTrue([filter shouldInstrumentURL:@"http://www.mail.google.com"]);
  XCTAssertTrue([filter shouldInstrumentURL:@"http://www.super.mail.google.com"]);
  filter.disablePlist = YES;
}

@end
