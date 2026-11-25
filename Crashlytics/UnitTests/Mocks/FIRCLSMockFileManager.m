// Copyright 2020 Google LLC
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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockFileManager.h"

@interface FIRCLSMockFileManager ()

@property(nonatomic) NSMutableDictionary<NSString *, NSData *> *fileSystemDict;
@property(nonatomic) BOOL didFulfillRemoveExpectation;

@end

@implementation FIRCLSMockFileManager

@synthesize removeExpectation = _removeExpectation;

- (instancetype)init {
  self = [super init];
  if (!self) {
    return nil;
  }

  _fileSystemDict = [[NSMutableDictionary<NSString *, NSData *> alloc] init];

  return self;
}

- (void)setRemoveExpectation:(XCTestExpectation *)removeExpectation {
  @synchronized(self) {
    _removeExpectation = removeExpectation;
    _didFulfillRemoveExpectation = NO;
  }
}

- (XCTestExpectation *)removeExpectation {
  @synchronized(self) {
    return _removeExpectation;
  }
}

- (BOOL)removeItemAtPath:(NSString *)path {
  XCTestExpectation *expectationToFulfill = nil;
  @synchronized(self) {
    [self.fileSystemDict removeObjectForKey:path];

    self.removeCount += 1;

    // Fulfill the expectation at most once when we reach the expected remove count, without
    // clearing `_removeExpectation` since tests such as `FIRCLSSettingsTests` read
    // `self.fileManager.removeExpectation` when calling `waitForExpectations:`.
    if (_removeExpectation && !_didFulfillRemoveExpectation &&
        self.removeCount >= self.expectedRemoveCount) {
      expectationToFulfill = _removeExpectation;
      _didFulfillRemoveExpectation = YES;
    }
  }
  [expectationToFulfill fulfill];

  return YES;
}

- (BOOL)fileExistsAtPath:(NSString *)path {
  @synchronized(self) {
    return self.fileSystemDict[path] != nil;
  }
}

- (BOOL)createFileAtPath:(NSString *)path
                contents:(NSData *)data
              attributes:(NSDictionary<NSFileAttributeKey, id> *)attr {
  @synchronized(self) {
    self.fileSystemDict[path] = data;
  }
  return YES;
}

- (NSArray *)activePathContents {
  @synchronized(self) {
    NSMutableArray *pathsWithActive = [[NSMutableArray alloc] init];
    for (NSString *path in [_fileSystemDict allKeys]) {
      if ([path containsString:@"v5/reports/active"]) {
        [pathsWithActive addObject:path];
      }
    }

    return pathsWithActive;
  }
}

- (NSData *)dataWithContentsOfFile:(NSString *)path {
  @synchronized(self) {
    return self.fileSystemDict[path];
  }
}

- (void)enumerateFilesInDirectory:(NSString *)directory
                       usingBlock:(void (^)(NSString *filePath, NSString *extension))block {
  NSArray<NSString *> *allKeysSnapshot = nil;
  @synchronized(self) {
    allKeysSnapshot = [self.fileSystemDict.allKeys copy];
  }
  NSArray<NSString *> *filteredPaths = [allKeysSnapshot
      filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *path,
                                                                        NSDictionary *bindings) {
        return [path hasPrefix:directory];
      }]];

  for (NSString *path in filteredPaths) {
    NSString *extension;
    NSString *fullPath;

    // Skip files that start with a dot.  This is important, because if you try to move a .DS_Store
    // file, it will fail if the target directory also has a .DS_Store file in it.  Plus, its
    // wasteful, because we don't care about dot files.
    if ([path hasPrefix:@"."]) {
      continue;
    }

    extension = [path pathExtension];
    fullPath = [directory stringByAppendingPathComponent:path];
    if (block) {
      block(fullPath, extension);
    }
  }
}

@end
