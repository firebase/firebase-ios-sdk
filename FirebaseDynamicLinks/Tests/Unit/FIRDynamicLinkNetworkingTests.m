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

#import <OCMock/OCMock.h>

#import <GoogleUtilities/GULSwizzler.h>

#import <GoogleUtilities/GULSwizzler+Unswizzle.h>
#import "FirebaseDynamicLinks/Sources/FIRDynamicLinkNetworking+Private.h"

static NSString *const kAPIKey = @"myfakeapikey";
const NSInteger kJSONParsingErrorCode = 3840;
static NSString *const kURLScheme = @"gindeeplinkurl";
static const NSTimeInterval kAsyncTestTimeout = 5.0;

@interface FIRDynamicLinkNetworkingTests : XCTestCase

@property(strong, nonatomic) FIRDynamicLinkNetworking *service;

@end

@implementation FIRDynamicLinkNetworkingTests

- (void)tearDown {
  self.service = nil;
}

- (FIRDynamicLinkNetworking *)service {
  if (!_service) {
    _service = [[FIRDynamicLinkNetworking alloc] initWithAPIKey:kAPIKey URLScheme:kURLScheme];
  }
  return _service;
}

- (void)testFIRDynamicLinkAPIKeyParameterReturnsCorrectlyFormattedParameterString {
  NSString *expectedValue = [NSString stringWithFormat:@"?key=%@", kAPIKey];

  NSString *parameter = FIRDynamicLinkAPIKeyParameter(kAPIKey);

  XCTAssertEqualObjects(parameter, expectedValue,
                        @"FIRDynamicLinkAPIKeyParameter() returned incorrect parameter string");
}

- (void)testFIRDynamicLinkAPIKeyParameterReturnsNilParameterStringWhenAPIKeyIsNil {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  NSString *parameter = FIRDynamicLinkAPIKeyParameter(nil);
#pragma clang diagnostic pop

  XCTAssertNil(parameter,
               @"FIRDynamicLinkAPIKeyParameter() returned non-nil result when API key was nil");
}

- (void)testResolveShortLinkServiceCompletionDoesntCrashWhenNilDataIsRetrieved {
  NSURL *url = [NSURL URLWithString:@"https://google.com"];

  void (^executeRequestBlock)(id, NSDictionary *, NSString *, FIRNetworkRequestCompletionHandler) =
      ^(id p1, NSDictionary *requestBody, NSString *requestURLString,
        FIRNetworkRequestCompletionHandler handler) {
        handler(nil, nil, nil);
      };

  SEL executeRequestSelector = @selector(executeOnePlatformRequest:forURL:completionHandler:);

  [GULSwizzler swizzleClass:[FIRDynamicLinkNetworking class]
                   selector:executeRequestSelector
            isClassSelector:NO
                  withBlock:executeRequestBlock];

  XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];

  [self.service resolveShortLink:url
                   FDLSDKVersion:@"1.0.0"
                      completion:^(NSURL *_Nullable url, NSError *_Nullable error) {
                        [expectation fulfill];
                      }];

  [self waitForExpectationsWithTimeout:kAsyncTestTimeout handler:nil];

  [GULSwizzler unswizzleClass:[FIRDynamicLinkNetworking class]
                     selector:executeRequestSelector
              isClassSelector:NO];
}

@end
