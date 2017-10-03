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

@class FSTDatabaseID;

NS_ASSUME_NONNULL_BEGIN

/** FSTDatabaseInfo contains data about the database. */
@interface FSTDatabaseInfo : NSObject

/**
 * Creates and returns a new FSTDatabaseInfo.
 *
 * @param databaseID The project/database to use.
 * @param persistenceKey A unique identifier for this Firestore's local storage. Usually derived
 *     from -[FIRApp appName].
 * @param host The hostname of the datastore backend.
 * @param sslEnabled Whether to use SSL when connecting.
 * @return A new instance of FSTDatabaseInfo.
 */
+ (instancetype)databaseInfoWithDatabaseID:(FSTDatabaseID *)databaseID
                            persistenceKey:(NSString *)persistenceKey
                                      host:(NSString *)host
                                sslEnabled:(BOOL)sslEnabled;

/** The database info. */
@property(nonatomic, strong, readonly) FSTDatabaseID *databaseID;

/** The application name, taken from FIRApp. */
@property(nonatomic, copy, readonly) NSString *persistenceKey;

/** The hostname of the backend. */
@property(nonatomic, copy, readonly) NSString *host;

/** Whether to use SSL when connecting. */
@property(nonatomic, readonly, getter=isSSLEnabled) BOOL sslEnabled;

@end

NS_ASSUME_NONNULL_END
