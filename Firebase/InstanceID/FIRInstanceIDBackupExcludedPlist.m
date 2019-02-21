/*
 * Copyright 2019 Google
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

#import "FIRInstanceIDBackupExcludedPlist.h"

#import "FIRInstanceIDDefines.h"
#import "FIRInstanceIDLogger.h"

typedef enum : NSUInteger {
  FIRInstanceIDPlistDirectoryUnknown,
  FIRInstanceIDPlistDirectoryDocuments,
  FIRInstanceIDPlistDirectoryApplicationSupport,
} FIRInstanceIDPlistDirectory;

@interface FIRInstanceIDBackupExcludedPlist ()

@property(nonatomic, readwrite, copy) NSString *fileName;
@property(nonatomic, readwrite, copy) NSString *applicationSupportSubDirectory;
@property(nonatomic, readwrite, assign) BOOL fileInApplicationSupport;

@property(nonatomic, readwrite, strong) NSDictionary *cachedPlistContents;

@end

@implementation FIRInstanceIDBackupExcludedPlist

- (instancetype)initWithFileName:(NSString *)fileName
    applicationSupportSubDirectory:(NSString *)applicationSupportSubDirectory {
  self = [super init];
  if (self) {
    _fileName = [fileName copy];
    _applicationSupportSubDirectory = [applicationSupportSubDirectory copy];
    _fileInApplicationSupport =
        [self moveToApplicationSupportSubDirectory:applicationSupportSubDirectory];
  }
  return self;
}

- (BOOL)writeDictionary:(NSDictionary *)dict error:(NSError **)error {
  NSString *path = [self plistPathInDirectory:[self plistDirectory]];
  if (![dict writeToFile:path atomically:YES]) {
    FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeBackupExcludedPlist000,
                             @"Failed to write to %@.plist", self.fileName);
    return NO;
  }

  // Successfully wrote contents -- change the in-memory contents
  self.cachedPlistContents = [dict copy];

  _FIRInstanceIDDevAssert([[NSFileManager defaultManager] fileExistsAtPath:path],
                          @"Error writing data to non-backed up plist %@.plist", self.fileName);

  NSURL *URL = [NSURL fileURLWithPath:path];
  if (error) {
    *error = nil;
  }

  NSDictionary *preferences = [URL resourceValuesForKeys:@[ NSURLIsExcludedFromBackupKey ]
                                                   error:error];
  if ([preferences[NSURLIsExcludedFromBackupKey] boolValue]) {
    return YES;
  }

  BOOL success = [URL setResourceValue:@(YES) forKey:NSURLIsExcludedFromBackupKey error:error];
  if (!success) {
    FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeBackupExcludedPlist001,
                             @"Error excluding %@ from backup, %@", [URL lastPathComponent],
                             error ? *error : @"");
  }
  return success;
}

- (BOOL)deleteFile:(NSError **)error {
  BOOL success = YES;
  NSString *path = [self plistPathInDirectory:[self plistDirectory]];
  if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
    success = [[NSFileManager defaultManager] removeItemAtPath:path error:error];
  }
  // remove the in-memory contents
  self.cachedPlistContents = nil;
  return success;
}

- (NSDictionary *)contentAsDictionary {
  if (!self.cachedPlistContents) {
    NSString *path = [self plistPathInDirectory:[self plistDirectory]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
      self.cachedPlistContents = [[NSDictionary alloc] initWithContentsOfFile:path];
    }
  }
  return self.cachedPlistContents;
}

- (void)moveToApplicationSupportSubDirectory {
  self.fileInApplicationSupport =
      [self moveToApplicationSupportSubDirectory:self.applicationSupportSubDirectory];
}

- (BOOL)moveToApplicationSupportSubDirectory:(NSString *)subDirectoryName {
  NSArray *directoryPaths =
      NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *applicationSupportDirPath = directoryPaths.lastObject;
  NSArray *components = @[ applicationSupportDirPath, subDirectoryName ];
  NSString *subDirectoryPath = [NSString pathWithComponents:components];
  BOOL hasSubDirectory;
  if (![[NSFileManager defaultManager] fileExistsAtPath:subDirectoryPath
                                            isDirectory:&hasSubDirectory]) {
    // Cannot move to non-existent directory
    return NO;
  }

  if ([self doesFileExistInDirectory:FIRInstanceIDPlistDirectoryDocuments]) {
    NSString *oldPlistPath = [self plistPathInDirectory:FIRInstanceIDPlistDirectoryDocuments];
    NSString *newPlistPath =
        [self plistPathInDirectory:FIRInstanceIDPlistDirectoryApplicationSupport];
    if ([self doesFileExistInDirectory:FIRInstanceIDPlistDirectoryApplicationSupport]) {
      // File exists in both Documents and ApplicationSupport
      return NO;
    }
    NSError *moveError;
    if (![[NSFileManager defaultManager] moveItemAtPath:oldPlistPath
                                                 toPath:newPlistPath
                                                  error:&moveError]) {
      FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeBackupExcludedPlist002,
                               @"Failed to move file %@ from %@ to %@. Error: %@", self.fileName,
                               oldPlistPath, newPlistPath, moveError);
      return NO;
    }
  }
  // We moved the file if it existed, otherwise we didn't need to do anything
  return YES;
}

- (BOOL)doesFileExist {
  return [self doesFileExistInDirectory:[self plistDirectory]];
}

#pragma mark - Private

- (FIRInstanceIDPlistDirectory)plistDirectory {
  if (self.fileInApplicationSupport) {
    return FIRInstanceIDPlistDirectoryApplicationSupport;
  } else {
    return FIRInstanceIDPlistDirectoryDocuments;
  };
}

- (NSString *)plistPathInDirectory:(FIRInstanceIDPlistDirectory)directory {
  return [self pathWithName:self.fileName inDirectory:directory];
}

- (NSString *)pathWithName:(NSString *)plistName
               inDirectory:(FIRInstanceIDPlistDirectory)directory {
  NSArray *directoryPaths;
  NSArray *components = @[];
  NSString *plistNameWithExtension = [NSString stringWithFormat:@"%@.plist", plistName];
  switch (directory) {
    case FIRInstanceIDPlistDirectoryDocuments:
      directoryPaths =
          NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
      components = @[ directoryPaths.lastObject, plistNameWithExtension ];
      break;

    case FIRInstanceIDPlistDirectoryApplicationSupport:
      directoryPaths =
          NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
      components = @[
        directoryPaths.lastObject, self.applicationSupportSubDirectory, plistNameWithExtension
      ];
      break;

    default:
      FIRInstanceIDLoggerError(kFIRInstanceIDMessageCodeBackupExcludedPlistInvalidPlistEnum,
                               @"Invalid plist directory type: %lu", (unsigned long)directory);
      NSAssert(NO, @"Invalid plist directory type: %lu", (unsigned long)directory);
      break;
  }

  return [NSString pathWithComponents:components];
}

- (BOOL)doesFileExistInDirectory:(FIRInstanceIDPlistDirectory)directory {
  NSString *path = [self plistPathInDirectory:directory];
  return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

@end
