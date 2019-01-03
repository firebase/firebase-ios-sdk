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

#import "GDLLogWriter.h"
#import "GDLLogWriter_Private.h"

#import <GoogleDataLogger/GDLLogTransformer.h>

#import "GDLAssert.h"
#import "GDLConsoleLogger.h"
#import "GDLLogEvent_Private.h"
#import "GDLLogStorage.h"

@implementation GDLLogWriter

// This class doesn't have to be a singleton, but allocating an instance for every logger could be
// wasteful.
+ (instancetype)sharedInstance {
  static GDLLogWriter *logWriter;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    logWriter = [[self alloc] init];
  });
  return logWriter;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _logWritingQueue = dispatch_queue_create("com.google.GDLLogWriter", DISPATCH_QUEUE_SERIAL);
    _storageInstance = [GDLLogStorage sharedInstance];
  }
  return self;
}

- (void)writeLog:(GDLLogEvent *)log
    afterApplyingTransformers:(NSArray<id<GDLLogTransformer>> *)logTransformers {
  GDLAssert(log, @"You can't write a nil log");
  dispatch_async(_logWritingQueue, ^{
    GDLLogEvent *transformedLog = log;
    for (id<GDLLogTransformer> transformer in logTransformers) {
      if ([transformer respondsToSelector:@selector(transform:)]) {
        transformedLog = [transformer transform:transformedLog];
        if (!transformedLog) {
          return;
        }
      } else {
        GDLLogError(GDLMCETransformerDoesntImplementTransform,
                    @"Transformer doesn't implement transform: %@", transformer);
        return;
      }
    }
    [self.storageInstance storeLog:transformedLog];
  });
}

@end
