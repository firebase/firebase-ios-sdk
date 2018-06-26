// Copyright 2017 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FIRMutableDictionary.h"
#import <GoogleUtilities/GULMutableDictionary.h>

@implementation FIRMutableDictionary {
  // Wrap GULMutableDictionary until FIRMutableDictionary can be eliminated in dependencies
  GULMutableDictionary *_gulMutableDictionary;
}

- (instancetype)init {
  self = [super init];

  if (self) {
    _gulMutableDictionary = [[GULMutableDictionary alloc] init];
  }

  return self;
}

- (NSString *)description {
  return [_gulMutableDictionary description];
}

- (id)objectForKey:(id)key {
  return [_gulMutableDictionary objectForKey:key];
}

- (void)removeObjectForKey:(id)key {
  [_gulMutableDictionary removeObjectForKey:key];
}

- (void)removeAllObjects {
  [_gulMutableDictionary removeAllObjects];
}

- (NSUInteger)count {
  return [_gulMutableDictionary count];
}

- (id)objectForKeyedSubscript:(id<NSCopying>)key {
  // The method this calls is already synchronized.
  return [_gulMutableDictionary objectForKeyedSubscript:key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key {
  // The method this calls is already synchronized.
  [_gulMutableDictionary setObject:obj forKeyedSubscript:key];
}

- (NSDictionary *)dictionary {
  return [_gulMutableDictionary dictionary];
}

@end
