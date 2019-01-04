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

#import "GDLLogStorage.h"

@class GDLUploader;

@interface GDLLogStorage ()

/** The queue on which all storage work will occur. */
@property(nonatomic) dispatch_queue_t storageQueue;

/** A map of log hash values to log file on-disk URLs. */
@property(nonatomic) NSMutableDictionary<NSNumber *, NSURL *> *logHashToLogFile;

/** A map of logTargets to a set of log hash values. */
@property(nonatomic)
    NSMutableDictionary<NSNumber *, NSMutableSet<NSURL *> *> *logTargetToLogFileSet;

/** The log uploader instance to use. */
@property(nonatomic) GDLUploader *uploader;

@end
