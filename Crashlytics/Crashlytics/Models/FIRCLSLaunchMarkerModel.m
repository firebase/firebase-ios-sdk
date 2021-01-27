// Copyright 2021 Google LLC
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

#import "Crashlytics/Crashlytics/Models/FIRCLSLaunchMarkerModel.h"

#import "Crashlytics/Crashlytics/Helpers/FIRCLSInternalLogging.h"

@interface FIRCLSLaunchMarkerModel ()

@property(nonatomic, strong) FIRCLSFileManager *fileManager;

@end

@implementation FIRCLSLaunchMarkerModel

- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager {
  self = [super init];
  if (!self) {
    return nil;
  }

  _fileManager = fileManager;

  return self;
}

- (BOOL)checkForAndCreateLaunchMarker {
  BOOL launchFailure = [self launchFailureMarkerPresent];
  if (launchFailure) {
    FIRCLSDeveloperLog("Crashlytics:Crash",
                       @"Last launch failed: this may indicate a crash shortly after app launch.");
  } else {
    [self createLaunchFailureMarker];
  }

  return launchFailure;
}

- (NSString *)launchFailureMarkerPath {
  return [[_fileManager structurePath] stringByAppendingPathComponent:@"launchmarker"];
}

- (BOOL)createLaunchFailureMarker {
  // It's tempting to use - [NSFileManger createFileAtPath:contents:attributes:] here. But that
  // operation, even with empty/nil contents does a ton of work to write out nothing via a
  // temporarly file. This is a much faster implemenation.
  const char *path = [[self launchFailureMarkerPath] fileSystemRepresentation];

#if TARGET_OS_IPHONE
  /*
   * data-protected non-portable open(2) :
   * int open_dprotected_np(user_addr_t path, int flags, int class, int dpflags, int mode)
   */
  int fd = open_dprotected_np(path, O_WRONLY | O_CREAT | O_TRUNC, 4, 0, 0644);
#else
  int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
#endif
  if (fd == -1) {
    return NO;
  }

  return close(fd) == 0;
}

- (BOOL)launchFailureMarkerPresent {
  return [[_fileManager underlyingFileManager] fileExistsAtPath:[self launchFailureMarkerPath]];
}

- (BOOL)removeLaunchFailureMarker {
  return [_fileManager removeItemAtPath:[self launchFailureMarkerPath]];
}

@end
