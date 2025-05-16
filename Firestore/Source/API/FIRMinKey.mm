/*
 * Copyright 2025 Google LLC
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

#include "Firestore/Source/Public/FirebaseFirestore/FIRMinKey.h"

@implementation FIRMinKey
static FIRMinKey *sharedInstance = nil;
static dispatch_once_t onceToken;

+ (FIRMinKey *)shared {
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  return self;
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  return self;
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }
  if (object == nil || [self class] != [object class]) {
    return NO;
  }
  return YES;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FIRMinKey>"];
}

@end
