//
//  FIRCLSLaunchMarker.m
//  Pods
//
//  Created by Sam Edson on 1/25/21.
//

#import "FIRCLSLaunchMarker.h"

#import "Crashlytics/Crashlytics/Helpers/FIRCLSInternalLogging.h"

@interface FIRCLSLaunchMarker ()

@property(nonatomic, strong) FIRCLSFileManager *fileManager;

@end

@implementation FIRCLSLaunchMarker

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
