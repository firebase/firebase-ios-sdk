// Copyright 2020 Google
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

#import "ABTTestUtilities.h"

#import <FirebaseABTesting/ABTExperimentPayload.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ABTTestUtilities

+ (ABTExperimentPayload *)payloadFromTestFilename:(NSString *)filename {
  NSString *testJsonDataFilePath = [[NSBundle bundleForClass:[ABTTestUtilities class]] pathForResource:filename
                                                                                    ofType:@"txt"];
  NSError *readTextError = nil;
  NSString *fileText = [[NSString alloc] initWithContentsOfFile:testJsonDataFilePath
                                                       encoding:NSUTF8StringEncoding
                                                          error:&readTextError];
  if (readTextError) {
    NSAssert(NO, readTextError.localizedDescription);
    return nil;
  }
  return [ABTExperimentPayload parseFromData:[fileText dataUsingEncoding:NSUTF8StringEncoding]];
}

+ (NSData *)JSONDataFromFile:(NSString *)filename {
  NSString *testJsonDataFilePath = [[NSBundle bundleForClass:[ABTTestUtilities class]] pathForResource:filename
                                                                                    ofType:@"txt"];
  NSError *readTextError = nil;
  NSString *fileText = [[NSString alloc] initWithContentsOfFile:testJsonDataFilePath
                                                       encoding:NSUTF8StringEncoding
                                                          error:&readTextError];
  
  NSError *jsonError = nil;
  
  return [NSJSONSerialization dataWithJSONObject:fileText
                                         options:NSJSONWritingFragmentsAllowed
                                           error:&jsonError];
}

@end

NS_ASSUME_NONNULL_END
