/*
 * Copyright 2023 Google LLC
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

NS_SWIFT_NAME(LocalCacheSettings)
@interface FIRLocalCacheSettings : NSObject
@end

NS_SWIFT_NAME(PersistentCacheSettings)
@interface FIRPersistentCacheSettings : FIRLocalCacheSettings <NSCopying>

// Default settings, with default cache size set to 100MB.
- (instancetype)init;
- (instancetype)initWithSizeBytes:(NSNumber *)size;

@end

NS_SWIFT_NAME(MemoryCacheSettings)
@interface FIRMemoryCacheSettings : FIRLocalCacheSettings <NSCopying>

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
