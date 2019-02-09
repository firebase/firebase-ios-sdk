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

#import "GDTRegistrar.h"

#import "GDTRegistrar_Private.h"

@implementation GDTRegistrar {
  /** Backing ivar for logTargetToUploader property. */
  NSMutableDictionary<NSNumber *, id<GDTLogUploader>> *_logTargetToUploader;

  /** Backing ivar for logTargetToPrioritizer property. */
  NSMutableDictionary<NSNumber *, id<GDTLogPrioritizer>> *_logTargetToPrioritizer;
}

+ (instancetype)sharedInstance {
  static GDTRegistrar *sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[GDTRegistrar alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _registrarQueue = dispatch_queue_create("com.google.GDTRegistrar", DISPATCH_QUEUE_CONCURRENT);
    _logTargetToPrioritizer = [[NSMutableDictionary alloc] init];
    _logTargetToUploader = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)registerUploader:(id<GDTLogUploader>)backend logTarget:(GDTLogTarget)logTarget {
  __weak GDTRegistrar *weakSelf = self;
  dispatch_barrier_async(_registrarQueue, ^{
    GDTRegistrar *strongSelf = weakSelf;
    if (strongSelf) {
      strongSelf->_logTargetToUploader[@(logTarget)] = backend;
    }
  });
}

- (void)registerPrioritizer:(id<GDTLogPrioritizer>)prioritizer logTarget:(GDTLogTarget)logTarget {
  __weak GDTRegistrar *weakSelf = self;
  dispatch_barrier_async(_registrarQueue, ^{
    GDTRegistrar *strongSelf = weakSelf;
    if (strongSelf) {
      strongSelf->_logTargetToPrioritizer[@(logTarget)] = prioritizer;
    }
  });
}

- (NSMutableDictionary<NSNumber *, id<GDTLogUploader>> *)logTargetToUploader {
  __block NSMutableDictionary<NSNumber *, id<GDTLogUploader>> *logTargetToUploader;
  __weak GDTRegistrar *weakSelf = self;
  dispatch_sync(_registrarQueue, ^{
    GDTRegistrar *strongSelf = weakSelf;
    if (strongSelf) {
      logTargetToUploader = strongSelf->_logTargetToUploader;
    }
  });
  return logTargetToUploader;
}

- (NSMutableDictionary<NSNumber *, id<GDTLogPrioritizer>> *)logTargetToPrioritizer {
  __block NSMutableDictionary<NSNumber *, id<GDTLogPrioritizer>> *logTargetToPrioritizer;
  __weak GDTRegistrar *weakSelf = self;
  dispatch_sync(_registrarQueue, ^{
    GDTRegistrar *strongSelf = weakSelf;
    if (strongSelf) {
      logTargetToPrioritizer = strongSelf->_logTargetToPrioritizer;
    }
  });
  return logTargetToPrioritizer;
}

@end
