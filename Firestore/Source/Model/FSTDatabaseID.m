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

#import "Firestore/Source/Model/FSTDatabaseID.h"

#import "Firestore/Source/Util/FSTAssert.h"

NS_ASSUME_NONNULL_BEGIN

/** The default name for "unset" database ID in resource names. */
NSString *const kDefaultDatabaseID = @"(default)";

#pragma mark - FSTDatabaseID

@implementation FSTDatabaseID

+ (instancetype)databaseIDWithProject:(NSString *)projectID database:(NSString *)databaseID {
  return [[FSTDatabaseID alloc] initWithProject:projectID database:databaseID];
}

/**
 * Designated initializer.
 *
 * @param projectID The project for the database.
 * @param databaseID The database in the datastore.
 */
- (instancetype)initWithProject:(NSString *)projectID database:(NSString *)databaseID {
  if (self = [super init]) {
    FSTAssert(databaseID, @"databaseID cannot be nil");
    _projectID = [projectID copy];
    _databaseID = [databaseID copy];
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) return YES;
  if (!other || ![[other class] isEqual:[self class]]) return NO;

  return [self isEqualToDatabaseId:other];
}

- (NSUInteger)hash {
  NSUInteger hash = [self.projectID hash];
  hash = hash * 31u + [self.databaseID hash];
  return hash;
}

- (NSString *)description {
  return [NSString
      stringWithFormat:@"<FSTDatabaseID: project:%@ database:%@>", self.projectID, self.databaseID];
}

- (NSComparisonResult)compare:(FSTDatabaseID *)other {
  NSComparisonResult cmp = [self.projectID compare:other.projectID];
  return cmp == NSOrderedSame ? [self.databaseID compare:other.databaseID] : cmp;
}

- (BOOL)isDefaultDatabase {
  return [self.databaseID isEqualToString:kDefaultDatabaseID];
}

- (BOOL)isEqualToDatabaseId:(FSTDatabaseID *)databaseID {
  if (self == databaseID) return YES;
  if (databaseID == nil) return NO;
  if (self.projectID != databaseID.projectID &&
      ![self.projectID isEqualToString:databaseID.projectID])
    return NO;
  if (self.databaseID != databaseID.databaseID &&
      ![self.databaseID isEqualToString:databaseID.databaseID])
    return NO;
  return YES;
}

@end

NS_ASSUME_NONNULL_END
