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

#import <Foundation/Foundation.h>
#include <memory>

@class FSTPBTargetGlobal;

namespace leveldb {
class DB;
struct ReadOptions;
}

NS_ASSUME_NONNULL_BEGIN

@interface FSTLevelDBUtil : NSObject

+ (const leveldb::ReadOptions)standardReadOptions;

+ (nullable FSTPBTargetGlobal *)readTargetMetadataFromDB:(std::shared_ptr<leveldb::DB>)db;

@end

NS_ASSUME_NONNULL_END
