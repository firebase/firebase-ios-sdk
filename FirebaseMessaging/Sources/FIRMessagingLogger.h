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

#import "FirebaseMessaging/Sources/FIRMessagingCode.h"

// The convenience macros are only defined if they haven't already been defined.
#ifndef FIRMessagingLoggerInfo

// Convenience macros that log to the shared FIRMessagingLogger instance. These macros
// are how users should typically log to FIRMessagingLogger.
#define FIRMessagingLoggerDebug(code, ...) \
  [FIRMessagingSharedLogger() logFuncDebug:__func__ messageCode:code msg:__VA_ARGS__]
#define FIRMessagingLoggerInfo(code, ...) \
  [FIRMessagingSharedLogger() logFuncInfo:__func__ messageCode:code msg:__VA_ARGS__]
#define FIRMessagingLoggerNotice(code, ...) \
  [FIRMessagingSharedLogger() logFuncNotice:__func__ messageCode:code msg:__VA_ARGS__]
#define FIRMessagingLoggerWarn(code, ...) \
  [FIRMessagingSharedLogger() logFuncWarning:__func__ messageCode:code msg:__VA_ARGS__]
#define FIRMessagingLoggerError(code, ...) \
  [FIRMessagingSharedLogger() logFuncError:__func__ messageCode:code msg:__VA_ARGS__]

#endif  // !defined(FIRMessagingLoggerInfo)

@interface FIRMessagingLogger : NSObject

- (void)logFuncDebug:(const char *)func
         messageCode:(FIRMessagingMessageCode)messageCode
                 msg:(NSString *)fmt, ... NS_FORMAT_FUNCTION(3, 4);

- (void)logFuncInfo:(const char *)func
        messageCode:(FIRMessagingMessageCode)messageCode
                msg:(NSString *)fmt, ... NS_FORMAT_FUNCTION(3, 4);

- (void)logFuncNotice:(const char *)func
          messageCode:(FIRMessagingMessageCode)messageCode
                  msg:(NSString *)fmt, ... NS_FORMAT_FUNCTION(3, 4);

- (void)logFuncWarning:(const char *)func
           messageCode:(FIRMessagingMessageCode)messageCode
                   msg:(NSString *)fmt, ... NS_FORMAT_FUNCTION(3, 4);

- (void)logFuncError:(const char *)func
         messageCode:(FIRMessagingMessageCode)messageCode
                 msg:(NSString *)fmt, ... NS_FORMAT_FUNCTION(3, 4);

@end

/**
 * Instantiates and/or returns a shared FIRMessagingLogger used exclusively
 * for FIRMessaging log messages.
 *
 * @return the shared FIRMessagingLogger instance
 */
FIRMessagingLogger *FIRMessagingSharedLogger(void);
