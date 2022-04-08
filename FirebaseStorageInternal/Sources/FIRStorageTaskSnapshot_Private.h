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

#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageTaskSnapshot.h"

#import "FirebaseStorageInternal/Sources/FIRStorageConstants_Private.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRIMPLStorageMetadata;
@class FIRIMPLStorageReference;
@class FIRIMPLStorageTask;

@interface FIRIMPLStorageTaskSnapshot ()

@property(readwrite, copy, nonatomic) FIRIMPLStorageTask *task;
@property(readwrite, copy, nonatomic) FIRIMPLStorageMetadata *metadata;
@property(readwrite, copy, nonatomic) FIRIMPLStorageReference *reference;
@property(readwrite, strong, nonatomic) NSProgress *progress;
@property(readwrite, copy, nonatomic) NSError *error;

/**
 * Creates a new task snapshot from the given properties.
 * @param task The task being represented in this snapshot.
 * @param state The current state of the parent task.
 * @param metadata The FIRIMPLStorageMetadata of a task. Before upload/update, contains the metadata
 * to be updated; after, contains the returned metadata. May be nil if no metadata is provided
 * or returned.
 * @param reference The FIRIMPLStorageReference that spawned the task this snapshot is based on.
 * @param progress An NSProgress object containing progress of the task this snapshot is based on,
 * or nil if the task doesn't report progress.
 * @param error An NSError object containing an error that occurred during the task,
 * if one occurred.
 * @return Returns the constructed snapshot.
 */
- (instancetype)initWithTask:(__kindof FIRIMPLStorageTask *)task
                       state:(FIRIMPLStorageTaskState)state
                    metadata:(nullable FIRIMPLStorageMetadata *)metadata
                   reference:(FIRIMPLStorageReference *)reference
                    progress:(nullable NSProgress *)progress
                       error:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
