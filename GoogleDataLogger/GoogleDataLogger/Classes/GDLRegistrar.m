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

@implementation GDLRegistrar

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
    _logTargetToPrioritizer = [[NSMutableDictionary alloc] init];
    _logTargetToBackend = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)registerBackend:(id<GDLLogBackend>)backend forLogTarget:(NSInteger)logTarget {
  self.logTargetToBackend[@(logTarget)] = backend;
}

- (void)registerLogPrioritizer:(id<GDLLogPrioritizer>)prioritizer
                  forLogTarget:(NSInteger)logTarget {
  self.logTargetToPrioritizer[@(logTarget)] = prioritizer;
}

@end
