// Copyright 2019 Google
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

#include "Crashlytics/Crashlytics/Components/FIRCLSHost.h"

#include <mach/mach.h>
#include <sys/mount.h>
#include <sys/sysctl.h>

#import "Crashlytics/Crashlytics/Components/FIRCLSApplication.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSDefines.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSFile.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSUtility.h"
#import "Crashlytics/Shared/FIRCLSFABHost.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#define CLS_HOST_SYSCTL_BUFFER_SIZE (128)
#define CLS_MAX_ARM64_NATIVE_PAGE_SIZE (1024 * 16)

#if CLS_CPU_ARM64
#define CLS_MAX_NATIVE_PAGE_SIZE CLS_MAX_ARM64_NATIVE_PAGE_SIZE
#else
// return 4K, which is correct for all platforms except arm64, currently
#define CLS_MAX_NATIVE_PAGE_SIZE (1024 * 4)
#endif
#define CLS_MIN_NATIVE_PAGE_SIZE (1024 * 4)

#pragma mark Prototypes
static void FIRCLSHostWriteSysctlEntry(
    FIRCLSFile* file, const char* key, const char* sysctlKey, void* buffer, size_t bufferSize);
static void FIRCLSHostWriteModelInfo(FIRCLSFile* file);
static void FIRCLSHostWriteOSVersionInfo(FIRCLSFile* file);

#pragma mark - API
void FIRCLSHostInitialize(FIRCLSHostReadOnlyContext* roContext) {
  _firclsContext.readonly->host.pageSize = FIRCLSHostGetPageSize();
  _firclsContext.readonly->host.documentDirectoryPath = NULL;

  // determine where the document directory is mounted, so we can get file system statistics later
  NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  if ([paths count]) {
    _firclsContext.readonly->host.documentDirectoryPath =
        FIRCLSDupString([[paths objectAtIndex:0] fileSystemRepresentation]);
  }
}

vm_size_t FIRCLSHostGetPageSize(void) {
  size_t size;
  int pageSize;

  // hw.pagesize is defined as HW_PAGESIZE, which is an int. It's important to match
  // these types. Turns out that sysctl will not init the data to zero, but it appears
  // that sysctlbyname does. This API is nicer, but that's important to keep in mind.

  int maxNativePageSize = CLS_MAX_NATIVE_PAGE_SIZE;

  // On Apple Silicon, we need to use the arm64 page size
  // even if we're in x86 land.
  if (FIRCLSHostIsRosettaTranslated()) {
    FIRCLSSDKLog("Running under Rosetta 2 emulation. Using the arm64 page size.\n");

    maxNativePageSize = CLS_MAX_ARM64_NATIVE_PAGE_SIZE;
  }

  pageSize = 0;
  size = sizeof(pageSize);
  if (sysctlbyname("hw.pagesize", &pageSize, &size, NULL, 0) != 0) {
    FIRCLSSDKLog("sysctlbyname failed while trying to get hw.pagesize\n");

    return maxNativePageSize;
  }

  // if the returned size is not the expected value, abort
  if (size != sizeof(pageSize)) {
    return maxNativePageSize;
  }

  // put in some guards to make sure our size is reasonable
  if (pageSize > maxNativePageSize) {
    return maxNativePageSize;
  }

  if (pageSize < CLS_MIN_NATIVE_PAGE_SIZE) {
    return CLS_MIN_NATIVE_PAGE_SIZE;
  }

  return pageSize;
}

// This comes from the Apple documentation here:
// https://developer.apple.com/documentation/apple_silicon/about_the_rosetta_translation_environment
bool FIRCLSHostIsRosettaTranslated(void) {
#if TARGET_OS_MAC
  int result = 0;
  size_t size = sizeof(result);
  if (sysctlbyname("sysctl.proc_translated", &result, &size, NULL, 0) == -1) {
    // If we get an error, or 0, we're going to treat this as x86_64 macOS native
    if (errno == ENOENT) {
      return false;
    }
    // This is the error case
    FIRCLSSDKLog("sysctlbyname failed while trying to get sysctl.proc_translated for Rosetta 2 "
                 "translation\n");
    return false;
  }
  return result == 1;

#else
  return false;
#endif
}

static void FIRCLSHostWriteSysctlEntry(
    FIRCLSFile* file, const char* key, const char* sysctlKey, void* buffer, size_t bufferSize) {
  if (sysctlbyname(sysctlKey, buffer, &bufferSize, NULL, 0) != 0) {
    FIRCLSFileWriteHashEntryString(file, key, "(failed)");
    return;
  }

  FIRCLSFileWriteHashEntryString(file, key, buffer);
}

static void FIRCLSHostWriteModelInfo(FIRCLSFile* file) {
  FIRCLSFileWriteHashEntryString(file, "model", [FIRCLSHostModelInfo() UTF8String]);

  // allocate a static buffer for the sysctl values, which are typically
  // quite short
  char buffer[CLS_HOST_SYSCTL_BUFFER_SIZE];

#if TARGET_OS_EMBEDDED
  FIRCLSHostWriteSysctlEntry(file, "machine", "hw.model", buffer, CLS_HOST_SYSCTL_BUFFER_SIZE);
#else
  FIRCLSHostWriteSysctlEntry(file, "machine", "hw.machine", buffer, CLS_HOST_SYSCTL_BUFFER_SIZE);
  FIRCLSHostWriteSysctlEntry(file, "cpu", "machdep.cpu.brand_string", buffer,
                             CLS_HOST_SYSCTL_BUFFER_SIZE);
#endif
}

static void FIRCLSHostWriteOSVersionInfo(FIRCLSFile* file) {
  FIRCLSFileWriteHashEntryString(file, "os_build_version", [FIRCLSHostOSBuildVersion() UTF8String]);
  FIRCLSFileWriteHashEntryString(file, "os_display_version",
                                 [FIRCLSHostOSDisplayVersion() UTF8String]);
  FIRCLSFileWriteHashEntryString(file, "platform", [FIRCLSApplicationGetPlatform() UTF8String]);
  FIRCLSFileWriteHashEntryString(file, "firebase_platform",
                                 [FIRCLSApplicationGetFirebasePlatform() UTF8String]);
}

bool FIRCLSHostRecord(FIRCLSFile* file) {
  FIRCLSFileWriteSectionStart(file, "host");

  FIRCLSFileWriteHashStart(file);

  FIRCLSHostWriteModelInfo(file);
  FIRCLSHostWriteOSVersionInfo(file);
  FIRCLSFileWriteHashEntryString(file, "locale",
                                 [[[NSLocale currentLocale] localeIdentifier] UTF8String]);

  FIRCLSFileWriteHashEnd(file);

  FIRCLSFileWriteSectionEnd(file);

  return true;
}

void FIRCLSHostWriteDiskUsage(FIRCLSFile* file) {
  struct statfs tStats;

  FIRCLSFileWriteSectionStart(file, "storage");

  FIRCLSFileWriteHashStart(file);

  if (statfs(_firclsContext.readonly->host.documentDirectoryPath, &tStats) == 0) {
    FIRCLSFileWriteHashEntryUint64(file, "free", tStats.f_bavail * tStats.f_bsize);
    FIRCLSFileWriteHashEntryUint64(file, "total", tStats.f_blocks * tStats.f_bsize);
  }

  FIRCLSFileWriteHashEnd(file);

  FIRCLSFileWriteSectionEnd(file);
}
