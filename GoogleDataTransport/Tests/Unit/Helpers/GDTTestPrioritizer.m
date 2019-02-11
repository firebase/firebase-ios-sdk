/*
 * Copyright 2018 Google
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

#import "GDTTestPrioritizer.h"

@implementation GDTTestPrioritizer

- (instancetype)init {
  self = [super init];
  if (self) {
    _eventsForNextUploadFake = [[NSSet alloc] init];
  }
  return self;
}

- (NSSet<NSNumber *> *)eventsToUploadGivenConditions:(GDTUploadConditions)conditions {
  if (_eventsForNextUploadBlock) {
    _eventsForNextUploadBlock();
  }
  return _eventsForNextUploadFake;
}

- (void)prioritizeEvent:(GDTEvent *)event {
  if (_prioritizeEventBlock) {
    _prioritizeEventBlock(event);
  }
}

- (void)unprioritizeEvent:(nonnull NSNumber *)eventHash {
}

@end
