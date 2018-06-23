// Copyright 2017 Google
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

#import "Private/FIRLogger.h"

#import <GoogleUtilities/GULAppEnvironmentUtil.h>
#import <GoogleUtilities/GULLogger.h>
#import "Public/FIRLoggerLevel.h"

#include <asl.h>
#include <assert.h>
#include <stdbool.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <unistd.h>

FIRLoggerService kFIRLoggerABTesting = @"[Firebase/ABTesting]";
FIRLoggerService kFIRLoggerAdMob = @"[Firebase/AdMob]";
FIRLoggerService kFIRLoggerAnalytics = @"[Firebase/Analytics]";
FIRLoggerService kFIRLoggerAuth = @"[Firebase/Auth]";
FIRLoggerService kFIRLoggerCore = @"[Firebase/Core]";
FIRLoggerService kFIRLoggerCrash = @"[Firebase/Crash]";
FIRLoggerService kFIRLoggerDatabase = @"[Firebase/Database]";
FIRLoggerService kFIRLoggerDynamicLinks = @"[Firebase/DynamicLinks]";
FIRLoggerService kFIRLoggerFirestore = @"[Firebase/Firestore]";
FIRLoggerService kFIRLoggerInstanceID = @"[Firebase/InstanceID]";
FIRLoggerService kFIRLoggerInvites = @"[Firebase/Invites]";
FIRLoggerService kFIRLoggerMLKit = @"[Firebase/MLKit]";
FIRLoggerService kFIRLoggerMessaging = @"[Firebase/Messaging]";
FIRLoggerService kFIRLoggerPerf = @"[Firebase/Performance]";
FIRLoggerService kFIRLoggerRemoteConfig = @"[Firebase/RemoteConfig]";
FIRLoggerService kFIRLoggerStorage = @"[Firebase/Storage]";
FIRLoggerService kFIRLoggerSwizzler = @"[FirebaseSwizzlingUtilities]";

/// Arguments passed on launch.
NSString *const kFIRDisableDebugModeApplicationArgument = @"-FIRDebugDisabled";
NSString *const kFIREnableDebugModeApplicationArgument = @"-FIRDebugEnabled";
NSString *const kFIRLoggerForceSDTERRApplicationArgument = @"-FIRLoggerForceSTDERR";

static dispatch_once_t sFIRLoggerOnceToken;

// The sFIRAnalyticsDebugMode flag is here to support the -FIRDebugEnabled/-FIRDebugDisabled
// flags used by Analytics. Users who use those flags expect Analytics to log verbosely,
// while the rest of Firebase logs at the default level. This flag is introduced to support
// that behavior.
static BOOL sFIRAnalyticsDebugMode;

#ifdef DEBUG
/// The regex pattern for the message code.
static NSString *const kMessageCodePattern = @"^I-[A-Z]{3}[0-9]{6}$";
static NSRegularExpression *sMessageCodeRegex;
#endif

void FIRLoggerInitializeASL() {
  dispatch_once(&sFIRLoggerOnceToken, ^{
    NSArray *arguments = [NSProcessInfo processInfo].arguments;
    GULLoggerInitializeASL([arguments containsObject:kFIRDisableDebugModeApplicationArgument],
                           [arguments containsObject:kFIREnableDebugModeApplicationArgument],
                           [arguments containsObject:kFIRLoggerForceSDTERRApplicationArgument]);
  });
}

void FIRSetAnalyticsDebugMode(BOOL analyticsDebugMode) {
  if (analyticsDebugMode && [GULAppEnvironmentUtil isFromAppStore]) {
    return;
  }
  sFIRAnalyticsDebugMode = analyticsDebugMode;
  if (sFIRAnalyticsDebugMode) {
    FIRLoggerInitializeASL();
    sFIRAnalyticsDebugMode = analyticsDebugMode;
  }
}

void FIRSetLoggerLevel(FIRLoggerLevel loggerLevel) {
  GULSetLoggerLevel((GULLoggerLevel)loggerLevel);
}

#ifdef DEBUG
void FIRResetLogger() {
  extern void GULResetLogger(void);
  sFIRLoggerOnceToken = 0;
  GULResetLogger();
}
#endif

/**
 * Check if the level is high enough to be loggable.
 */
BOOL FIRIsLoggableLevel(FIRLoggerLevel loggerLevel, BOOL analyticsComponent) {
  FIRLoggerInitializeASL();
  return GULIsLoggableLevel((GULLoggerLevel)loggerLevel,
                            sFIRAnalyticsDebugMode && analyticsComponent);
}

void FIRLogBasic(FIRLoggerLevel level,
                 FIRLoggerService service,
                 NSString *messageCode,
                 NSString *message,
                 va_list args_ptr) {
  FIRLoggerInitializeASL();
  GULLogBasic((GULLoggerLevel)level, service, NO, messageCode, message, args_ptr);
}

/**
 * Generates the logging functions using macros.
 *
 * Calling FIRLogError(kFIRLoggerCore, @"I-COR000001", @"Configure %@ failed.", @"blah") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Error> [Firebase/Core][I-COR000001] Configure blah failed.
 * Calling FIRLogDebug(kFIRLoggerCore, @"I-COR000001", @"Configure succeed.") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Debug> [Firebase/Core][I-COR000001] Configure succeed.
 */
#define FIR_LOGGING_FUNCTION(level)                                                             \
  void FIRLog##level(FIRLoggerService service, NSString *messageCode, NSString *message, ...) { \
    va_list args_ptr;                                                                           \
    va_start(args_ptr, message);                                                                \
    FIRLogBasic(FIRLoggerLevel##level, service, messageCode, message, args_ptr);                \
    va_end(args_ptr);                                                                           \
  }

FIR_LOGGING_FUNCTION(Error)
FIR_LOGGING_FUNCTION(Warning)
FIR_LOGGING_FUNCTION(Notice)
FIR_LOGGING_FUNCTION(Info)
FIR_LOGGING_FUNCTION(Debug)

#undef FIR_MAKE_LOGGER

#pragma mark - FIRLoggerWrapper

@implementation FIRLoggerWrapper

+ (void)logWithLevel:(FIRLoggerLevel)level
         withService:(FIRLoggerService)service
            withCode:(NSString *)messageCode
         withMessage:(NSString *)message
            withArgs:(va_list)args {
  FIRLogBasic(level, service, messageCode, message, args);
}

@end
