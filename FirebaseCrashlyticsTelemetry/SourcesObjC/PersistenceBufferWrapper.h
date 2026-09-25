// Copyright 2026 Google LLC
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
#import "PersistenceSpan.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_CLOSED_ENUM(NSInteger, PersistenceBufferSize) {
  PersistenceBufferSizeSmall = 0,
  PersistenceBufferSizeMedium = 1,
  PersistenceBufferSizeLarge = 2
};

@interface PersistenceBufferWrapper : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// Initializes the file-backed buffer and extracts any spans persisted from a prior session/crash.
///
/// @param filePath The absolute file path to the mmap buffer file.
/// @param bufferSize The allocated size tier for the mmap buffer.
/// @param outRecoveredSpans Populated with recovered spans if found, even if the active buffer fails to initialize.
/// @return An active buffer instance, or nil if the live mutable buffer could not be established.
+ (nullable instancetype)initializeWithFilePath:(NSString *)filePath
                                     bufferSize:(PersistenceBufferSize)bufferSize
                                 recoveredSpans:(NSArray<PersistenceSpan *> * _Nullable * _Nonnull)outRecoveredSpans;

- (void)addSpan:(PersistenceSpan *)span;
- (void)setAttribute:(NSString *)value forKey:(NSString *)key onSpanId:(uint64_t)spanId;
- (void)endSpanId:(uint64_t)spanId endTime:(uint64_t)endTime;
- (void)removeSpanId:(uint64_t)spanId;

@end

NS_ASSUME_NONNULL_END
