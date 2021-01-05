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

#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDatabase.h"

@class FRepo;
@class FRepoInfo;
@class FIRDatabaseConfig;

@interface FIRDatabase ()

@property(nonatomic, strong) FRepoInfo *repoInfo;
@property(nonatomic, strong) FIRDatabaseConfig *config;
@property(nonatomic, strong) FRepo *repo;

- (id)initWithApp:(FIRApp *)app
         repoInfo:(FRepoInfo *)info
           config:(FIRDatabaseConfig *)config;

+ (NSString *)buildVersion;
+ (FIRDatabase *)createDatabaseForTests:(FRepoInfo *)repoInfo
                                 config:(FIRDatabaseConfig *)config;

@end
