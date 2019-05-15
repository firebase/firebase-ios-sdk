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

#import "GDTCCTTests/Unit/Helpers/GDTCCTEventGenerator.h"

#import <GoogleDataTransport/GDTTargets.h>

@implementation GDTCCTEventGenerator

// Atomic, but not threadsafe.
static volatile NSUInteger gCounter = 0;

- (void)deleteGeneratedFilesFromDisk {
  for (GDTStoredEvent *storedEvent in self.allGeneratedEvents) {
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtURL:storedEvent.dataFuture.fileURL error:&error];
    NSAssert(error == nil, @"There was an error deleting a temporary event file.");
  }
}

- (GDTStoredEvent *)generateStoredEvent:(GDTEventQoS)qosTier {
  NSString *cachePath = NSTemporaryDirectory();
  NSString *filePath = [cachePath
      stringByAppendingPathComponent:[NSString stringWithFormat:@"test-%ld.txt",
                                                                (unsigned long)gCounter]];
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1018" target:kGDTTargetCCT];
  event.clockSnapshot = [GDTClock snapshot];
  event.qosTier = qosTier;
  [[NSFileManager defaultManager] createFileAtPath:filePath contents:[NSData data] attributes:nil];
  gCounter++;
  GDTDataFuture *future = [[GDTDataFuture alloc] initWithFileURL:[NSURL fileURLWithPath:filePath]];
  GDTStoredEvent *storedEvent = [event storedEventWithDataFuture:future];
  [self.allGeneratedEvents addObject:storedEvent];
  return storedEvent;
}

- (GDTStoredEvent *)generateStoredEvent:(GDTEventQoS)qosTier fileURL:(NSURL *)fileURL {
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1018" target:kGDTTargetCCT];
  event.clockSnapshot = [GDTClock snapshot];
  event.qosTier = qosTier;
  gCounter++;
  GDTDataFuture *future =
      [[GDTDataFuture alloc] initWithFileURL:[NSURL fileURLWithPath:fileURL.path]];
  GDTStoredEvent *storedEvent = [event storedEventWithDataFuture:future];
  [self.allGeneratedEvents addObject:storedEvent];
  return storedEvent;
}

- (NSArray<GDTStoredEvent *> *)generateTheFiveConsistentStoredEvents {
  NSMutableArray<GDTStoredEvent *> *storedEvents = [[NSMutableArray alloc] init];
  NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
  {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1018" target:kGDTTargetCCT];
    event.clockSnapshot = [GDTClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111222) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(1235567890) forKeyPath:@"uptime"];
    event.qosTier = GDTEventQosDefault;
    event.customPrioritizationParams = @{@"customParam" : @1337};
    GDTDataFuture *future = [[GDTDataFuture alloc]
        initWithFileURL:[testBundle URLForResource:@"message-32347456.dat" withExtension:nil]];
    GDTStoredEvent *storedEvent = [event storedEventWithDataFuture:future];
    [storedEvents addObject:storedEvent];
  }

  {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1018" target:kGDTTargetCCT];
    event.clockSnapshot = [GDTClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111333) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(1236567890) forKeyPath:@"uptime"];
    event.qosTier = GDTEventQoSWifiOnly;
    GDTDataFuture *future = [[GDTDataFuture alloc]
        initWithFileURL:[testBundle URLForResource:@"message-35458880.dat" withExtension:nil]];
    GDTStoredEvent *storedEvent = [event storedEventWithDataFuture:future];
    [storedEvents addObject:storedEvent];
  }

  {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1018" target:kGDTTargetCCT];
    event.clockSnapshot = [GDTClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111444) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(1237567890) forKeyPath:@"uptime"];
    event.qosTier = GDTEventQosDefault;
    GDTDataFuture *future = [[GDTDataFuture alloc]
        initWithFileURL:[testBundle URLForResource:@"message-39882816.dat" withExtension:nil]];
    GDTStoredEvent *storedEvent = [event storedEventWithDataFuture:future];
    [storedEvents addObject:storedEvent];
  }

  {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1018" target:kGDTTargetCCT];
    event.clockSnapshot = [GDTClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111555) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(1238567890) forKeyPath:@"uptime"];
    event.qosTier = GDTEventQosDefault;
    event.customPrioritizationParams = @{@"customParam1" : @"aValue1"};
    GDTDataFuture *future = [[GDTDataFuture alloc]
        initWithFileURL:[testBundle URLForResource:@"message-40043840.dat" withExtension:nil]];
    GDTStoredEvent *storedEvent = [event storedEventWithDataFuture:future];
    [storedEvents addObject:storedEvent];
  }

  {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1018" target:kGDTTargetCCT];
    event.clockSnapshot = [GDTClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111666) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(1239567890) forKeyPath:@"uptime"];
    event.qosTier = GDTEventQoSTelemetry;
    event.customPrioritizationParams = @{@"customParam2" : @(34)};
    GDTDataFuture *future = [[GDTDataFuture alloc]
        initWithFileURL:[testBundle URLForResource:@"message-40657984.dat" withExtension:nil]];
    GDTStoredEvent *storedEvent = [event storedEventWithDataFuture:future];
    [storedEvents addObject:storedEvent];
  }
  return storedEvents;
}

@end
