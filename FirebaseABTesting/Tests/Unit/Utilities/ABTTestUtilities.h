// Copyright 2020 Google LLC
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

@class ABTExperimentPayload;

NS_ASSUME_NONNULL_BEGIN

@interface ABTTestUtilities : NSObject

/// Generates an ABTExperimentPayload object from the test file directory.
+ (ABTExperimentPayload *)payloadFromTestFilename:(NSString *)filename;

/// Generates a serialized JSON object from the test file directory.
/// @param modifiedStartTime clobbers the start time for the experiment from the test file.
+ (NSData *)payloadJSONDataFromFile:(NSString *)filename
                  modifiedStartTime:(nullable NSDate *)modifiedStartTime;

@end

NS_ASSUME_NONNULL_END
