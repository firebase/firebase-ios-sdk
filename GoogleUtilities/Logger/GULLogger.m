// Copyright 2018 Google
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

#import "Private/GULLogger.h"

#import <GoogleUtilities/GULAppEnvironmentUtil.h>

#import "Private/GULASLLogger.h"
#import "Public/GULLoggerLevel.h"

static dispatch_once_t sGULLoggerOnceToken;
static id<GULLoggerSystem> sGULLogger;

void GULLoggerInitializeASL(void) {
  [[GULLogger logger] initializeLogger];
}

void GULLoggerEnableSTDERR(void) {
  [[GULLogger logger] printToSTDERR];
}

void GULLoggerForceDebug(void) {
  [GULLogger logger].forcedDebug = YES;
}

void GULSetLoggerLevel(GULLoggerLevel loggerLevel) {
  [GULLogger logger].logLevel = loggerLevel;
}

BOOL GULIsLoggableLevel(GULLoggerLevel loggerLevel) {
  return [[GULLogger logger] isLoggableLevel:loggerLevel];
}

#ifdef DEBUG
void GULResetLogger() {
  sGULLoggerOnceToken = 0;
  sGULLogger = nil;
}

id<GULLoggerSystem> getGULLoggerClient() {
  return sGULLogger;
}

BOOL getGULLoggerDebugMode() {
  return [GULLogger logger].forcedDebug;
}
#endif

void GULLoggerRegisterVersion(const char *version) {
  [GULLogger logger].version = version;
}

void GULLogBasic(GULLoggerLevel level,
                 GULLoggerService service,
                 BOOL forceLog,
                 NSString *messageCode,
                 NSString *message,
                 va_list args_ptr) {
  [[GULLogger logger] logWithLevel:level
                       withService:service
                          withCode:messageCode
                       withMessage:messageCode, args_ptr];
}
#pragma clang diagnostic pop

/**
 * Generates the logging functions using macros.
 *
 * Calling GULLogError(kGULLoggerCore, @"I-COR000001", @"Configure %@ failed.", @"blah") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Error> [{service}][I-COR000001] Configure blah failed.
 * Calling GULLogDebug(kGULLoggerCore, @"I-COR000001", @"Configure succeed.") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Debug> [{service}][I-COR000001] Configure succeed.
 */
#define GUL_LOGGING_FUNCTION(level)                                                     \
  void GULLog##level(GULLoggerService service, BOOL force, NSString *messageCode,       \
                     NSString *message, ...) {                                          \
    va_list args_ptr;                                                                   \
    va_start(args_ptr, message);                                                        \
    GULLogBasic(GULLoggerLevel##level, service, force, messageCode, message, args_ptr); \
    va_end(args_ptr);                                                                   \
  }

GUL_LOGGING_FUNCTION(Error)
GUL_LOGGING_FUNCTION(Warning)
GUL_LOGGING_FUNCTION(Notice)
GUL_LOGGING_FUNCTION(Info)
GUL_LOGGING_FUNCTION(Debug)

#undef GUL_MAKE_LOGGER

@implementation GULLogger

+ (id<GULLoggerSystem>)logger {
  dispatch_once(&sGULLoggerOnceToken, ^{
    // TODO(bstpierre): Determine which iOS version we are running.
    sGULLogger = [[GULASLLogger alloc] init];
  });
  return sGULLogger;
}

@end
