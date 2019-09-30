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

#import "GDTCCTTests/Unit/Helpers/GDTCCTEventGenerator.h"

#import "GDTCCTLibrary/Private/GDTCCTPrioritizer.h"

@interface GDTCCTPrioritizerTest : XCTestCase

/** An event generator for testing. */
@property(nonatomic) GDTCCTEventGenerator *generator;

@end

@implementation GDTCCTPrioritizerTest

- (void)setUp {
  self.generator = [[GDTCCTEventGenerator alloc] init];
}

- (void)tearDown {
  [super tearDown];
  [self.generator deleteGeneratedFilesFromDisk];
}

/** Tests prioritizing events. */
- (void)testPrioritizeEvent {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  dispatch_sync(prioritizer.queue, ^{
    XCTAssertEqual(prioritizer.events.count, 1);
  });
}

/** Tests prioritizing multiple events. */
- (void)testPrioritizeMultipleEvents {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  dispatch_sync(prioritizer.queue, ^{
    XCTAssertEqual(prioritizer.events.count, 9);
  });
}

/** Tests unprioritizing events. */
- (void)testPackageDelivered {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  dispatch_sync(prioritizer.queue, ^{
    XCTAssertEqual(prioritizer.events.count, 9);
  });
  GDTUploadPackage *package = [prioritizer uploadPackageWithConditions:GDTUploadConditionWifiData];
  [prioritizer packageDelivered:package successful:YES];
  package = [prioritizer uploadPackageWithConditions:GDTUploadConditionWifiData];
  XCTAssertEqual(package.events.count, 0);
}

/** Tests providing events for upload. */
- (void)testEventsForUpload {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQoSWifiOnly]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQoSTelemetry]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQoSWifiOnly]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQoSDaily]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQoSTelemetry]];
  GDTUploadPackage *package = [prioritizer uploadPackageWithConditions:GDTUploadConditionWifiData];
  for (GDTStoredEvent *storedEvent in package.events) {
    XCTAssertTrue(
        storedEvent.qosTier == GDTEventQoSTelemetry || storedEvent.qosTier == GDTEventQoSWifiOnly ||
        storedEvent.qosTier == GDTEventQosDefault || storedEvent.qosTier == GDTEventQoSDaily);
  }
  XCTAssertEqual(package.events.count, 9);
  package = [prioritizer uploadPackageWithConditions:GDTUploadConditionMobileData];
  for (GDTStoredEvent *storedEvent in package.events) {
    XCTAssertTrue(storedEvent.qosTier == GDTEventQoSTelemetry ||
                  storedEvent.qosTier == GDTEventQosDefault);
  }
  XCTAssertEqual(package.events.count, 4);
}

/** Tests providing daily uploaded events. */
- (void)testDailyUpload {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  GDTStoredEvent *dailyEvent = [_generator generateStoredEvent:GDTEventQoSDaily];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTEventQoSWifiOnly]];
  GDTStoredEvent *telemetryEvent = [_generator generateStoredEvent:GDTEventQoSTelemetry];
  [prioritizer prioritizeEvent:dailyEvent];
  [prioritizer prioritizeEvent:telemetryEvent];
  GDTUploadPackage *package = [prioritizer uploadPackageWithConditions:GDTUploadConditionWifiData];
  // If no previous daily upload time existed, the daily event will be included.
  XCTAssertTrue([package.events containsObject:dailyEvent]);

  // If a previous daily upload time exists, but now is not > 24h from then, it is excluded.
  package = [prioritizer uploadPackageWithConditions:GDTUploadConditionMobileData];
  XCTAssertFalse([package.events containsObject:dailyEvent]);

  // If a previous daily upload time exists and it's > 24h ago, daily logs are included.
  prioritizer.timeOfLastDailyUpload = [GDTClock snapshot];
  int64_t previousTime = prioritizer.timeOfLastDailyUpload.timeMillis - (24 * 60 * 60 * 1000 + 1);
  [prioritizer.timeOfLastDailyUpload setValue:@(previousTime) forKeyPath:@"timeMillis"];
  package = [prioritizer uploadPackageWithConditions:GDTUploadConditionMobileData];
  XCTAssertTrue([package.events containsObject:dailyEvent]);
  XCTAssertTrue([package.events containsObject:telemetryEvent]);
}

@end
