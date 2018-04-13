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

#import "Firestore/Source/Core/FSTDatabaseInfo.h"

#import "Firestore/Source/Model/FSTDatabaseID.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTDatabaseInfo

@implementation FSTDatabaseInfo

#pragma mark - Constructors

+ (instancetype)databaseInfoWithDatabaseID:(FSTDatabaseID *)databaseID
                            persistenceKey:(NSString *)persistenceKey
                                      host:(NSString *)host
                                sslEnabled:(BOOL)sslEnabled {
  return [[FSTDatabaseInfo alloc] initWithDatabaseID:databaseID
                                      persistenceKey:persistenceKey
                                                host:host
                                          sslEnabled:sslEnabled];
}

/**
 * Designated initializer.
 *
 * @param databaseID The database in the datastore.
 * @param persistenceKey A unique identifier for this Firestore's local storage. Usually derived
 *     from -[FIRApp appName].
 * @param host The Firestore server hostname.
 * @param sslEnabled Whether to use SSL when connecting.
 */
- (instancetype)initWithDatabaseID:(FSTDatabaseID *)databaseID
                    persistenceKey:(NSString *)persistenceKey
                              host:(NSString *)host
                        sslEnabled:(BOOL)sslEnabled {
  if (self = [super init]) {
    _databaseID = databaseID;
    _persistenceKey = [persistenceKey copy];
    _host = [host copy];
    _sslEnabled = sslEnabled;
  }
  return self;
}

#pragma mark - NSObject methods

- (NSString *)description {
  return [NSString
      stringWithFormat:@"<FSTDatabaseInfo: databaseID:%@ host:%@>", self.databaseID, self.host];
}

@end

NS_ASSUME_NONNULL_END
