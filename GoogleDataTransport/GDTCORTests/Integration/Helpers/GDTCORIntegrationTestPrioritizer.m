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

#import "GDTCORTests/Integration/Helpers/GDTCORIntegrationTestPrioritizer.h"

#import <GoogleDataTransport/GDTCORRegistrar.h>
#import <GoogleDataTransport/GDTCORStoredEvent.h>

#import "GDTCORTests/Integration/Helpers/GDTCORIntegrationTestUploadPackage.h"

@interface GDTCORIntegrationTestPrioritizer ()

/** Events that are only supposed to be uploaded whilst on wifi. */
@property(nonatomic) NSMutableSet<GDTCORStoredEvent *> *wifiOnlyEvents;

/** Events that can be uploaded on any type of connection. */
@property(nonatomic) NSMutableSet<GDTCORStoredEvent *> *nonWifiEvents;

/** The queue on which this prioritizer operates. */
@property(nonatomic) dispatch_queue_t queue;

@end

@implementation GDTCORIntegrationTestPrioritizer

- (instancetype)init {
  self = [super init];
  if (self) {
    _queue =
        dispatch_queue_create("com.google.GDTCORIntegrationTestPrioritizer", DISPATCH_QUEUE_SERIAL);
    _wifiOnlyEvents = [[NSMutableSet alloc] init];
    _nonWifiEvents = [[NSMutableSet alloc] init];
    [[GDTCORRegistrar sharedInstance] registerPrioritizer:self target:kGDTCORIntegrationTestTarget];
  }
  return self;
}

- (void)prioritizeEvent:(GDTCORStoredEvent *)event {
  dispatch_async(_queue, ^{
    if (event.qosTier == GDTCOREventQoSWifiOnly) {
      [self.wifiOnlyEvents addObject:event];
    } else {
      [self.nonWifiEvents addObject:event];
    }
  });
}

- (GDTCORUploadPackage *)uploadPackageWithConditions:(GDTCORUploadConditions)conditions {
  __block GDTCORIntegrationTestUploadPackage *uploadPackage =
      [[GDTCORIntegrationTestUploadPackage alloc] initWithTarget:kGDTCORIntegrationTestTarget];
  dispatch_sync(_queue, ^{
    if ((conditions & GDTCORUploadConditionWifiData) == GDTCORUploadConditionWifiData) {
      uploadPackage.events = [self.wifiOnlyEvents setByAddingObjectsFromSet:self.nonWifiEvents];
    } else {
      uploadPackage.events = self.nonWifiEvents;
    }
  });
  return uploadPackage;
}

- (void)packageDelivered:(GDTCORUploadPackage *)package successful:(BOOL)successful {
  dispatch_async(_queue, ^{
    for (GDTCORStoredEvent *event in package.events) {
      [self.wifiOnlyEvents removeObject:event];
      [self.nonWifiEvents removeObject:event];
    }
  });
}

@end
