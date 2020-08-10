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

@end

@implementation FIRCLSMockFileManager

- (instancetype)init {
  self = [super init];
  if (!self) {
    return nil;
  }

  _fileSystemDict = [[NSMutableDictionary<NSString *, NSData *> alloc] init];

  return self;
}

- (BOOL)removeItemAtPath:(NSString *)path {
  [self.fileSystemDict removeObjectForKey:path];

  self.removeCount += 1;

  // If we set up the expectation, and we went over the expected count or removes, fulfill the
  // expectation
  if (self.removeExpectation && self.removeCount >= self.expectedRemoveCount) {
    [self.removeExpectation fulfill];
  }

  return YES;
}

- (BOOL)fileExistsAtPath:(NSString *)path {
  return self.fileSystemDict[path] != nil;
}

- (BOOL)createFileAtPath:(NSString *)path
                contents:(NSData *)data
              attributes:(NSDictionary<NSFileAttributeKey, id> *)attr {
  self.fileSystemDict[path] = data;
  return YES;
}

- (NSData *)dataWithContentsOfFile:(NSString *)path {
  return self.fileSystemDict[path];
}

- (void)enumerateFilesInDirectory:(NSString *)directory
                       usingBlock:(void (^)(NSString *filePath, NSString *extension))block {
  NSArray<NSString *> *filteredPaths = [self.fileSystemDict.allKeys
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
