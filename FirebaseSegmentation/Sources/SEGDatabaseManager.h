// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

#import "FirebaseSegmentation/Sources/SEGSegmentationConstants.h"

NS_ASSUME_NONNULL_BEGIN

/// Persist config data in sqlite database on device. Managing data read/write from/to database.
@interface SEGDatabaseManager : NSObject
/// Shared Singleton Instance
+ (instancetype)sharedInstance;

/// Open the database.
- (void)createOrOpenDatabaseWithCompletion:(SEGRequestCompletion)completionHandler;

/// Read all contents of main table.
- (void)loadMainTableWithCompletion:(SEGRequestCompletion)completionHandler;

/// Insert a record in main table.
/// @param firebaseApplication The name of the Firebase App that this segmentation instance is
/// associated with.
/// @param customInstanceIdentifier The custom instance identifier provided by the developer.
/// @param firebaseInstanceIdentifier The firebase instance identifier provided by the IID/FIS SDK.
/// @param associationStatus The current status of the association - Pending until reported to the
/// backend.
- (void)insertMainTableApplicationNamed:(NSString *)firebaseApplication
               customInstanceIdentifier:(NSString *)customInstanceIdentifier
             firebaseInstanceIdentifier:(NSString *)firebaseInstanceIdentifier
                      associationStatus:(NSString *)associationStatus
                      completionHandler:(nullable SEGRequestCompletion)handler;

/// Clear the record of given namespace and package name
/// before updating the table.//TODO: Add delete.
- (void)deleteRecordFromMainTableWithCustomInstanceIdentifier:(NSString *)customInstanceIdentifier;

/// Remove all the records from a config content table.
- (void)deleteAllRecordsFromTable;

NS_ASSUME_NONNULL_END

@end
