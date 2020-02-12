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

@interface FIRCLSRecordFrame : FIRCLSRecordBase

#pragma mark - required attributes

@property(nonatomic) NSUInteger pc;

#pragma mark - optional attributes

// Method / function call
@property(nonatomic, copy) NSString *symbol;

// Line number.
// Call hasLine before reading from line
@property(nonatomic, readonly) BOOL hasLine;
@property(nonatomic, readonly) NSUInteger line;

// Offset from the start of the program. Used for symbolication.
// Call hasOffset before reading from line
@property(nonatomic, readonly) BOOL hasOffset;
@property(nonatomic, readonly) NSUInteger offset;

@end
