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

#import "FirebaseDatabase/Sources/Api/Private/FTypedefs_Private.h"
#import "FirebaseDatabase/Sources/Core/FQueryParams.h"
#import "FirebaseDatabase/Sources/Core/FRepo.h"
#import "FirebaseDatabase/Sources/Core/FRepoManager.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDatabaseQuery.h"

@interface FIRDatabaseQuery ()

+ (dispatch_queue_t)sharedQueue;

- (id)initWithRepo:(FRepo *)repo path:(FPath *)path;
- (id)initWithRepo:(FRepo *)repo
                    path:(FPath *)path
                  params:(FQueryParams *)params
           orderByCalled:(BOOL)orderByCalled
    priorityMethodCalled:(BOOL)priorityMethodCalled;

@property(nonatomic, strong) FRepo *repo;
@property(nonatomic, strong) FPath *path;
@property(nonatomic, strong) FQueryParams *queryParams;
@property(nonatomic) BOOL orderByCalled;
@property(nonatomic) BOOL priorityMethodCalled;

- (FQuerySpec *)querySpec;

@end
