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
  self.generator = [[GDTCCTEventGenerator alloc] initWithTarget:kGDTCORTargetFLL];
}

- (void)tearDown {
  [super tearDown];
  [self.generator deleteGeneratedFilesFromDisk];
}

/** Tests prioritizing events. */
- (void)testCCTPrioritizeEvent {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  dispatch_sync(prioritizer.queue, ^{
    XCTAssertEqual(prioritizer.events.count, 1);
  });
}

/** Tests prioritizing multiple events. */
- (void)testCCTPrioritizeMultipleEvents {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  dispatch_sync(prioritizer.queue, ^{
    XCTAssertEqual(prioritizer.events.count, 9);
  });
}

/** Tests unprioritizing events. */
- (void)testCCTPackageDelivered {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  dispatch_sync(prioritizer.queue, ^{
    XCTAssertEqual(prioritizer.events.count, 9);
  });
  GDTCORUploadPackage *package =
      [prioritizer uploadPackageWithConditions:GDTCORUploadConditionWifiData];
  [prioritizer packageDelivered:package successful:YES];
  package = [prioritizer uploadPackageWithConditions:GDTCORUploadConditionWifiData];
  XCTAssertEqual(package.events.count, 0);
}

/** Tests providing events for upload. */
- (void)testCCTEventsForUpload {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQoSWifiOnly]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQoSTelemetry]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQoSWifiOnly]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQoSDaily]];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQoSTelemetry]];
  GDTCORUploadPackage *package =
      [prioritizer uploadPackageWithConditions:GDTCORUploadConditionWifiData];
  for (GDTCORStoredEvent *storedEvent in package.events) {
    XCTAssertTrue(storedEvent.qosTier == GDTCOREventQoSTelemetry ||
                  storedEvent.qosTier == GDTCOREventQoSWifiOnly ||
                  storedEvent.qosTier == GDTCOREventQosDefault ||
                  storedEvent.qosTier == GDTCOREventQoSDaily);
  }
  XCTAssertEqual(package.events.count, 9);
  package = [prioritizer uploadPackageWithConditions:GDTCORUploadConditionMobileData];
  for (GDTCORStoredEvent *storedEvent in package.events) {
    XCTAssertTrue(storedEvent.qosTier == GDTCOREventQoSTelemetry ||
                  storedEvent.qosTier == GDTCOREventQosDefault);
  }
  XCTAssertEqual(package.events.count, 4);
}

/** Tests providing daily uploaded events. */
- (void)testCCTDailyUpload {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  GDTCORStoredEvent *dailyEvent = [_generator generateStoredEvent:GDTCOREventQoSDaily];
  [prioritizer prioritizeEvent:[_generator generateStoredEvent:GDTCOREventQoSWifiOnly]];
  GDTCORStoredEvent *telemetryEvent = [_generator generateStoredEvent:GDTCOREventQoSTelemetry];
  [prioritizer prioritizeEvent:dailyEvent];
  [prioritizer prioritizeEvent:telemetryEvent];
  GDTCORUploadPackage *package =
      [prioritizer uploadPackageWithConditions:GDTCORUploadConditionWifiData];
  // If no previous daily upload time existed, the daily event will be included.
  XCTAssertTrue([package.events containsObject:dailyEvent]);

  // If a previous daily upload time exists, but now is not > 24h from then, it is excluded.
  package = [prioritizer uploadPackageWithConditions:GDTCORUploadConditionMobileData];
  XCTAssertFalse([package.events containsObject:dailyEvent]);

  // If a previous daily upload time exists and it's > 24h ago, daily logs are included.
  prioritizer.timeOfLastDailyUpload = [GDTCORClock snapshot];
  int64_t previousTime = prioritizer.timeOfLastDailyUpload.timeMillis - (24 * 60 * 60 * 1000 + 1);
  [prioritizer.timeOfLastDailyUpload setValue:@(previousTime) forKeyPath:@"timeMillis"];
  package = [prioritizer uploadPackageWithConditions:GDTCORUploadConditionMobileData];
  XCTAssertTrue([package.events containsObject:dailyEvent]);
  XCTAssertTrue([package.events containsObject:telemetryEvent]);
}

@end
