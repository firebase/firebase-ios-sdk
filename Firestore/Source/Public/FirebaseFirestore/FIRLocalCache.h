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

NS_ASSUME_NONNULL_BEGIN

@class FIRDiskCache;
@class FIRMemoryCache;

NS_SWIFT_NAME(LocalCache)
@interface FIRLocalCache : NSObject <NSCopying>

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

+ (FIRDiskCache*)disk;
+ (FIRDiskCache*)diskWithSizeBytes:(long)size;
+ (FIRMemoryCache*)memory;

@end

NS_SWIFT_NAME(DiskCache)
@interface FIRDiskCache : FIRLocalCache <NSCopying>

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, readonly) long size;

@end

NS_SWIFT_NAME(MemoryCache)
@interface FIRMemoryCache : FIRLocalCache <NSCopying>

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

@end
NS_ASSUME_NONNULL_END
