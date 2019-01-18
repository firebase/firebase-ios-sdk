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

#import "GDLRegistrar.h"

#import "GDLRegistrar_Private.h"

@implementation GDLRegistrar {
  /** Backing ivar for logTargetToUploader property. */
  NSMutableDictionary<NSNumber *, id<GDLLogUploader>> *_logTargetToUploader;

  /** Backing ivar for logTargetToPrioritizer property. */
  NSMutableDictionary<NSNumber *, id<GDLLogPrioritizer>> *_logTargetToPrioritizer;
}

+ (instancetype)sharedInstance {
  static GDLRegistrar *sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[GDLRegistrar alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _registrarQueue = dispatch_queue_create("com.google.GDLRegistrar", DISPATCH_QUEUE_CONCURRENT);
    _logTargetToPrioritizer = [[NSMutableDictionary alloc] init];
    _logTargetToUploader = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)registerUploader:(id<GDLLogUploader>)backend logTarget:(GDLLogTarget)logTarget {
  __weak GDLRegistrar *weakSelf = self;
  dispatch_barrier_async(_registrarQueue, ^{
    GDLRegistrar *strongSelf = weakSelf;
    if (strongSelf) {
      strongSelf->_logTargetToUploader[@(logTarget)] = backend;
    }
  });
}

- (void)registerPrioritizer:(id<GDLLogPrioritizer>)prioritizer logTarget:(GDLLogTarget)logTarget {
  __weak GDLRegistrar *weakSelf = self;
  dispatch_barrier_async(_registrarQueue, ^{
    GDLRegistrar *strongSelf = weakSelf;
    if (strongSelf) {
      strongSelf->_logTargetToPrioritizer[@(logTarget)] = prioritizer;
    }
  });
}

- (NSMutableDictionary<NSNumber *, id<GDLLogUploader>> *)logTargetToUploader {
  __block NSMutableDictionary<NSNumber *, id<GDLLogUploader>> *logTargetToUploader;
  __weak GDLRegistrar *weakSelf = self;
  dispatch_sync(_registrarQueue, ^{
    GDLRegistrar *strongSelf = weakSelf;
    if (strongSelf) {
      logTargetToUploader = strongSelf->_logTargetToUploader;
    }
  });
  return logTargetToUploader;
}

- (NSMutableDictionary<NSNumber *, id<GDLLogPrioritizer>> *)logTargetToPrioritizer {
  __block NSMutableDictionary<NSNumber *, id<GDLLogPrioritizer>> *logTargetToPrioritizer;
  __weak GDLRegistrar *weakSelf = self;
  dispatch_sync(_registrarQueue, ^{
    GDLRegistrar *strongSelf = weakSelf;
    if (strongSelf) {
      logTargetToPrioritizer = strongSelf->_logTargetToPrioritizer;
    }
  });
  return logTargetToPrioritizer;
}

@end
