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

@class FSTLevelDB;
@class FSTMemoryPersistence;

NS_ASSUME_NONNULL_BEGIN

@interface FSTPersistenceTestHelpers : NSObject

/**
 * @return The directory where a leveldb instance can store data files. Any files that existed
 * there will be deleted first.
 */
+ (NSString *)levelDBDir;

/**
 * Creates and starts a new FSTLevelDB instance for testing, destroying any previous contents
 * if they existed.
 *
 * Note that in order to avoid generating a bunch of garbage on the filesystem, the path of the
 * database is reused. This prevents concurrent running of tests using this database. We may
 * need to revisit this if we want to parallelize the tests.
 */
+ (FSTLevelDB *)levelDBPersistence;

/** Creates and starts a new FSTMemoryPersistence instance for testing. */
+ (FSTMemoryPersistence *)memoryPersistence;
@end

NS_ASSUME_NONNULL_END
