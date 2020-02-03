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

/** An event generator for testing the CCT target. */
@property(nonatomic) GDTCCTEventGenerator *CCTGenerator;

/** An event generator for testing the FLL target. */
@property(nonatomic) GDTCCTEventGenerator *FLLGenerator;

/** An event generator for testing the CSH target. */
@property(nonatomic) GDTCCTEventGenerator *CSHGenerator;

@end

@implementation GDTCCTPrioritizerTest

- (void)setUp {
  self.CCTGenerator = [[GDTCCTEventGenerator alloc] initWithTarget:kGDTCORTargetCCT];
  self.FLLGenerator = [[GDTCCTEventGenerator alloc] initWithTarget:kGDTCORTargetFLL];
  self.CSHGenerator = [[GDTCCTEventGenerator alloc] initWithTarget:kGDTCORTargetCSH];
}

- (void)tearDown {
  [super tearDown];
  [self.CCTGenerator deleteGeneratedFilesFromDisk];
  [self.FLLGenerator deleteGeneratedFilesFromDisk];
  [self.CSHGenerator deleteGeneratedFilesFromDisk];
}

/** Tests prioritizing events. */
- (void)testPrioritizeEvent {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_FLLGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CSHGenerator generateStoredEvent:GDTCOREventQosDefault]];
  dispatch_sync(prioritizer.queue, ^{
    XCTAssertEqual(prioritizer.CCTEvents.count, 1);
    XCTAssertEqual(prioritizer.FLLEvents.count, 1);
    XCTAssertEqual(prioritizer.CSHEvents.count, 1);
  });
}

/** Tests prioritizing multiple events. */
- (void)testPrioritizeMultipleEvents {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_FLLGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CSHGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_FLLGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CSHGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  dispatch_sync(prioritizer.queue, ^{
    XCTAssertEqual(prioritizer.CCTEvents.count, 5);
    XCTAssertEqual(prioritizer.FLLEvents.count, 2);
    XCTAssertEqual(prioritizer.CSHEvents.count, 2);
  });
}

/** Tests unprioritizing events. */
- (void)testPackageDelivered {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_FLLGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CSHGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_FLLGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CSHGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  dispatch_sync(prioritizer.queue, ^{
    XCTAssertEqual(prioritizer.CCTEvents.count, 5);
    XCTAssertEqual(prioritizer.FLLEvents.count, 2);
    XCTAssertEqual(prioritizer.CSHEvents.count, 2);
  });
  GDTCORUploadPackage *package =
      [prioritizer uploadPackageWithTarget:kGDTCORTargetFLL
                                conditions:GDTCORUploadConditionWifiData];
  [prioritizer packageDelivered:package successful:YES];
  package = [prioritizer uploadPackageWithTarget:kGDTCORTargetFLL
                                      conditions:GDTCORUploadConditionWifiData];
  XCTAssertEqual(package.events.count, 0);
}

/** Tests providing events for upload. */
- (void)testEventsForUpload {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQoSWifiOnly]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQoSTelemetry]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQoSWifiOnly]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQosDefault]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQoSDaily]];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQoSTelemetry]];
  GDTCORUploadPackage *package =
      [prioritizer uploadPackageWithTarget:kGDTCORTargetCCT
                                conditions:GDTCORUploadConditionWifiData];
  for (GDTCORStoredEvent *storedEvent in package.events) {
    XCTAssertTrue(storedEvent.qosTier == GDTCOREventQoSTelemetry ||
                  storedEvent.qosTier == GDTCOREventQoSWifiOnly ||
                  storedEvent.qosTier == GDTCOREventQosDefault ||
                  storedEvent.qosTier == GDTCOREventQoSDaily);
  }
  XCTAssertEqual(package.events.count, 9);
  package = [prioritizer uploadPackageWithTarget:kGDTCORTargetCCT
                                      conditions:GDTCORUploadConditionMobileData];
  for (GDTCORStoredEvent *storedEvent in package.events) {
    XCTAssertTrue(storedEvent.qosTier == GDTCOREventQoSTelemetry ||
                  storedEvent.qosTier == GDTCOREventQosDefault);
  }
  XCTAssertEqual(package.events.count, 4);
}

/** Tests providing daily uploaded events. */
- (void)testDailyUpload {
  GDTCCTPrioritizer *prioritizer = [[GDTCCTPrioritizer alloc] init];
  GDTCORStoredEvent *dailyEvent = [_CCTGenerator generateStoredEvent:GDTCOREventQoSDaily];
  [prioritizer prioritizeEvent:[_CCTGenerator generateStoredEvent:GDTCOREventQoSWifiOnly]];
  GDTCORStoredEvent *telemetryEvent = [_CCTGenerator generateStoredEvent:GDTCOREventQoSTelemetry];
  [prioritizer prioritizeEvent:dailyEvent];
  [prioritizer prioritizeEvent:telemetryEvent];
  GDTCORUploadPackage *package =
      [prioritizer uploadPackageWithTarget:kGDTCORTargetCCT
                                conditions:GDTCORUploadConditionWifiData];
  // If no previous daily upload time existed, the daily event will be included.
  XCTAssertTrue([package.events containsObject:dailyEvent]);

  // If a previous daily upload time exists, but now is not > 24h from then, it is excluded.
  package = [prioritizer uploadPackageWithTarget:kGDTCORTargetCCT
                                      conditions:GDTCORUploadConditionMobileData];
  XCTAssertFalse([package.events containsObject:dailyEvent]);

  // If a previous daily upload time exists and it's > 24h ago, daily logs are included.
  prioritizer.CCTTimeOfLastDailyUpload = [GDTCORClock snapshot];
  int64_t previousTime =
      prioritizer.CCTTimeOfLastDailyUpload.timeMillis - (24 * 60 * 60 * 1000 + 1);
  [prioritizer.CCTTimeOfLastDailyUpload setValue:@(previousTime) forKeyPath:@"timeMillis"];
  package = [prioritizer uploadPackageWithTarget:kGDTCORTargetCCT
                                      conditions:GDTCORUploadConditionMobileData];
  XCTAssertTrue([package.events containsObject:dailyEvent]);
  XCTAssertTrue([package.events containsObject:telemetryEvent]);
}

@end
