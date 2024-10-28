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

#import "FirebaseCore/InternalObjC/FIRLogger.h"

#import <GoogleUtilities/GULAppEnvironmentUtil.h>
#import <GoogleUtilities/GULLogger.h>
#import "FirebaseCore/Sources/Public/FirebaseCore/FIRLoggerLevel.h"

#import "FirebaseCore/Sources/Public/FirebaseCore/FIRVersion.h"

NSString *const kFIRLoggerSubsystem = @"com.google.firebase";

NSString *const kFIRLoggerCore = @"[FirebaseCore]";

// All the FIRLoggerService definitions should be migrated to clients. Do not add new ones!
NSString *const kFIRLoggerAnalytics = @"[FirebaseAnalytics]";
NSString *const kFIRLoggerCrash = @"[FirebaseCrash]";
NSString *const kFIRLoggerRemoteConfig = @"[FirebaseRemoteConfig]";

/// Arguments passed on launch.
NSString *const kFIRDisableDebugModeApplicationArgument = @"-FIRDebugDisabled";
NSString *const kFIREnableDebugModeApplicationArgument = @"-FIRDebugEnabled";

/// Key for the debug mode bit in NSUserDefaults.
NSString *const kFIRPersistedDebugModeKey = @"/google/firebase/debug_mode";

/// NSUserDefaults that should be used to store and read variables. If nil, `standardUserDefaults`
/// will be used.
static NSUserDefaults *sFIRLoggerUserDefaults;

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

void FIRLoggerInitialize(void) {
  dispatch_once(&sFIRLoggerOnceToken, ^{
    // Register Firebase Version with GULLogger.
    // TODO!
    // GULLoggerRegisterVersion(FIRFirebaseVersion());

    NSArray *arguments = [NSProcessInfo processInfo].arguments;

    // Use the standard NSUserDefaults if it hasn't been explicitly set.
    if (sFIRLoggerUserDefaults == nil) {
      sFIRLoggerUserDefaults = [NSUserDefaults standardUserDefaults];
    }

    BOOL forceDebugMode = NO;
    BOOL debugMode = [sFIRLoggerUserDefaults boolForKey:kFIRPersistedDebugModeKey];
    if ([arguments containsObject:kFIRDisableDebugModeApplicationArgument]) {  // Default mode
      [sFIRLoggerUserDefaults removeObjectForKey:kFIRPersistedDebugModeKey];
    } else if ([arguments containsObject:kFIREnableDebugModeApplicationArgument] ||
               debugMode) {  // Debug mode
      [sFIRLoggerUserDefaults setBool:YES forKey:kFIRPersistedDebugModeKey];
      forceDebugMode = YES;
    }
    GULLoggerInitialize();
    if (forceDebugMode) {
      GULLoggerForceDebug();
    }
  });
}

__attribute__((no_sanitize("thread"))) void FIRSetAnalyticsDebugMode(BOOL analyticsDebugMode) {
  sFIRAnalyticsDebugMode = analyticsDebugMode;
}

FIRLoggerLevel FIRGetLoggerLevel(void) {
  FIRLoggerInitialize();
  return (FIRLoggerLevel)GULGetLoggerLevel();
}

void FIRSetLoggerLevel(FIRLoggerLevel loggerLevel) {
  FIRLoggerInitialize();
  GULSetLoggerLevel((GULLoggerLevel)loggerLevel);
}

void FIRSetLoggerLevelNotice(void) {
  FIRLoggerInitialize();
  GULSetLoggerLevel(GULLoggerLevelNotice);
}

void FIRSetLoggerLevelWarning(void) {
  FIRLoggerInitialize();
  GULSetLoggerLevel(GULLoggerLevelWarning);
}

void FIRSetLoggerLevelError(void) {
  FIRLoggerInitialize();
  GULSetLoggerLevel(GULLoggerLevelError);
}

void FIRSetLoggerLevelDebug(void) {
  FIRLoggerInitialize();
  GULSetLoggerLevel(GULLoggerLevelDebug);
}

