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

#import "GDTIntegrationTestPrioritizer.h"

@interface GDTIntegrationTestPrioritizer ()

/** Logs that are only supposed to be uploaded whilst on wifi. */
@property(nonatomic) NSMutableSet *wifiOnlyLogs;

/** Logs that can be uploaded on any type of connection. */
@property(nonatomic) NSMutableSet *nonWifiLogs;

/** The queue on which this prioritizer operates. */
@property(nonatomic) dispatch_queue_t queue;

@end

@implementation GDTIntegrationTestPrioritizer

- (instancetype)init {
  self = [super init];
  if (self) {
    _queue =
        dispatch_queue_create("com.google.GDTIntegrationTestPrioritizer", DISPATCH_QUEUE_SERIAL);
    _wifiOnlyLogs = [[NSMutableSet alloc] init];
    _nonWifiLogs = [[NSMutableSet alloc] init];
    [[GDTRegistrar sharedInstance] registerPrioritizer:self logTarget:kGDTIntegrationTestTarget];
  }
  return self;
}

- (void)prioritizeLog:(GDTLogEvent *)logEvent {
  dispatch_sync(_queue, ^{
    if (logEvent.qosTier == GDTLogQoSWifiOnly) {
      [self.wifiOnlyLogs addObject:@(logEvent.hash)];
    } else {
      [self.nonWifiLogs addObject:@(logEvent.hash)];
    }
  });
}

- (void)unprioritizeLog:(NSNumber *)logHash {
  dispatch_sync(_queue, ^{
    [self.wifiOnlyLogs removeObject:logHash];
    [self.nonWifiLogs removeObject:logHash];
  });
}

- (nonnull NSSet<NSNumber *> *)logsToUploadGivenConditions:(GDTUploadConditions)conditions {
  __block NSSet<NSNumber *> *logs;
  dispatch_sync(_queue, ^{
    if ((conditions & GDTUploadConditionWifiData) == GDTUploadConditionWifiData) {
      logs = self.wifiOnlyLogs;
    } else {
      logs = self.nonWifiLogs;
    }
  });
  return logs;
}

@end
