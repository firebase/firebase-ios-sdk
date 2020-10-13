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

#import "FirebaseABTesting/Tests/Unit/Utilities/ABTTestUtilities.h"

#import "FirebaseABTesting/Sources/Private/ABTExperimentPayload.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ABTTestUtilities

+ (NSBundle *)getBundle {
#if SWIFT_PACKAGE
  return Firebase_ABTestingUnit_SWIFTPM_MODULE_BUNDLE();
#else
  return [NSBundle bundleForClass:[ABTTestUtilities class]];
#endif
}

+ (ABTExperimentPayload *)payloadFromTestFilename:(NSString *)filename {
  NSBundle *abtBundle = [self getBundle];
  NSString *testJsonDataFilePath = [abtBundle pathForResource:filename ofType:@"txt"];
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

+ (NSData *)payloadJSONDataFromFile:(NSString *)filename
                  modifiedStartTime:(nullable NSDate *)modifiedStartTime {
  NSBundle *abtBundle = [self getBundle];
  NSString *testJsonDataFilePath = [abtBundle pathForResource:filename ofType:@"txt"];
  NSError *readTextError = nil;
  NSString *fileText = [[NSString alloc] initWithContentsOfFile:testJsonDataFilePath
                                                       encoding:NSUTF8StringEncoding
                                                          error:&readTextError];

  NSData *fileData = [fileText dataUsingEncoding:kCFStringEncodingUTF8];

  NSError *jsonDictionaryError = nil;
  NSMutableDictionary *jsonDictionary =
      [[NSJSONSerialization JSONObjectWithData:fileData
                                       options:kNilOptions
                                         error:&jsonDictionaryError] mutableCopy];
  if (modifiedStartTime) {
    jsonDictionary[@"experimentStartTime"] =
        [[ABTTestUtilities class] dateStringForStartTime:modifiedStartTime];
  }

  NSError *jsonDataError = nil;
  return [NSJSONSerialization dataWithJSONObject:jsonDictionary
                                         options:kNilOptions
                                           error:&jsonDataError];
}

+ (NSString *)dateStringForStartTime:(NSDate *)startTime {
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
  [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
  // Locale needs to be hardcoded. See
  // https://developer.apple.com/library/ios/#qa/qa1480/_index.html for more details.
  [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
  [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];

  return [dateFormatter stringFromDate:startTime];
}

@end

NS_ASSUME_NONNULL_END
