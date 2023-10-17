/*
 * Copyright 2018 Google
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

#import "FirebaseAuth/Sources/Utilities/NSData+FIRBase64.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSData (FIRBase64)

- (NSString *)fir_base64URLEncodedStringWithOptions:(NSDataBase64EncodingOptions)options {
  NSString *string = [self base64EncodedStringWithOptions:options];
  string = [string stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
  string = [string stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
  string = [string stringByReplacingOccurrencesOfString:@"=" withString:@""];
  return string;
}

- (id)fir_initWithBase64URLEncodedString:(NSString *)base64URLEncodedString
                                 options:(NSDataBase64DecodingOptions)options {
  // Replace "_" with "/"
  NSMutableString *base64String =
      [[base64URLEncodedString stringByReplacingOccurrencesOfString:@"_"
                                                         withString:@"/"] mutableCopy];

  // Replace "-" with "+"
  [base64String replaceOccurrencesOfString:@"-"
                                withString:@"+"
                                   options:kNilOptions
                                     range:NSMakeRange(0, base64String.length)];

  // Pad the base64String with "=" signs if the payload's length is not a multiple of 4.
  while ((base64String.length % 4) != 0) {
    [base64String appendFormat:@"="];
  }

  return [self initWithBase64EncodedString:base64String options:options];
}

@end

NS_ASSUME_NONNULL_END
