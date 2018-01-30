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

#import "Firestore/Source/Local/FSTLevelDBUtil.h"

#import <leveldb/db.h>

#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"
#import "Firestore/Source/Util/FSTAssert.h"

NS_ASSUME_NONNULL_BEGIN

using leveldb::DB;
using leveldb::ReadOptions;
using leveldb::Slice;
using leveldb::Status;
using leveldb::WriteOptions;

@implementation FSTLevelDBUtil

+ (const ReadOptions)standardReadOptions {
  ReadOptions options;
  options.verify_checksums = true;
  return options;
}

+ (nullable FSTPBTargetGlobal *)readTargetMetadataFromDB:(std::shared_ptr<DB>)db {
  std::string key = [FSTLevelDBTargetGlobalKey key];
  std::string value;
  Status status = db->Get([FSTLevelDBUtil standardReadOptions], key, &value);
  if (status.IsNotFound()) {
    return nil;
  } else if (!status.ok()) {
    FSTFail(@"metadataForKey: failed loading key %s with status: %s", key.c_str(),
            status.ToString().c_str());
  }

  NSData *data =
      [[NSData alloc] initWithBytesNoCopy:(void *)value.data() length:value.size() freeWhenDone:NO];

  NSError *error;
  FSTPBTargetGlobal *proto = [FSTPBTargetGlobal parseFromData:data error:&error];
  if (!proto) {
    FSTFail(@"FSTPBTargetGlobal failed to parse: %@", error);
  }

  return proto;
}

@end

NS_ASSUME_NONNULL_END
