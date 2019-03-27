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

#import "GDTCCTEventGenerator.h"

#import <GoogleDataTransport/GDTTargets.h>

@implementation GDTCCTEventGenerator

// Atomic, but not threadsafe.
static volatile NSUInteger gCounter = 0;

- (void)deleteGeneratedFilesFromDisk {
  for (GDTStoredEvent *storedEvent in self.allGeneratedEvents) {
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtURL:storedEvent.eventFileURL error:&error];
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
  GDTStoredEvent *storedEvent = [event storedEventWithFileURL:[NSURL fileURLWithPath:filePath]];
  [self.allGeneratedEvents addObject:storedEvent];
  return storedEvent;
}

- (GDTStoredEvent *)generateStoredEvent:(GDTEventQoS)qosTier fileURL:(NSURL *)fileURL {
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1018" target:kGDTTargetCCT];
  event.clockSnapshot = [GDTClock snapshot];
  event.qosTier = qosTier;
  gCounter++;
  GDTStoredEvent *storedEvent = [event storedEventWithFileURL:[NSURL fileURLWithPath:fileURL.path]];
  [self.allGeneratedEvents addObject:storedEvent];
  return storedEvent;
}

- (NSArray<GDTStoredEvent *> *)generateTheFiveConsistentStoredEvents {
  NSMutableArray<GDTStoredEvent *> *storedEvents = [[NSMutableArray alloc] init];
  NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
  {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1018" target:kGDTTargetCCT];
    event.clockSnapshot = [GDTClock snapshot];
    [event.clockSnapshot setValue:@(1553536373134) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1552576634359451) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(961141987648) forKeyPath:@"uptime"];
    event.qosTier = GDTEventQosDefault;
    event.customPrioritizationParams = @{@"customParam" : @1337};
    GDTStoredEvent *storedEvent =
        [event storedEventWithFileURL:[testBundle URLForResource:@"message-32347456.dat"
                                                   withExtension:nil]];
    [storedEvents addObject:storedEvent];
  }

  {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1018" target:kGDTTargetCCT];
    event.clockSnapshot = [GDTClock snapshot];
    [event.clockSnapshot setValue:@(1553536573957) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1552576634359451) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(961141764308) forKeyPath:@"uptime"];
    event.qosTier = GDTEventQoSWifiOnly;
    GDTStoredEvent *storedEvent =
        [event storedEventWithFileURL:[testBundle URLForResource:@"message-35458880.dat"
                                                   withExtension:nil]];
    [storedEvents addObject:storedEvent];
  }

  {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1018" target:kGDTTargetCCT];
    event.clockSnapshot = [GDTClock snapshot];
    [event.clockSnapshot setValue:@(1553536673239) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1552576634359451) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(961142164964) forKeyPath:@"uptime"];
    event.qosTier = GDTEventQosDefault;
    GDTStoredEvent *storedEvent =
        [event storedEventWithFileURL:[testBundle URLForResource:@"message-39882816.dat"
                                                   withExtension:nil]];
    [storedEvents addObject:storedEvent];
  }

  {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1018" target:kGDTTargetCCT];
    event.clockSnapshot = [GDTClock snapshot];
    [event.clockSnapshot setValue:@(1553534573010) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1552576634359451) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(961141365197) forKeyPath:@"uptime"];
    event.qosTier = GDTEventQosDefault;
    event.customPrioritizationParams = @{@"customParam1" : @"aValue1"};
    GDTStoredEvent *storedEvent =
        [event storedEventWithFileURL:[testBundle URLForResource:@"message-40043840.dat"
                                                   withExtension:nil]];
    [storedEvents addObject:storedEvent];
  }

  {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1018" target:kGDTTargetCCT];
    event.clockSnapshot = [GDTClock snapshot];
    [event.clockSnapshot setValue:@(1553536543875) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1552576634359451) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(961141562094) forKeyPath:@"uptime"];
    event.qosTier = GDTEventQoSTelemetry;
    event.customPrioritizationParams = @{@"customParam2" : @(34)};
    GDTStoredEvent *storedEvent =
        [event storedEventWithFileURL:[testBundle URLForResource:@"message-40657984.dat"
                                                   withExtension:nil]];
    [storedEvents addObject:storedEvent];
  }
  return storedEvents;
}

@end
