/*
 * Copyright 2018 Google
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

#import "GDTStorage.h"

@class GDTUploadCoordinator;

NS_ASSUME_NONNULL_BEGIN

@interface GDTStorage ()

/** The queue on which all storage work will occur. */
@property(nonatomic) dispatch_queue_t storageQueue;

/** A map of event hashes to their on-disk file URLs. */
@property(nonatomic) NSMutableDictionary<NSNumber *, NSURL *> *eventHashToFile;

/** A map of targets to a set of event hash values. */
@property(nonatomic)
    NSMutableDictionary<NSNumber *, NSMutableSet<NSNumber *> *> *targetToEventHashSet;

/** The upload coordinator instance to use. */
@property(nonatomic) GDTUploadCoordinator *uploader;

@end

NS_ASSUME_NONNULL_END
