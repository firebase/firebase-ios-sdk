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
#import "OCMock.h"

#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"
#import "FirebaseRemoteConfig/Sources/RCNPersonalization.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

@interface RCNPersonalizationTest : XCTestCase {
  NSDictionary *_configContainer;
  NSMutableArray<NSDictionary *> *_fakeLogs;
  id _analyticsMock;
}
@end

@implementation RCNPersonalizationTest
- (void)setUp {
  [super setUp];

  _configContainer = @{
    RCNFetchResponseKeyEntries : @{
      @"key1" : [[FIRRemoteConfigValue alloc]
          initWithData:[@"value1" dataUsingEncoding:NSUTF8StringEncoding]
                source:FIRRemoteConfigSourceRemote],
      @"key2" : [[FIRRemoteConfigValue alloc]
          initWithData:[@"value2" dataUsingEncoding:NSUTF8StringEncoding]
                source:FIRRemoteConfigSourceRemote],
      @"key3" : [[FIRRemoteConfigValue alloc]
          initWithData:[@"value3" dataUsingEncoding:NSUTF8StringEncoding]
                source:FIRRemoteConfigSourceRemote]
    },
    RCNFetchResponseKeyPersonalizationMetadata :
        @{@"key1" : @{kPersonalizationId : @"id1"}, @"key2" : @{kPersonalizationId : @"id2"}}
  };

  _fakeLogs = [[NSMutableArray alloc] init];
  _analyticsMock = OCMProtocolMock(@protocol(FIRAnalyticsInterop));
  OCMStub([_analyticsMock logEventWithOrigin:kAnalyticsOriginPersonalization
                                        name:kAnalyticsPullEvent
                                  parameters:[OCMArg isKindOfClass:[NSDictionary class]]])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSDictionary *bundle;
        [invocation getArgument:&bundle atIndex:4];
        [self->_fakeLogs addObject:bundle];
      });

  [RCNPersonalization setAnalytics:_analyticsMock];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testNonPersonalizationKey {
  [_fakeLogs removeAllObjects];

  [RCNPersonalization logArmActive:@"key3" config:_configContainer];

  OCMVerify(never(),
            [_analyticsMock logEventWithOrigin:kAnalyticsOriginPersonalization
                                          name:kAnalyticsPullEvent
                                    parameters:[OCMArg isKindOfClass:[NSDictionary class]]]);
  XCTAssertEqual([_fakeLogs count], 0);
}

- (void)testSinglePersonalizationKey {
  [_fakeLogs removeAllObjects];

  [RCNPersonalization logArmActive:@"key1" config:_configContainer];

  OCMVerify(times(1),
            [_analyticsMock logEventWithOrigin:kAnalyticsOriginPersonalization
                                          name:kAnalyticsPullEvent
                                    parameters:[OCMArg isKindOfClass:[NSDictionary class]]]);
  XCTAssertEqual([_fakeLogs count], 1);

  NSDictionary *params = @{kArmKey : @"id1", kArmValue : @"value1"};
  XCTAssertEqualObjects(_fakeLogs[0], params);
}

- (void)testMultiplePersonalizationKeys {
  [_fakeLogs removeAllObjects];

  [RCNPersonalization logArmActive:@"key1" config:_configContainer];
  [RCNPersonalization logArmActive:@"key2" config:_configContainer];

  OCMVerify(times(2),
            [_analyticsMock logEventWithOrigin:kAnalyticsOriginPersonalization
                                          name:kAnalyticsPullEvent
                                    parameters:[OCMArg isKindOfClass:[NSDictionary class]]]);
  XCTAssertEqual([_fakeLogs count], 2);

  NSDictionary *params1 = @{kArmKey : @"id1", kArmValue : @"value1"};
  XCTAssertEqualObjects(_fakeLogs[0], params1);

  NSDictionary *params2 = @{kArmKey : @"id2", kArmValue : @"value2"};
  XCTAssertEqualObjects(_fakeLogs[1], params2);
}

@end
