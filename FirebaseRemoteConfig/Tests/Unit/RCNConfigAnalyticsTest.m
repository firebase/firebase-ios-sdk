#import <XCTest/XCTest.h>

#import "RCNConfigAnalytics.h"
#import "googlemac/iPhone/Firebase/Analytics/InternalHeaders/FIRAnalytics+Internal.h"
#import "third_party/objective_c/ocmock/v3/Source/OCMock/OCMock.h"

@interface RCNConfigAnalyticsTest : XCTestCase {
  id _mockAnalytics;
  RCNConfigAnalytics *_configAnalytics;
}
@end

@implementation RCNConfigAnalyticsTest

- (void)setUp {
  [super setUp];
  _mockAnalytics = OCMClassMock([FIRAnalytics class]);
  _configAnalytics = [[RCNConfigAnalytics alloc] init];
}

- (void)testFetchUserProperty {
  XCTestExpectation *fetchExpectation =
      [self expectationWithDescription:@"Test fetch user property."];

  // Mocks the user property fetching response.
  OCMStub([_mockAnalytics userPropertiesIncludingInternal:NO
                                                    queue:[OCMArg any]
                                                 callback:([OCMArg invokeBlockWithArgs:@{
                                                   @"user_property_event_name" : @"level up",
                                                   @"user_property_gold_amount" : @"1800",
                                                   @"user_property_level" : @20
                                                 },
                                                                                       nil])]);

  [_configAnalytics fetchUserPropertiesWithCompletionHandler:^(NSDictionary *userProperties) {
    XCTAssertNotNil(userProperties);
    XCTAssertEqual(userProperties.count, 3);
    XCTAssertEqualObjects(@"level up", userProperties[@"user_property_event_name"]);
    XCTAssertEqualObjects(@20, userProperties[@"user_property_level"]);
    XCTAssertEqualObjects(@"1800", userProperties[@"user_property_gold_amount"]);

    [fetchExpectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:1.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testFetchUserPropertyWithEmptyResponse {
  XCTestExpectation *fetchExpectation =
      [self expectationWithDescription:@"Test fetch empty user property."];

  // Mocks the user property fetching response.
  OCMStub([_mockAnalytics userPropertiesIncludingInternal:NO
                                                    queue:[OCMArg any]
                                                 callback:([OCMArg invokeBlockWithArgs:@{}, nil])]);

  // Tests passing nil callback won't crash.
  [_configAnalytics fetchUserPropertiesWithCompletionHandler:nil];

  [_configAnalytics fetchUserPropertiesWithCompletionHandler:^(NSDictionary *userProperties) {
    XCTAssertNotNil(userProperties);
    XCTAssertEqual(userProperties.count, 0);
    [fetchExpectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:1.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}
@end
