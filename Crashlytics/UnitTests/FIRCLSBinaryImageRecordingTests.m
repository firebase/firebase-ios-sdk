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

#import <XCTest/XCTest.h>

#import "Crashlytics/Crashlytics/Components/FIRCLSBinaryImage.h"
#import "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSSharedContext.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"

#include <mach-o/dyld.h>
#include <dlfcn.h>

@interface FIRCLSBinaryImageRecordingTests : XCTestCase

@property(nonatomic, strong) NSString *reportPath;

@end

@implementation FIRCLSBinaryImageRecordingTests

/*
 # How to reproduce:

 run testInMemoryBinaryImageStore -> OK
 run testFileBinaryImageStore -> OK
 run testInMemoryBinaryImageStore then testFileBinaryImageStore -> FAIL

 # Bug description:

 testFileBinaryImageStore opens dylib empty.dylib, it takes some address im memory A
 FIRCLSBinaryImageChanged adds node with baseAddress A, writes it to nodes[i]
 testFileBinaryImageStore closes dylib empty.dylib, dyld reclaims memory A
 FIRCLSBinaryImageChanged removes node by zeroing all fields except baseAddress at nodes[i]

 testInMemoryBinaryImageStore opens empty_func.dylib, dyld reuses memory A
 FIRCLSBinaryImageChanged adds node with baseAddress A, writes it to nodes[i+1] // searchAddress == NULL
 testInMemoryBinaryImageStore closes dylib empty_func.dylib, dyld reclaims memory A
 FIRCLSBinaryImageChanged removes node by zeroing all fields except baseAddress at nodes[i] // not at i+1
 FIRCLSBinaryImageSafeFindImageForAddress traverses array of nodes with condition 'address < node->baseAddress + node->size'
  and finds nodes[i+1] which is not empty and returns true

 memory A may be reused by another dylib and will be stored at nodes[i+2], but after unload empty_func.dylib nodes[i] will be deleted
 FIRCLSBinaryImageSafeFindImageForAddress will find nodes[i+1] in that case
 */

- (void)setUp {
  [super setUp];

  self.reportPath = [FIRCLSSharedContext shared].reportPath;
}

+ (NSString *)pathToFileNamed:(NSString *)name {
  NSString *resourcePath = [[NSBundle bundleForClass:[self class]] resourcePath];
  XCTAssertNotNil(resourcePath);
  NSString *path = [resourcePath stringByAppendingPathComponent:name];
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:path]);
  return path;
}

- (void)testFileBinaryImageStore {
  NSString *imageStorePath = [self.reportPath stringByAppendingPathComponent:FIRCLSReportBinaryImageFile];
  XCTAssertTrue(strcmp(imageStorePath.fileSystemRepresentation,
                       _firclsContext.readonly->binaryimage.path) == 0);

  NSString *dylibPath = [self.class pathToFileNamed:@"empty.dylib"];
  void *handle = dlopen(dylibPath.fileSystemRepresentation, RTLD_NOW);
  XCTAssertTrue(handle != NULL);
  __auto_type getRecords = ^NSArray<NSString *> *(void) {
    return [[NSString stringWithContentsOfFile:imageStorePath
                                      encoding:NSUTF8StringEncoding
                                         error:NULL]
            componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
  };

  __block NSString *imageInfoString = nil;

  dispatch_sync(FIRCLSGetBinaryImageQueue(), ^{
    FIRCLSFileFlushWriteBuffer(&_firclsContext.writable->binaryImage.file);
    __block NSRange dylibRecordPrefix = NSMakeRange(NSNotFound, 0);
    [getRecords() enumerateObjectsUsingBlock:^(NSString *record, NSUInteger idx, BOOL *stop) {
      dylibRecordPrefix = [record rangeOfString:[NSString stringWithFormat:@"{\"load\":{\"path\":\"%@\",", dylibPath]];
      if (dylibRecordPrefix.location != NSNotFound) {
        *stop = true;
        imageInfoString = [record substringWithRange:NSMakeRange(dylibRecordPrefix.length, record.length - dylibRecordPrefix.length)];
      }
    }];
    XCTAssertTrue(dylibRecordPrefix.location != NSNotFound, @"%@ does not contain information about loaded dylib", imageStorePath);
    XCTAssertTrue(dylibRecordPrefix.location == 0, @"clsrecord format error");
  });

  dlclose(handle);

  dispatch_sync(FIRCLSGetBinaryImageQueue(), ^{
    FIRCLSFileFlushWriteBuffer(&_firclsContext.writable->binaryImage.file);
    __block bool containsUnloadRecord = false;
    [getRecords() enumerateObjectsUsingBlock:^(NSString *record, NSUInteger idx, BOOL *stop) {
      if ([record hasPrefix:@"{\"unload\":{\"path\":null,"]) {
        containsUnloadRecord = [record hasSuffix:imageInfoString];
        if (containsUnloadRecord) *stop = true;
      }
    }];
    XCTAssertTrue(containsUnloadRecord, @"%@ does not contain information about unloaded dylib", imageStorePath);
  });
}

- (void)testInMemoryBinaryImageStore {
  NSString *dylibPath = [self.class pathToFileNamed:@"empty_func.dylib"];
  void *handle = dlopen(dylibPath.fileSystemRepresentation, RTLD_NOW);
  XCTAssertTrue(handle != NULL);

  __block uintptr_t dylibStartAddress;

  dispatch_sync(FIRCLSGetBinaryImageQueue(), ^{
    void* sym = dlsym(handle, "empty");
    XCTAssertTrue(sym != NULL, @"%s", dlerror());

    Dl_info image_info;
    memset(&image_info, 0, sizeof(Dl_info));
    dladdr(sym, &image_info);
    dylibStartAddress = (uintptr_t) image_info.dli_fbase;

    FIRCLSBinaryImageRuntimeNode image;
    memset(&image, 0, sizeof(FIRCLSBinaryImageRuntimeNode));
    XCTAssertTrue(FIRCLSBinaryImageSafeFindImageForAddress(dylibStartAddress, &image));
    XCTAssertTrue(image.size > 0 && image.unwindInfo != NULL);
  });

  dlclose(handle);

  dispatch_sync(FIRCLSGetBinaryImageQueue(), ^{
    FIRCLSBinaryImageRuntimeNode image;
    memset(&image, 0, sizeof(FIRCLSBinaryImageRuntimeNode));
    XCTAssertFalse(FIRCLSBinaryImageSafeFindImageForAddress(dylibStartAddress, &image));
  });
}

@end
