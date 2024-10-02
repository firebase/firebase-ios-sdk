// Copyright 2024 Google LLC
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

#import <Foundation/Foundation.h>
#include "Crashlytics/Crashlytics/Components/FIRCLSUserLogging.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"

#if SWIFT_PACKAGE
@import FirebaseCrashlyticsSwift;
#elif __has_include(<FirebaseCrashlytics/FirebaseCrashlytics-Swift.h>)
#import <FirebaseCrashlytics/FirebaseCrashlytics-Swift.h>
#elif __has_include("FirebaseCrashlytics-Swift.h")
// If frameworks are not available, fall back to importing the header as it
// should be findable from a header search path pointing to the build
// directory. See #12611 for more context.
#import "FirebaseCrashlytics-Swift.h"
#endif

@interface FIRCLSRolloutsPersistenceManager : NSObject <FIRCLSPersistenceLog>
@property(nonatomic, readonly) FIRCLSFileManager *fileManager;
@property(nonnull, nonatomic, readonly) dispatch_queue_t rolloutsLoggingQueue;
@end

@implementation FIRCLSRolloutsPersistenceManager
- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager
                           andQueue:(dispatch_queue_t)queue {
  self = [super init];
  if (!self) {
    return nil;
  }
  _fileManager = fileManager;

  if (!queue) {
    FIRCLSDebugLog(@"Failed to initialize FIRCLSRolloutsPersistenceManager, logging queue is nil");
    return nil;
  }
  _rolloutsLoggingQueue = queue;
  return self;
}

- (void)updateRolloutsStateToPersistenceWithRollouts:(NSData *_Nonnull)rollouts
                                            reportID:(NSString *_Nonnull)reportID {
  NSString *rolloutsPath = [[[_fileManager activePath] stringByAppendingPathComponent:reportID]
      stringByAppendingPathComponent:FIRCLSReportRolloutsFile];
  if (![_fileManager fileExistsAtPath:rolloutsPath]) {
    if (![_fileManager createFileAtPath:rolloutsPath contents:nil attributes:nil]) {
      FIRCLSDebugLog(@"Could not create rollouts.clsrecord file. Error was code: %d - message: %s",
                     errno, strerror(errno));
      return;
    }
  }

  NSFileHandle *rolloutsFile = [NSFileHandle fileHandleForUpdatingAtPath:rolloutsPath];

  if (!_rolloutsLoggingQueue) {
    FIRCLSDebugLog(@"Rollouts logging queue is dealloccated");
    return;
  }

  dispatch_async(_rolloutsLoggingQueue, ^{
    @try {
      [rolloutsFile seekToEndOfFile];
      NSMutableData *rolloutsWithNewLineData = [rollouts mutableCopy];
      [rolloutsWithNewLineData appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
      [rolloutsFile writeData:rolloutsWithNewLineData];
      [rolloutsFile closeFile];
    } @catch (NSException *exception) {
      FIRCLSDebugLog(@"Failed to write new rollouts. Exception name: %s - message: %s",
                     exception.name, exception.reason);
    }
  });
}

- (void)debugLogWithMessage:(NSString *_Nonnull)message {
  FIRCLSDebugLog(message);
}

@end
