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

#import "FirebaseDatabase/Sources/Core/FRepo.h"
#import "FirebaseDatabase/Sources/Core/FSparseSnapshotTree.h"

@class FSyncTree;
@class FAtomicNumber;
@class FEventRaiser;
@class FSnapshotHolder;

@interface FRepo ()

- (void)runOnDisconnectEvents;

@property(nonatomic, strong) FRepoInfo *repoInfo;
@property(nonatomic, strong) FPersistentConnection *connection;
@property(nonatomic, strong) FSnapshotHolder *infoData;
@property(nonatomic, strong) FSparseSnapshotTree *onDisconnect;
@property(nonatomic, strong) FEventRaiser *eventRaiser;
@property(nonatomic, strong) FSyncTree *serverSyncTree;

// For testing.
@property(nonatomic) long dataUpdateCount;
@property(nonatomic) long rangeMergeUpdateCount;

- (NSInteger)nextWriteId;

@end
