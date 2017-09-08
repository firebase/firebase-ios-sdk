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

#import "FStorageEngine.h"
#import "FNode.h"
#import "FPath.h"
#import "FCompoundWrite.h"
#import "FQuerySpec.h"

@class FCacheNode;
@class FTrackedQuery;
@class FPruneForest;
@class FRepoInfo;

@interface FLevelDBStorageEngine : NSObject<FStorageEngine>

+ (NSString *) firebaseDir;

- (id)initWithPath:(NSString *)path;

- (void)runLegacyMigration:(FRepoInfo *)info;
- (void)purgeEverything;

@end
