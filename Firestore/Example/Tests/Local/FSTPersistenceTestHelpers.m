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

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"

#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Local/FSTMemoryPersistence.h"
#import "Firestore/Source/Model/FSTDatabaseID.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FSTPersistenceTestHelpers

+ (NSString *)levelDBDir {
  NSError *error;
  NSFileManager *files = [NSFileManager defaultManager];
  NSString *dir =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"FSTPersistenceTestHelpers"];
  if ([files fileExistsAtPath:dir]) {
    // Delete the directory first to ensure isolation between runs.
    BOOL success = [files removeItemAtPath:dir error:&error];
    if (!success) {
      [NSException raise:NSInternalInconsistencyException
                  format:@"Failed to clean up leveldb path %@: %@", dir, error];
    }
  }
  return dir;
}

+ (FSTLevelDB *)levelDBPersistence {
  NSString *dir = [self levelDBDir];

  FSTDatabaseID *databaseID = [FSTDatabaseID databaseIDWithProject:@"p" database:@"d"];
  FSTSerializerBeta *remoteSerializer = [[FSTSerializerBeta alloc] initWithDatabaseID:databaseID];
  FSTLocalSerializer *serializer =
      [[FSTLocalSerializer alloc] initWithRemoteSerializer:remoteSerializer];
  FSTLevelDB *db = [[FSTLevelDB alloc] initWithDirectory:dir serializer:serializer];
  NSError *error;
  BOOL success = [db start:&error];
  if (!success) {
    [NSException raise:NSInternalInconsistencyException
                format:@"Failed to create leveldb path %@: %@", dir, error];
  }

  return db;
}

+ (FSTMemoryPersistence *)memoryPersistence {
  NSError *error;
  FSTMemoryPersistence *persistence = [FSTMemoryPersistence persistence];
  BOOL success = [persistence start:&error];
  if (!success) {
    [NSException raise:NSInternalInconsistencyException
                format:@"Failed to start memory persistence: %@", error];
  }

  return persistence;
}

@end

NS_ASSUME_NONNULL_END
