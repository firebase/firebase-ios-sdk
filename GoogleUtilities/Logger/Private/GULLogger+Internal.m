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

#import "GULLogger+Internal.h"

#ifdef DEBUG
static NSRegularExpression *sMessageCodeRegex;
static NSString *const kGULLoggerMessageCodePattern = @"^I-[A-Z]{3}[0-9]{6}$";
#endif

@implementation GULLogger (Internal)

+ (BOOL)loggerSystem:(id<GULLoggerSystem>)logger shouldLogMessageOfLevel:(GULLoggerLevel)logLevel {
  if (logger.forcedDebug) {
    return YES;
  } else if (logLevel < GULLoggerLevelMin || logLevel > GULLoggerLevelMax) {
    return NO;
  }
  return logLevel <= logger.logLevel;
}

+ (NSString *)messageFromLogger:(id<GULLoggerSystem>)logger
                    withService:(GULLoggerService)service
                           code:(NSString *)code
                        message:(NSString *)message {
#ifdef DEBUG
  NSCAssert(code.length == 11, @"Incorrect message code length.");
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sMessageCodeRegex =
        [NSRegularExpression regularExpressionWithPattern:kGULLoggerMessageCodePattern
                                                  options:0
                                                    error:NULL];
  });
  NSRange messageCodeRange = NSMakeRange(0, code.length);
  NSUInteger numberOfMatches = [sMessageCodeRegex numberOfMatchesInString:code
                                                                  options:0
                                                                    range:messageCodeRange];
  NSCAssert(numberOfMatches == 1, @"Incorrect message code format.");
#endif
  return [NSString stringWithFormat:@"%@ - %@[%@] %@", logger.version, service, code, message];
}

@end
