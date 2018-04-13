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

#ifdef __cplusplus
#include <memory>

#include "Firestore/Source/Local/StringView.h"

namespace leveldb {
class DB;
class Status;
}

#endif

NS_ASSUME_NONNULL_BEGIN

@class GPBMessage;

/**
 * A group of writes that will be applied together atomically to persistent storage.
 *
 * This class is usable by both Objective-C and Objective-C++ clients. Objective-C clients are able
 * to create a new group and commit it. Objective-C++ clients can additionally add to the group
 * using deleteKey: and putKey:value:.
 *
 * Note that this is a write "group" even though the underlying LevelDB concept is a write "batch"
 * because Firestore already has a concept of mutation batches, which are user-specified groups of
 * changes. This means that an FSTWriteGroup may contain the application of multiple user-specified
 * mutation batches.
 */
@interface FSTWriteGroup : NSObject

/**
 * Creates a new, empty write group.
 *
 * @param action A description of the action performed by this group, used for logging.
 */
+ (instancetype)groupWithAction:(NSString *)action;

- (instancetype)init __attribute__((unavailable("Use a static constructor instead")));

/** The action description assigned to this write group. */
@property(nonatomic, copy, readonly) NSString *action;

/** Returns YES if the write group has no messages in it. */
- (BOOL)isEmpty;

#ifdef __cplusplus

/**
 * Marks the given key for deletion.
 *
 * @param key The LevelDB key of the row to delete
 */
- (void)removeMessageForKey:(Firestore::StringView)key;

/**
 * Sets the row identified by the given key to the value of the given protocol buffer message.
 *
 * @param key The LevelDB Key of the row to set.
 * @param message The protocol buffer message whose serialized contents should be used for the
 *     value associated with the key.
 */
- (void)setMessage:(GPBMessage *)message forKey:(Firestore::StringView)key;

/**
 * Sets the row identified by the given key to the value of the given data bytes.
 *
 * @param key The LevelDB Key of the row to set.
 * @param data The exact value to be associated with the key.
 */
- (void)setData:(Firestore::StringView)data forKey:(Firestore::StringView)key;

/** Writes the contents to the given LevelDB. */
- (leveldb::Status)writeToDB:(std::shared_ptr<leveldb::DB>)db;

#endif

@end

NS_ASSUME_NONNULL_END
