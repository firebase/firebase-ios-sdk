/*
 * Copyright 2020 Google LLC
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

#import "GDTCORLibrary/Private/GDTCORFlatFileStorageIterator.h"

#import <GoogleDataTransport/GDTCORConsoleLogger.h>
#import <GoogleDataTransport/GDTCOREvent.h>

@implementation GDTCORFlatFileStorageIterator {
  /** The current eventFiles array index, incremented in -nextEvent. */
  NSInteger _currentIndex;
}

- (instancetype)initWithTarget:(GDTCORTarget)target queue:(dispatch_queue_t)queue {
  self = [super init];
  if (self) {
    _queue = queue;
    _target = target;
  }
  return self;
}

- (nullable GDTCOREvent *)nextEvent {
  if (_currentIndex == -1) {
    return nil;
  }
  if (!_eventFiles) {
    GDTCORLogDebug(@"%@", @"eventFiles property not set, so -nextEvent will be nil.");
    return nil;
  }
  dispatch_queue_t queue = _queue;
  if (!queue) {
    GDTCORLogDebug(@"%@", @"iterator queue was nil, so -nextEvent will be nil.");
    return nil;
  }
  __block GDTCOREvent *nextEvent;
  dispatch_sync(queue, ^{
    NSData *data = [NSData dataWithContentsOfFile:self->_eventFiles[_currentIndex]];
    if (data) {
      NSError *error;
      nextEvent = (GDTCOREvent *)GDTCORDecodeArchive([GDTCOREvent class], nil, data, &error);
      if (error || nextEvent == nil) {
        GDTCORLogDebug(@"Unarchiving an event failed: %@", error);
        nextEvent = nil;
        self->_currentIndex = -1;
        return;
      }
    }
  });
  return nextEvent;
}

@end
