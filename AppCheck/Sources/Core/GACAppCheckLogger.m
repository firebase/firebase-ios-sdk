/*
 * Copyright 2020 Google LLC
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

#import "AppCheck/Sources/Public/AppCheck/GACAppCheckLogger.h"

#import "AppCheck/Sources/Core/GACAppCheckLogger+Internal.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Public

@implementation GACAppCheckLogger

// Note: Declared as volatile to make getting and setting atomic.
static volatile GACAppCheckLogLevel _logLevel;

+ (GACAppCheckLogLevel)logLevel {
  return _logLevel;
}

+ (void)setLogLevel:(GACAppCheckLogLevel)logLevel {
  _logLevel = logLevel;
}

@end

#pragma mark - Helpers

NSString *GACAppCheckMessageCodeEnumToString(GACAppCheckMessageCode code) {
  return [[NSString alloc] initWithFormat:@"I-GAC%06ld", (long)code];
}

NSString *GACAppCheckLoggerLevelEnumToString(GACAppCheckLogLevel logLevel) {
  switch (logLevel) {
    case GACAppCheckLogLevelFault:
      return @"Fault";
    case GACAppCheckLogLevelError:
      return @"Error";
    case GACAppCheckLogLevelWarning:
      return @"Warning";
    case GACAppCheckLogLevelInfo:
      return @"Info";
    case GACAppCheckLogLevelDebug:
      return @"Debug";
  }
}

#pragma mark - Logging Functions

/**
 * Generates the logging functions using macros.
 *
 * Calling GACLogError(@"Firebase", @"I-GAC000001", @"Configure %@ failed.", @"blah") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Error> [Firebase/AppCheck][I-GAC000001] Configure blah
 * failed. Calling GACLogDebug(@"GoogleSignIn", @"I-GAC000002", @"Configure succeed.") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Debug> [GoogleSignIn/AppCheck][I-COR000002] Configure
 * succeed.
 */
void GACAppCheckLog(GACAppCheckMessageCode code, GACAppCheckLogLevel logLevel, NSString *message) {
  // Don't log anything in not debug builds.
#if !NDEBUG
  if (logLevel >= GACAppCheckLogger.logLevel) {
    NSLog(@"<%@> [AppCheckCore][%@] %@", GACAppCheckLoggerLevelEnumToString(logLevel),
          GACAppCheckMessageCodeEnumToString(code), message);
  }
#endif  // !NDEBUG
}

NS_ASSUME_NONNULL_END