#ifdef DEBUG
void FIRResetLogger(void) {
  extern void GULResetLogger(void);
  sFIRLoggerOnceToken = 0;
  [sFIRLoggerUserDefaults removeObjectForKey:kFIRPersistedDebugModeKey];
  sFIRLoggerUserDefaults = nil;
  GULResetLogger();
}

void FIRSetLoggerUserDefaults(NSUserDefaults *defaults) {
  sFIRLoggerUserDefaults = defaults;
}
#endif

/**
 * Check if the level is high enough to be loggable.
 *
 * Analytics can override the log level with an intentional race condition.
 * Add the attribute to get a clean thread sanitizer run.
 */
__attribute__((no_sanitize("thread"))) BOOL FIRIsLoggableLevel(FIRLoggerLevel loggerLevel,
                                                               BOOL analyticsComponent) {
  FIRLoggerInitialize();
  if (sFIRAnalyticsDebugMode && analyticsComponent) {
    return YES;
  }
  return GULIsLoggableLevel((GULLoggerLevel)loggerLevel);
}

BOOL FIRIsLoggableLevelNotice(void) {
  return FIRIsLoggableLevel(FIRLoggerLevelNotice, NO);
}

BOOL FIRIsLoggableLevelWarning(void) {
  return FIRIsLoggableLevel(FIRLoggerLevelWarning, NO);
}

BOOL FIRIsLoggableLevelError(void) {
  return FIRIsLoggableLevel(FIRLoggerLevelError, NO);
}

BOOL FIRIsLoggableLevelDebug(void) {
  return FIRIsLoggableLevel(FIRLoggerLevelDebug, NO);
}

void FIRLogBasic(FIRLoggerLevel level,
                 NSString *category,
                 NSString *messageCode,
                 NSString *message,
                 va_list args_ptr) {
  FIRLoggerInitialize();
  GULOSLogBasic((GULLoggerLevel)level, kFIRLoggerSubsystem, category,
                sFIRAnalyticsDebugMode && [kFIRLoggerAnalytics isEqualToString:category],
                messageCode, message, args_ptr);
}

#define FIR_LOGGING_FUNCTION_BASIC(level)                                               \
  void FIRLogBasic##level(NSString *category, NSString *messageCode, NSString *message, \
                          va_list args_ptr) {                                           \
    FIRLogBasic(FIRLoggerLevel##level, category, messageCode, message, args_ptr);       \
  }

FIR_LOGGING_FUNCTION_BASIC(Error)
FIR_LOGGING_FUNCTION_BASIC(Warning)
FIR_LOGGING_FUNCTION_BASIC(Notice)
FIR_LOGGING_FUNCTION_BASIC(Info)
FIR_LOGGING_FUNCTION_BASIC(Debug)

/**
 * Generates the logging functions using macros.
 *
 * Calling FIRLogError(kFIRLoggerCore, @"I-COR000001", @"Configure %@ failed.", @"blah") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Error> [Firebase/Core][I-COR000001] Configure blah failed.
 * Calling FIRLogDebug(kFIRLoggerCore, @"I-COR000001", @"Configure succeed.") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Debug> [Firebase/Core][I-COR000001] Configure succeed.
 */
#define FIR_LOGGING_FUNCTION(level)                                                       \
  void FIRLog##level(NSString *category, NSString *messageCode, NSString *message, ...) { \
    va_list args_ptr;                                                                     \
    va_start(args_ptr, message);                                                          \
    FIRLogBasic(FIRLoggerLevel##level, category, messageCode, message, args_ptr);         \
    va_end(args_ptr);                                                                     \
  }

FIR_LOGGING_FUNCTION(Error)
FIR_LOGGING_FUNCTION(Warning)
FIR_LOGGING_FUNCTION(Notice)
FIR_LOGGING_FUNCTION(Info)
FIR_LOGGING_FUNCTION(Debug)

#undef FIR_LOGGING_FUNCTION

#pragma mark - FIRLoggerWrapper

@implementation FIRLoggerWrapper

+ (void)logWithLevel:(FIRLoggerLevel)level
             service:(NSString *)service
                code:(NSString *)code
             message:(NSString *)message {
  FIRLogBasic(level, service, code, message, NULL);
}

@end