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

#import "FIRMessagingFileLogger.h"

#if FIRMessaging_PROBER

#import "DDFileLogger.h"
#import "DDLog.h"

@interface FIRMessagingFileLogFilter ()

@property(nonatomic, readwrite, assign) FIRMessagingLogLevel level;
@end

@implementation FIRMessagingFileLogFilter

#pragma mark - GTMLogFilter protocol

- (BOOL)filterAllowsMessage:(NSString *)msg level:(FIRMessagingLogLevel)level {
  // allow everything
  return YES;
}

@end

@interface FIRMessagingFileLogFormatter ()

@property(nonatomic, readwrite, strong) NSDateFormatter *dateFormatter;

@end

@implementation FIRMessagingFileLogFormatter

static NSString *const kFIRMessagingLogPrefix = @"FIRMessaging";

- (id)init {
  if ((self = [super init])) {
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
  }
  return self;
}

#pragma mark - GTMLogFormatter protocol

static DDLogMessage *currentMessage;
- (NSString *)stringForFunc:(NSString *)func
                 withFormat:(NSString *)fmt
                     valist:(va_list)args
                      level:(FIRMessagingLogLevel)level {
  NSString *logMessage = [[NSString alloc] initWithFormat:fmt arguments:args];
  currentMessage = [[DDLogMessage alloc] initWithMessage:logMessage
                                                   level:0
                                                    flag:0
                                                 context:0
                                                    file:NULL
                                                function:NULL
                                                    line:0
                                                     tag:0
                                                 options:0
                                               timestamp:[NSDate date]];
  return logMessage;
}

@end

@interface FIRMessagingFileLogWriter ()

@property(nonatomic, readwrite, strong) DDFileLogger *fileLogger;

@end

@implementation FIRMessagingFileLogWriter

- (instancetype)init {
  self = [super init];
  if (self) {
    _fileLogger = [[DDFileLogger alloc] init];
  }
  return self;
}

#pragma mark - GTMLogWriter protocol

- (void)logMessage:(NSString *)msg level:(FIRMessagingLogLevel)level {
  // log to stdout
  NSLog(@"%@", msg);
  [self.fileLogger logMessage:currentMessage];
}

@end

#endif
