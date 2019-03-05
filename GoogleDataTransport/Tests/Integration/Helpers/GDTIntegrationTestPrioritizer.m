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

#import "GDTIntegrationTestUploadPackage.h"

@interface GDTIntegrationTestPrioritizer ()

/** Events that are only supposed to be uploaded whilst on wifi. */
@property(nonatomic) NSMutableSet *wifiOnlyEvents;

/** Events that can be uploaded on any type of connection. */
@property(nonatomic) NSMutableSet *nonWifiEvents;

/** The queue on which this prioritizer operates. */
@property(nonatomic) dispatch_queue_t queue;

@end

@implementation GDTIntegrationTestPrioritizer

- (instancetype)init {
  self = [super init];
  if (self) {
    _queue =
        dispatch_queue_create("com.google.GDTIntegrationTestPrioritizer", DISPATCH_QUEUE_SERIAL);
    _wifiOnlyEvents = [[NSMutableSet alloc] init];
    _nonWifiEvents = [[NSMutableSet alloc] init];
    [[GDTRegistrar sharedInstance] registerPrioritizer:self target:kGDTIntegrationTestTarget];
  }
  return self;
}

- (void)prioritizeEvent:(GDTEvent *)event {
  NSUInteger eventHash = event.hash;
  NSInteger qosTier = event.qosTier;
  dispatch_async(_queue, ^{
    if (qosTier == GDTEventQoSWifiOnly) {
      [self.wifiOnlyEvents addObject:@(eventHash)];
    } else {
      [self.nonWifiEvents addObject:@(eventHash)];
    }
  });
}

- (void)unprioritizeEvent:(NSNumber *)eventHash {
  dispatch_async(_queue, ^{
    [self.wifiOnlyEvents removeObject:eventHash];
    [self.nonWifiEvents removeObject:eventHash];
  });
}

- (GDTUploadPackage *)uploadPackageWithConditions:(GDTUploadConditions)conditions {
  __block GDTIntegrationTestUploadPackage *uploadPackage =
      [[GDTIntegrationTestUploadPackage alloc] init];
  dispatch_sync(_queue, ^{
    if ((conditions & GDTUploadConditionWifiData) == GDTUploadConditionWifiData) {
      uploadPackage.eventHashes = self.wifiOnlyEvents;
    } else {
      uploadPackage.eventHashes = self.nonWifiEvents;
    }
  });
  return uploadPackage;
}

@end
