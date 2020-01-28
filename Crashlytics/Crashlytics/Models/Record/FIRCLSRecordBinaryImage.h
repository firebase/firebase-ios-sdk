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

@interface FIRCLSRecordBinaryImage : FIRCLSRecordBase

@property(nonatomic, copy) NSString *path;
@property(nonatomic, copy) NSString *uuid;
@property(nonatomic, assign) NSUInteger base;
@property(nonatomic, assign) NSUInteger size;

/// Return an array of binary images
/// @param dicts Dictionary describing the binary images
+ (NSArray<FIRCLSRecordBinaryImage *> *)binaryImagesFromDictionaries:
    (NSArray<NSDictionary *> *)dicts;

@end
