/*
 * Copyright 2021 Google LLC
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

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FIRLoadBundleTaskState) {

  FIRLoadBundleTaskStateError,

  FIRLoadBundleTaskStateInProgress,

  FIRLoadBundleTaskStateSuccess,

} NS_SWIFT_NAME(LoadBundleTaskState);

NS_SWIFT_NAME(LoadBundleTaskProgress)
@interface FIRLoadBundleTaskProgress : NSObject

@property(readonly, nonatomic) NSInteger documentsLoaded;
@property(readonly, nonatomic) NSInteger totalDocuments;
@property(readonly, nonatomic) NSInteger bytesLoaded;
@property(readonly, nonatomic) NSInteger totalBytes;

@property(readonly, nonatomic) FIRLoadBundleTaskState state;

@end

typedef NSString *FIRLoadBundleHandle NS_SWIFT_NAME(LoadBundleHandle);

NS_SWIFT_NAME(LoadBundleTask)
@interface FIRLoadBundleTask : NSObject

- (FIRLoadBundleHandle)observeState:(FIRLoadBundleTaskState)state
                            handler:(void (^)(FIRLoadBundleTaskProgress *progress))handler;

- (void)removeObserverWithHandle:(FIRLoadBundleHandle)handle;

- (void)removeAllObserversForState:(FIRLoadBundleTaskState)state;

- (void)removeAllObservers;

@end

NS_ASSUME_NONNULL_END
