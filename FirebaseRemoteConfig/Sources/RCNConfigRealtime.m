/*
 * Copyright 2022 Google LLC
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

#import <Foundation/Foundation.h>
#import "FirebaseRemoteConfig/Sources/RCNConfigRealtime.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"

@implementation FIRConfigUpdateListenerRegistration {
  RCNConfigRealtime *_realtimeClient;
  id completionHandler;
}

- (instancetype)initWithClient:(RCNConfigRealtime *)realtimeClient
             completionHandler:(id)completionHandler {
  self = [super init];
  if (self) {
    _realtimeClient = realtimeClient;
    completionHandler = completionHandler;
  }
  return self;
}

- (void)remove {
  [self->_realtimeClient removeConfigUpdateListener:completionHandler];
}

@end

@interface RCNConfigRealtime ()

@property(strong, atomic, nonnull) NSMutableSet<id> *listeners;
@property(strong, atomic, nonnull) dispatch_queue_t realtimeLockQueue;

@end

@implementation RCNConfigRealtime

- (instancetype)init {
  self = [super init];
  if (self) {
    _listeners = [NSMutableSet alloc];
    _realtimeLockQueue = [RCNConfigRealtime realtimeRemoteConfigSerialQueue];
  }

  return self;
}

/// Singleton instance of serial queue for queuing all incoming RC calls.
+ (dispatch_queue_t)realtimeRemoteConfigSerialQueue {
  static dispatch_once_t onceToken;
  static dispatch_queue_t realtimeRemoteConfigQueue;
  dispatch_once(&onceToken, ^{
    realtimeRemoteConfigQueue =
        dispatch_queue_create(RCNRemoteConfigQueueLabel, DISPATCH_QUEUE_SERIAL);
  });
  return realtimeRemoteConfigQueue;
}

- (void)beginRealtimeStream {
}

- (void)pauseRealtimeStream {
}

- (FIRConfigUpdateListenerRegistration *)addConfigUpdateListener:
    (void (^_Nonnull)(NSError *_Nullable error))listener {
  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    [strongSelf->_listeners addObject:listener];
    [strongSelf beginRealtimeStream];
  });

  return [[FIRConfigUpdateListenerRegistration alloc] initWithClient:self
                                                   completionHandler:listener];
}

- (void)removeConfigUpdateListener:(void (^_Nonnull)(NSError *_Nullable error))listener {
  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    [strongSelf->_listeners removeObject:listener];
    if (strongSelf->_listeners.count == 0) {
      [strongSelf pauseRealtimeStream];
    }
  });
}

@end
