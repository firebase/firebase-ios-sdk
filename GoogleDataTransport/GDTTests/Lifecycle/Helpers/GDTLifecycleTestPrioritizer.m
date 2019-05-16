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

#import "GDTTests/Lifecycle/Helpers/GDTLifecycleTestPrioritizer.h"

#import <GoogleDataTransport/GDTRegistrar.h>

@interface GDTLifecycleTestPrioritizer ()

/** Events that are only supposed to be uploaded whilst on wifi. */
@property(nonatomic) NSMutableSet<GDTStoredEvent *> *events;

/** The queue on which this prioritizer operates. */
@property(nonatomic) dispatch_queue_t queue;

@end

@implementation GDTLifecycleTestPrioritizer

- (instancetype)init {
  self = [super init];
  if (self) {
    _queue = dispatch_queue_create("com.google.GDTLifecycleTestPrioritizer", DISPATCH_QUEUE_SERIAL);
    _events = [[NSMutableSet alloc] init];
    [[GDTRegistrar sharedInstance] registerPrioritizer:self target:kGDTTargetTest];
  }
  return self;
}

- (void)prioritizeEvent:(GDTStoredEvent *)event {
  dispatch_async(_queue, ^{
    [self.events addObject:event];
  });
}

- (GDTUploadPackage *)uploadPackageWithConditions:(GDTUploadConditions)conditions {
  __block GDTUploadPackage *uploadPackage =
      [[GDTUploadPackage alloc] initWithTarget:kGDTTargetTest];
  dispatch_sync(_queue, ^{
    uploadPackage.events = self.events;
  });
  return uploadPackage;
}

- (void)packageDelivered:(GDTUploadPackage *)package successful:(BOOL)successful {
  dispatch_async(_queue, ^{
    for (GDTStoredEvent *event in package.events) {
      [self.events removeObject:event];
    }
  });
}

@end
