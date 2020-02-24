/*
 * Copyright 2017 Google
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

#import <FirebaseCore/FIRLogger.h>
#import <Foundation/Foundation.h>

#import "FParsedUrl.h"

@interface FUtilities : NSObject

+ (NSArray *)splitString:(NSString *)str intoMaxSize:(const unsigned int)size;
+ (NSNumber *)LUIDGenerator;
+ (FParsedUrl *)parseUrl:(NSString *)url;
+ (NSString *)getJavascriptType:(id)obj;
+ (NSError *)errorForStatus:(NSString *)status andReason:(NSString *)reason;
+ (NSNumber *)intForString:(NSString *)string;
+ (NSString *)ieee754StringForNumber:(NSNumber *)val;

+ (NSString *)minName;
+ (NSString *)maxName;
+ (NSComparisonResult)compareKey:(NSString *)a toKey:(NSString *)b;
+ (NSComparator)stringComparator;
+ (NSComparator)keyComparator;

+ (double)randomDouble;

@end

// Log tags
FOUNDATION_EXPORT NSString *const kFPersistenceLogTag;

#define FFLog(code, format, ...) FFDebug((code), (format), ##__VA_ARGS__)

#define FFDebug(code, format, ...)                                             \
    do {                                                                       \
        FIRLogDebug(kFIRLoggerDatabase, (code), (format), ##__VA_ARGS__);      \
    } while (0)

#define FFInfo(code, format, ...)                                              \
    do {                                                                       \
        FIRLogError(kFIRLoggerDatabase, (code), (format), ##__VA_ARGS__);      \
    } while (0)

#define FFWarn(code, format, ...)                                              \
    do {                                                                       \
        FIRLogWarning(kFIRLoggerDatabase, (code), (format), ##__VA_ARGS__);    \
    } while (0)

extern FIRLoggerService kFIRLoggerDatabase;
void firebaseUncaughtExceptionHandler(NSException *exception);
void firebaseJobsTroll(void);
