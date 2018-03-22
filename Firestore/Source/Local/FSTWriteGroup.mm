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

#import "Firestore/Source/Local/FSTWriteGroup.h"

#include <leveldb/write_batch.h>

#import "Firestore/Source/Local/FSTLevelDBKey.h"
#import "Firestore/Source/Util/FSTAssert.h"

using firebase::firestore::local::LevelDbTransaction;
using Firestore::StringView;
using leveldb::DB;
using leveldb::Slice;
using leveldb::Status;
using leveldb::WriteBatch;
using leveldb::WriteOptions;

NS_ASSUME_NONNULL_BEGIN

@interface FSTWriteGroup ()
- (instancetype)initWithAction:(NSString *)action NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithAction:(NSString *)action transaction:(LevelDbTransaction *)transaction;
@end

@implementation FSTWriteGroup {
  int _changes;
}

+ (instancetype)groupWithAction:(NSString *)action {
  return [[FSTWriteGroup alloc] initWithAction:action];
}

+ (instancetype)groupWithAction:(NSString *)action
                    transaction:(firebase::firestore::local::LevelDbTransaction *)transaction {
  return [[FSTWriteGroup alloc] initWithAction:action transaction:transaction];
}

- (instancetype)initWithAction:(NSString *)action {
  if (self = [super init]) {
    _action = action;
    _transaction = nullptr;
  }
  return self;
}

- (instancetype)initWithAction:(NSString *)action transaction:(LevelDbTransaction *)transaction {
  if (self = [self initWithAction:action]) {
    _transaction = transaction;
  }
  return self;
}

- (void)removeMessageForKey:(StringView)key {
  FSTAssert(_transaction != nullptr, @"Using group without a transaction");
  Slice keySlice = key;
  _transaction->Delete(keySlice.ToString());
  _changes += 1;
}

- (void)setMessage:(GPBMessage *)message forKey:(StringView)key {
  FSTAssert(_transaction != nullptr, @"Using group without a transaction");
  Slice keySlice = key;
  _transaction->Put(keySlice.ToString(), message);
  _changes += 1;
}

- (void)setData:(StringView)data forKey:(StringView)key {
  FSTAssert(_transaction != nullptr, @"Using group without a transaction");
  Slice keySlice = key;
  Slice valueSlice = data;
  std::string value = valueSlice.ToString();
  _transaction->Put(keySlice.ToString(), value);
  _changes += 1;
}

- (BOOL)isEmpty {
  return _changes == 0;
}

@end

NS_ASSUME_NONNULL_END
