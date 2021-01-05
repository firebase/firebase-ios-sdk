/*
 * Copyright 2019 Google
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
#import <mach-o/arch.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRAppDistributionMachOSlice : NSObject

@property(nonatomic, assign) const NXArchInfo* arch;
@property(nonatomic, copy) NSUUID* uuid;

- (instancetype)initWithArch:(const NXArchInfo*)arch uuid:(NSUUID*)uuid;

- (NSString*)architectureName;
- (NSString*)uuidString;

@end

NS_ASSUME_NONNULL_END
