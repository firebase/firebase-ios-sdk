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

#import "GoogleDataTransport/GDTCORTests/Common/Fakes/GDTCORTransportFake.h"

@interface GDTCORTransportFake ()

/**
 * Internal array that stores all log events that have been logged.
 * All access to this array is protected by @synchronized.
 */
@property(nonatomic, readonly) NSMutableArray<GDTCOREvent *> *events;

@end

@implementation GDTCORTransportFake

- (instancetype)initWithMappingID:(NSString *)mappingID
                     transformers:(nullable NSArray<id<GDTCOREventTransformer>> *)transformers
                           target:(GDTCORTarget)target {
  self = [super initWithMappingID:mappingID transformers:transformers target:target];

  if (self) {
    _events = [NSMutableArray array];
  }
  return self;
}

- (void)sendDataEvent:(GDTCOREvent *)event {
  @synchronized(self.events) {
    [self.events addObject:event];
  }
}

- (NSArray<GDTCOREvent *> *)logEvents {
  @synchronized(self.events) {
    return [self.events copy];
  }
}

- (void)reset {
  @synchronized(self.events) {
    [self.events removeAllObjects];
  }
}

@end
