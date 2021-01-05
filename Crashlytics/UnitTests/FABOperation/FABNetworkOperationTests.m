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

#import "Crashlytics/Crashlytics/Settings/Operations/FIRCLSNetworkOperation.h"

#import <XCTest/XCTest.h>

#import "Crashlytics/Shared/FIRCLSConstants.h"

#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionToken.h"

@interface FABNetworkOperationTests : XCTestCase

@end

@implementation FABNetworkOperationTests

- (void)testNetworkOperationHeaders {
  FIRCLSDataCollectionToken *token = [FIRCLSDataCollectionToken validToken];
  NSString *googleAppID = @"someGoogleAppID";

  FIRCLSNetworkOperation *networkOperation =
      [[FIRCLSNetworkOperation alloc] initWithGoogleAppID:googleAppID token:token];
  NSURL *url = [NSURL URLWithString:@"https://www.someEndpoint.com"];
  NSMutableURLRequest *request =
      [networkOperation mutableRequestWithDefaultHTTPHeaderFieldsAndTimeoutForURL:url];

  XCTAssertEqualObjects(
      [request.allHTTPHeaderFields valueForKey:FIRCLSNetworkCrashlyticsGoogleAppId], googleAppID);
}

@end
