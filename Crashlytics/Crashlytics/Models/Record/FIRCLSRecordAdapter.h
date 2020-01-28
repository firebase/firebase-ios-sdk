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

#import <Foundation/Foundation.h>

/**
 * The class will be responsible for aggregating the data from the persisted crash files
 * and returning a report object used for FireLog.
 **/
@interface FIRCLSRecordAdapter : NSObject

- (instancetype)init NS_UNAVAILABLE;

/// Initializer
/// @param folderPath Path where the persisted crash files reside
- (instancetype)initWithPath:(NSString *)folderPath;

// TODO: Add function to return the nanopb/FireLog report

@end
