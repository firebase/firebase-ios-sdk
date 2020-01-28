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

@interface FIRCLSRecordProcessStats : FIRCLSRecordBase

@property(nonatomic, assign) NSUInteger active;
@property(nonatomic, assign) NSUInteger inactive;
@property(nonatomic, assign) NSUInteger wired;
@property(nonatomic, assign) NSUInteger freeMem;
@property(nonatomic, assign) NSUInteger virtualAddress;
@property(nonatomic, assign) NSUInteger resident;
@property(nonatomic, assign) NSUInteger user_time;
@property(nonatomic, assign) NSUInteger sys_time;

@end
