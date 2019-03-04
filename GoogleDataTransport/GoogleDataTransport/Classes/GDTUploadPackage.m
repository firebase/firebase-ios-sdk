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

#import <GoogleDataTransport/GDTUploadPackage.h>

#import "GDTUploadPackage_Private.h"
#import "GDTStorage_Private.h"

@implementation GDTUploadPackage

- (instancetype)init {
  self = [super init];
  if (self) {
    _storage = [GDTStorage sharedInstance];
  }
  return self;
}

- (instancetype)copy {
  GDTUploadPackage *newPackage = [[GDTUploadPackage alloc] init];
  newPackage->_eventHashes = _eventHashes;
  return newPackage;
}

- (NSUInteger)hash {
  return [_eventHashes hash];
}

- (BOOL)isEqual:(id)object {
  return [self hash] == [object hash];
}

- (void)setEventHashes:(NSSet<NSNumber *> *)eventHashes {
  if (eventHashes != _eventHashes) {
    _eventHashes = [eventHashes copy];
  }
}

- (NSDictionary<NSNumber *, NSURL *> *)eventHashesToFiles {
  return [_storage eventHashesToFiles:_eventHashes];
}

- (void)setStorage:(GDTStorage *)storage {
  if (storage != _storage) {
    _storage = storage;
  }
}

@end
