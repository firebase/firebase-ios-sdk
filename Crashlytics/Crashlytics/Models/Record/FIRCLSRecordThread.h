/*
 * Copyright 2020 Google
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

#import "FIRCLSRecordBase.h"

@class FIRCLSRecordFrame;
@class FIRCLSRecordRegister;
@class FIRCLSRecordRuntime;

@interface FIRCLSRecordThread : FIRCLSRecordBase

@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *alternate_name;
@property(nonatomic, copy) NSString *objc_selector_name;
@property(nonatomic, assign) BOOL crashed;
@property(nonatomic, strong) NSArray<FIRCLSRecordRegister *> *registers;
@property(nonatomic, strong) NSArray<NSNumber *> *stacktrace;
@property(nonatomic, assign) uint32_t importance;

/// Aggregate data and returns a collection of populated threads
/// @param threads Array of thread dictionaries
/// @param names Array of thread names
/// @param dispatchNames Array of dispatch queue names
/// @param runtime Runtime object
+ (NSArray<FIRCLSRecordThread *> *)threadsFromDictionaries:(NSArray<NSDictionary *> *)threads
                                               threadNames:(NSArray<NSString *> *)names
                                    withDispatchQueueNames:(NSArray<NSString *> *)dispatchNames
                                               withRuntime:(FIRCLSRecordRuntime *)runtime;

@end
