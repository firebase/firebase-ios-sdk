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

#import <Foundation/Foundation.h>

#import "FSTRemoteDocumentCache.h"

#ifdef __cplusplus
#include <memory>

namespace leveldb {
class DB;
}
#endif

@class FSTLocalSerializer;

NS_ASSUME_NONNULL_BEGIN

/** Cached Remote Documents backed by leveldb. */
@interface FSTLevelDBRemoteDocumentCache : NSObject <FSTRemoteDocumentCache>

- (instancetype)init NS_UNAVAILABLE;

#ifdef __cplusplus
/**
 * Creates a new remote documents cache in the given leveldb.
 *
 * @param db The leveldb in which to create the cache.
 */
- (instancetype)initWithDB:(std::shared_ptr<leveldb::DB>)db
                serializer:(FSTLocalSerializer *)serializer NS_DESIGNATED_INITIALIZER;
#endif

@end

NS_ASSUME_NONNULL_END
