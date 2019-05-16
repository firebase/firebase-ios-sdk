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

#import "GDTTests/Integration/Helpers/GDTIntegrationTestPrioritizer.h"

#import <GoogleDataTransport/GDTRegistrar.h>
#import <GoogleDataTransport/GDTStoredEvent.h>

#import "GDTTests/Integration/Helpers/GDTIntegrationTestUploadPackage.h"

@interface GDTIntegrationTestPrioritizer ()

/** Events that are only supposed to be uploaded whilst on wifi. */
@property(nonatomic) NSMutableSet<GDTStoredEvent *> *wifiOnlyEvents;

/** Events that can be uploaded on any type of connection. */
@property(nonatomic) NSMutableSet<GDTStoredEvent *> *nonWifiEvents;

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

- (void)prioritizeEvent:(GDTStoredEvent *)event {
  dispatch_async(_queue, ^{
    if (event.qosTier == GDTEventQoSWifiOnly) {
      [self.wifiOnlyEvents addObject:event];
    } else {
      [self.nonWifiEvents addObject:event];
    }
  });
}

- (GDTUploadPackage *)uploadPackageWithConditions:(GDTUploadConditions)conditions {
  __block GDTIntegrationTestUploadPackage *uploadPackage =
      [[GDTIntegrationTestUploadPackage alloc] initWithTarget:kGDTIntegrationTestTarget];
  dispatch_sync(_queue, ^{
    if ((conditions & GDTUploadConditionWifiData) == GDTUploadConditionWifiData) {
      uploadPackage.events = [self.wifiOnlyEvents setByAddingObjectsFromSet:self.nonWifiEvents];
    } else {
      uploadPackage.events = self.nonWifiEvents;
    }
  });
  return uploadPackage;
}

- (void)packageDelivered:(GDTUploadPackage *)package successful:(BOOL)successful {
  dispatch_async(_queue, ^{
    for (GDTStoredEvent *event in package.events) {
      [self.wifiOnlyEvents removeObject:event];
      [self.nonWifiEvents removeObject:event];
    }
  });
}

@end
