/*
 * Copyright 2017 Google
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

#import "Firestore/Source/Remote/FSTWatchChange.h"

#include <utility>

#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Remote/FSTExistenceFilter.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::TargetId;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTWatchChange
@end

@implementation FSTDocumentWatchChange {
  DocumentKey _documentKey;
}

- (instancetype)initWithUpdatedTargetIDs:(NSArray<NSNumber *> *)updatedTargetIDs
                        removedTargetIDs:(NSArray<NSNumber *> *)removedTargetIDs
                             documentKey:(DocumentKey)documentKey
                                document:(nullable FSTMaybeDocument *)document {
  self = [super init];
  if (self) {
    _updatedTargetIDs = updatedTargetIDs;
    _removedTargetIDs = removedTargetIDs;
    _documentKey = std::move(documentKey);
    _document = document;
  }
  return self;
}

- (const firebase::firestore::model::DocumentKey &)documentKey {
  return _documentKey;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isMemberOfClass:[FSTDocumentWatchChange class]]) {
    return NO;
  }

  FSTDocumentWatchChange *otherChange = (FSTDocumentWatchChange *)other;
  return [_updatedTargetIDs isEqual:otherChange.updatedTargetIDs] &&
         [_removedTargetIDs isEqual:otherChange.removedTargetIDs] &&
         _documentKey == otherChange.documentKey &&
         (_document == otherChange.document || [_document isEqual:otherChange.document]);
}

- (NSUInteger)hash {
  NSUInteger hash = self.updatedTargetIDs.hash;
  hash = hash * 31 + self.removedTargetIDs.hash;
  hash = hash * 31 + self.documentKey.Hash();
  hash = hash * 31 + self.document.hash;
  return hash;
}

@end

@interface FSTExistenceFilterWatchChange ()

- (instancetype)initWithFilter:(FSTExistenceFilter *)filter
                      targetID:(TargetId)targetID NS_DESIGNATED_INITIALIZER;

@end

@implementation FSTExistenceFilterWatchChange

+ (instancetype)changeWithFilter:(FSTExistenceFilter *)filter targetID:(TargetId)targetID {
  return [[FSTExistenceFilterWatchChange alloc] initWithFilter:filter targetID:targetID];
}

- (instancetype)initWithFilter:(FSTExistenceFilter *)filter targetID:(TargetId)targetID {
  self = [super init];
  if (self) {
    _filter = filter;
    _targetID = targetID;
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isMemberOfClass:[FSTExistenceFilterWatchChange class]]) {
    return NO;
  }

  FSTExistenceFilterWatchChange *otherChange = (FSTExistenceFilterWatchChange *)other;
  return [_filter isEqual:otherChange->_filter] && _targetID == otherChange->_targetID;
}

- (NSUInteger)hash {
  return self.filter.hash;
}

@end

@implementation FSTWatchTargetChange

- (instancetype)initWithState:(FSTWatchTargetChangeState)state
                    targetIDs:(NSArray<NSNumber *> *)targetIDs
                  resumeToken:(NSData *)resumeToken
                        cause:(nullable NSError *)cause {
  self = [super init];
  if (self) {
    _state = state;
    _targetIDs = targetIDs;
    _resumeToken = [resumeToken copy];
    _cause = cause;
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isMemberOfClass:[FSTWatchTargetChange class]]) {
    return NO;
  }

  FSTWatchTargetChange *otherChange = (FSTWatchTargetChange *)other;
  return _state == otherChange->_state && [_targetIDs isEqual:otherChange->_targetIDs] &&
         [_resumeToken isEqual:otherChange->_resumeToken] &&
         (_cause == otherChange->_cause || [_cause isEqual:otherChange->_cause]);
}

- (NSUInteger)hash {
  NSUInteger hash = (NSUInteger)self.state;

  hash = hash * 31 + self.targetIDs.hash;
  hash = hash * 31 + self.resumeToken.hash;
  hash = hash * 31 + self.cause.hash;
  return hash;
}

@end

NS_ASSUME_NONNULL_END
