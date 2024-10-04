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

#import "FirebaseCore/Sources/FIRConfigurationInternal.h"

#import "FirebaseCore/Sources/FIRAnalyticsConfiguration.h"

extern void FIRSetLoggerLevel(FIRLoggerLevel loggerLevel);
extern FIRLoggerLevel FIRGetLoggerLevel(void);

@interface FIRConfiguration ()
@property(nonatomic, readonly) dispatch_queue_t queue;
@end

@implementation FIRConfiguration

+ (instancetype)sharedInstance {
  static FIRConfiguration *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FIRConfiguration alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _queue = dispatch_queue_create("com.firebase.FIRConfiguration", DISPATCH_QUEUE_SERIAL);
    _analyticsConfiguration = [FIRAnalyticsConfiguration sharedInstance];
  }
  return self;
}

- (void)setLoggerLevel:(FIRLoggerLevel)loggerLevel {
  NSAssert(loggerLevel <= FIRLoggerLevelMax && loggerLevel >= FIRLoggerLevelMin,
           @"Invalid logger level, %ld", (long)loggerLevel);
  dispatch_sync(self.queue, ^{
    FIRSetLoggerLevel(loggerLevel);
  });
}

- (FIRLoggerLevel)loggerLevel {
  __block FIRLoggerLevel level;
  dispatch_sync(self.queue, ^{
    level = FIRGetLoggerLevel();
  });
  return level;
}

@end
