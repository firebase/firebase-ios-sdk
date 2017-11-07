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

#import "FSTWriteGroup.h"

#import <Protobuf/GPBProtocolBuffers.h>
#include <leveldb/db.h>
#include <leveldb/write_batch.h>

#import "FSTAssert.h"
#import "FSTLevelDBKey.h"

#include "ordered_code.h"

using Firestore::OrderedCode;
using Firestore::StringView;
using leveldb::DB;
using leveldb::Slice;
using leveldb::Status;
using leveldb::WriteBatch;
using leveldb::WriteOptions;

NS_ASSUME_NONNULL_BEGIN

namespace Firestore {

/**
 * A WriteBatch::Handler implementation that extracts batch details from a leveldb::WriteBatch.
 * This is used for describing a write batch primarily in log messages after a failure.
 */
class BatchDescription : public WriteBatch::Handler {
 public:
  BatchDescription() : ops_(0), size_(0), message_([NSMutableString string]) {
  }
  virtual ~BatchDescription();
  virtual void Put(const Slice &key, const Slice &value);
  virtual void Delete(const Slice &key);

  // Converts the batch to a printable string description of it
  NSString *ToString() const {
    return [NSString
        stringWithFormat:@"%d changes (%lu bytes):%@", ops_, (unsigned long)size_, message_];
  }

  // Disallow copies and moves
  BatchDescription(const BatchDescription &) = delete;
  BatchDescription &operator=(const BatchDescription &) = delete;
  BatchDescription(BatchDescription &&) = delete;
  BatchDescription &operator=(BatchDescription &&) = delete;

 private:
  int ops_;
  size_t size_;
  NSMutableString *message_;
};

BatchDescription::~BatchDescription() {
}

void BatchDescription::Put(const Slice &key, const Slice &value) {
  ops_ += 1;
  size_ += value.size();

  [message_ appendFormat:@"\n  - Put %@ (%lu bytes)", [FSTLevelDBKey descriptionForKey:key],
                         (unsigned long)value.size()];
}

void BatchDescription::Delete(const Slice &key) {
  ops_ += 1;

  [message_ appendFormat:@"\n  - Delete %@", [FSTLevelDBKey descriptionForKey:key]];
}

}  // namespace Firestore

@interface FSTWriteGroup ()
- (instancetype)initWithAction:(NSString *)action NS_DESIGNATED_INITIALIZER;
@end

@implementation FSTWriteGroup {
  int _changes;
  WriteBatch _contents;
}

+ (instancetype)groupWithAction:(NSString *)action {
  return [[FSTWriteGroup alloc] initWithAction:action];
}

- (instancetype)initWithAction:(NSString *)action {
  if (self = [super init]) {
    _action = action;
  }
  return self;
}

- (NSString *)description {
  Firestore::BatchDescription description;
  Status status = _contents.Iterate(&description);
  if (!status.ok()) {
    FSTFail(@"Iterate over write batch should not fail");
  }
  return [NSString
      stringWithFormat:@"<FSTWriteGroup for %@: %@>", self.action, description.ToString()];
}

- (void)removeMessageForKey:(StringView)key {
  _contents.Delete(key);
  _changes += 1;
}

- (void)setMessage:(GPBMessage *)message forKey:(StringView)key {
  NSData *data = [message data];
  Slice value((const char *)data.bytes, data.length);

  _contents.Put(key, value);
  _changes += 1;
}

- (void)setData:(StringView)data forKey:(StringView)key {
  _contents.Put(key, data);
  _changes += 1;
}

- (leveldb::Status)writeToDB:(std::shared_ptr<leveldb::DB>)db {
  return db->Write(leveldb::WriteOptions(), &_contents);
}

- (BOOL)isEmpty {
  return _changes == 0;
}

@end

NS_ASSUME_NONNULL_END
