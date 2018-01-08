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

#import "Firestore/Source/Local/FSTLevelDB.h"

#include <leveldb/db.h>

#import "FIRFirestoreErrors.h"
#import "Firestore/Source/Core/FSTDatabaseInfo.h"
#import "Firestore/Source/Local/FSTLevelDBMutationQueue.h"
#import "Firestore/Source/Local/FSTLevelDBQueryCache.h"
#import "Firestore/Source/Local/FSTLevelDBRemoteDocumentCache.h"
#import "Firestore/Source/Local/FSTWriteGroup.h"
#import "Firestore/Source/Local/FSTWriteGroupTracker.h"
#import "Firestore/Source/Model/FSTDatabaseID.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTLogger.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kReservedPathComponent = @"firestore";

using leveldb::DB;
using leveldb::Options;
using leveldb::Status;
using leveldb::WriteOptions;

@interface FSTLevelDB ()

@property(nonatomic, copy) NSString *directory;
@property(nonatomic, strong) FSTWriteGroupTracker *writeGroupTracker;
@property(nonatomic, assign, getter=isStarted) BOOL started;
@property(nonatomic, strong, readonly) FSTLocalSerializer *serializer;

@end

@implementation FSTLevelDB

- (instancetype)initWithDirectory:(NSString *)directory
                       serializer:(FSTLocalSerializer *)serializer {
  if (self = [super init]) {
    _directory = [directory copy];
    _writeGroupTracker = [FSTWriteGroupTracker tracker];
    _serializer = serializer;
  }
  return self;
}

+ (NSString *)documentsDirectory {
#if TARGET_OS_IPHONE
  NSArray<NSString *> *directories =
      NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  return [directories[0] stringByAppendingPathComponent:kReservedPathComponent];

#elif TARGET_OS_MAC
  NSString *dotPrefixed = [@"." stringByAppendingString:kReservedPathComponent];
  return [NSHomeDirectory() stringByAppendingPathComponent:dotPrefixed];

#else
#error "local storage on tvOS"
// TODO(mcg): Writing to NSDocumentsDirectory on tvOS will fail; we need to write to Caches
// https://developer.apple.com/library/content/documentation/General/Conceptual/AppleTV_PG/

#endif
}

+ (NSString *)storageDirectoryForDatabaseInfo:(FSTDatabaseInfo *)databaseInfo
                           documentsDirectory:(NSString *)documentsDirectory {
  // Use two different path formats:
  //
  //   * persistenceKey / projectID . databaseID / name
  //   * persistenceKey / projectID / name
  //
  // projectIDs are DNS-compatible names and cannot contain dots so there's
  // no danger of collisions.
  NSString *directory = documentsDirectory;
  directory = [directory stringByAppendingPathComponent:databaseInfo.persistenceKey];

  NSString *segment = databaseInfo.databaseID.projectID;
  if (![databaseInfo.databaseID isDefaultDatabase]) {
    segment = [NSString stringWithFormat:@"%@.%@", segment, databaseInfo.databaseID.databaseID];
  }
  directory = [directory stringByAppendingPathComponent:segment];

  // Reserve one additional path component to allow multiple physical databases
  directory = [directory stringByAppendingPathComponent:@"main"];
  return directory;
}

#pragma mark - Startup

- (BOOL)start:(NSError **)error {
  FSTAssert(!self.isStarted, @"FSTLevelDB double-started!");
  self.started = YES;
  NSString *directory = self.directory;
  if (![self ensureDirectory:directory error:error]) {
    return NO;
  }

  DB *database = [self createDBWithDirectory:directory error:error];
  if (!database) {
    return NO;
  }

  _ptr.reset(database);
  return YES;
}

/** Creates the directory at @a directory and marks it as excluded from iCloud backup. */
- (BOOL)ensureDirectory:(NSString *)directory error:(NSError **)error {
  NSError *localError;
  NSFileManager *files = [NSFileManager defaultManager];

  BOOL success = [files createDirectoryAtPath:directory
                  withIntermediateDirectories:YES
                                   attributes:nil
                                        error:&localError];
  if (!success) {
    *error =
        [NSError errorWithDomain:FIRFirestoreErrorDomain
                            code:FIRFirestoreErrorCodeInternal
                        userInfo:@{
                          NSLocalizedDescriptionKey : @"Failed to create persistence directory",
                          NSUnderlyingErrorKey : localError
                        }];
    return NO;
  }

  NSURL *dirURL = [NSURL fileURLWithPath:directory];
  success = [dirURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&localError];
  if (!success) {
    *error = [NSError errorWithDomain:FIRFirestoreErrorDomain
                                 code:FIRFirestoreErrorCodeInternal
                             userInfo:@{
                               NSLocalizedDescriptionKey :
                                   @"Failed mark persistence directory as excluded from backups",
                               NSUnderlyingErrorKey : localError
                             }];
    return NO;
  }

  return YES;
}

/** Opens the database within the given directory. */
- (nullable DB *)createDBWithDirectory:(NSString *)directory error:(NSError **)error {
  Options options;
  options.create_if_missing = true;

  DB *database;
  Status status = DB::Open(options, [directory UTF8String], &database);
  if (!status.ok()) {
    if (error) {
      NSString *name = [directory lastPathComponent];
      *error =
          [FSTLevelDB errorWithStatus:status
                          description:@"Failed to create database %@ at path %@", name, directory];
    }
    return nullptr;
  }

  return database;
}

#pragma mark - Persistence Factory methods

- (id<FSTMutationQueue>)mutationQueueForUser:(FSTUser *)user {
  return [FSTLevelDBMutationQueue mutationQueueWithUser:user db:_ptr serializer:self.serializer];
}

- (id<FSTQueryCache>)queryCache {
  return [[FSTLevelDBQueryCache alloc] initWithDB:_ptr serializer:self.serializer];
}

- (id<FSTRemoteDocumentCache>)remoteDocumentCache {
  return [[FSTLevelDBRemoteDocumentCache alloc] initWithDB:_ptr serializer:self.serializer];
}

- (FSTWriteGroup *)startGroupWithAction:(NSString *)action {
  return [self.writeGroupTracker startGroupWithAction:action];
}

- (void)commitGroup:(FSTWriteGroup *)group {
  [self.writeGroupTracker endGroup:group];

  NSString *description = [group description];
  FSTLog(@"Committing %@", description);

  Status status = [group writeToDB:_ptr];
  if (!status.ok()) {
    FSTFail(@"%@ failed with status: %s, description: %@", group.action, status.ToString().c_str(),
            description);
  }
}

- (void)shutdown {
  FSTAssert(self.isStarted, @"FSTLevelDB shutdown without start!");
  self.started = NO;
  _ptr.reset();
}

#pragma mark - Error and Status

+ (nullable NSError *)errorWithStatus:(Status)status description:(NSString *)description, ... {
  if (status.ok()) {
    return nil;
  }

  va_list args;
  va_start(args, description);

  NSString *message = [[NSString alloc] initWithFormat:description arguments:args];
  NSString *reason = [self descriptionOfStatus:status];
  NSError *result = [NSError errorWithDomain:FIRFirestoreErrorDomain
                                        code:FIRFirestoreErrorCodeInternal
                                    userInfo:@{
                                      NSLocalizedDescriptionKey : message,
                                      NSLocalizedFailureReasonErrorKey : reason
                                    }];

  va_end(args);

  return result;
}

+ (NSString *)descriptionOfStatus:(Status)status {
  return [NSString stringWithCString:status.ToString().c_str() encoding:NSUTF8StringEncoding];
}

@end

NS_ASSUME_NONNULL_END
