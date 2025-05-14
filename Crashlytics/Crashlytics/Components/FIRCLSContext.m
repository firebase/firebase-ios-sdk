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

#include "Crashlytics/Crashlytics/Components/FIRCLSContext.h"

#include <stdlib.h>
#include <string.h>

#import "Crashlytics/Shared/FIRCLSConstants.h"

#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInstallIdentifierModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"

#include "Crashlytics/Crashlytics/Components/FIRCLSApplication.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSCrashedMarkerFile.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSProcess.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSContextInitData.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSDefines.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSFeatures.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSUtility.h"

// The writable size is our handler stack plus whatever scratch we need.  We have to use this space
// extremely carefully, however, because thread stacks always needs to be page-aligned.  Only the
// first allocation is guaranteed to be page-aligned.
//
// CLS_SIGNAL_HANDLER_STACK_SIZE and CLS_MACH_EXCEPTION_HANDLER_STACK_SIZE are platform dependant,
// defined as 0 for tv/watch.
#define CLS_MINIMUM_READWRITE_SIZE                                         \
  (CLS_SIGNAL_HANDLER_STACK_SIZE + CLS_MACH_EXCEPTION_HANDLER_STACK_SIZE + \
   sizeof(FIRCLSReadWriteContext))

// We need enough space here for the context, plus storage for strings.
#define CLS_MINIMUM_READABLE_SIZE (sizeof(FIRCLSReadOnlyContext) + 4096 * 4)

static const char* FIRCLSContextAppendToRoot(NSString* root, NSString* component);
static void FIRCLSContextAllocate(FIRCLSContext* context);

FIRCLSContextInitData* FIRCLSContextBuildInitData(FIRCLSInternalReport* report,
                                                  FIRCLSSettings* settings,
                                                  FIRCLSFileManager* fileManager,
                                                  NSString* appQualitySessionId) {
  // Because we need to start the crash reporter right away,
  // it starts up either with default settings, or cached settings
  // from the last time they were fetched

  FIRCLSContextInitData* initData = [[FIRCLSContextInitData alloc] init];
  initData.customBundleId = nil;
  initData.sessionId = [report identifier];
  initData.appQualitySessionId = appQualitySessionId;
  initData.rootPath = [report path];
  initData.previouslyCrashedFileRootPath = [fileManager rootPath];
  initData.errorsEnabled = [settings errorReportingEnabled];
  initData.customExceptionsEnabled = [settings customExceptionsEnabled];
  initData.maxCustomExceptions = [settings maxCustomExceptions];
  initData.maxErrorLogSize = [settings errorLogBufferSize];
  initData.maxLogSize = [settings logBufferSize];
  initData.maxKeyValues = [settings maxCustomKeys];
  initData.betaToken = @"";

  return initData;
}

FBLPromise* FIRCLSContextInitialize(FIRCLSContextInitData* initData,
                                    FIRCLSFileManager* fileManager) {
  if (!initData) {
    return false;
  }

  FIRCLSContextBaseInit();

  dispatch_group_t group = dispatch_group_create();
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

  if (!FIRCLSIsValidPointer(initData.rootPath)) {
    return false;
  }

  NSString* rootPath = initData.rootPath;

  // setup our SDK log file synchronously, because other calls may depend on it
  _firclsContext.readonly->logPath = FIRCLSContextAppendToRoot(rootPath, @"sdk.log");
  _firclsContext.readonly->initialReportPath = FIRCLSDupString([[initData rootPath] UTF8String]);
  if (!FIRCLSUnlinkIfExists(_firclsContext.readonly->logPath)) {
    FIRCLSErrorLog(@"Unable to write initialize SDK write paths %s", strerror(errno));
  }

  // some values that aren't tied to particular subsystem
  _firclsContext.readonly->debuggerAttached = FIRCLSProcessDebuggerAttached();

  __block FBLPromise* initPromise = [FBLPromise pendingPromise];

  dispatch_group_async(group, queue, ^{
    FIRCLSHostInitialize(&_firclsContext.readonly->host);
  });

  dispatch_group_async(group, queue, ^{
    _firclsContext.readonly->logging.errorStorage.maxSize = 0;
    _firclsContext.readonly->logging.errorStorage.maxEntries =
        initData.errorsEnabled ? initData.maxCustomExceptions : 0;
    _firclsContext.readonly->logging.errorStorage.restrictBySize = false;
    _firclsContext.readonly->logging.errorStorage.entryCount =
        &_firclsContext.writable->logging.errorsCount;
    _firclsContext.readonly->logging.errorStorage.aPath =
        FIRCLSContextAppendToRoot(rootPath, FIRCLSReportErrorAFile);
    _firclsContext.readonly->logging.errorStorage.bPath =
        FIRCLSContextAppendToRoot(rootPath, FIRCLSReportErrorBFile);

    _firclsContext.readonly->logging.logStorage.maxSize = initData.maxLogSize;
    _firclsContext.readonly->logging.logStorage.maxEntries = 0;
    _firclsContext.readonly->logging.logStorage.restrictBySize = true;
    _firclsContext.readonly->logging.logStorage.entryCount = NULL;
    _firclsContext.readonly->logging.logStorage.aPath =
        FIRCLSContextAppendToRoot(rootPath, FIRCLSReportLogAFile);
    _firclsContext.readonly->logging.logStorage.bPath =
        FIRCLSContextAppendToRoot(rootPath, FIRCLSReportLogBFile);
    _firclsContext.readonly->logging.customExceptionStorage.aPath =
        FIRCLSContextAppendToRoot(rootPath, FIRCLSReportCustomExceptionAFile);
    _firclsContext.readonly->logging.customExceptionStorage.bPath =
        FIRCLSContextAppendToRoot(rootPath, FIRCLSReportCustomExceptionBFile);
    _firclsContext.readonly->logging.customExceptionStorage.maxSize = 0;
    _firclsContext.readonly->logging.customExceptionStorage.restrictBySize = false;
    _firclsContext.readonly->logging.customExceptionStorage.maxEntries =
        initData.maxCustomExceptions;
    _firclsContext.readonly->logging.customExceptionStorage.entryCount =
        &_firclsContext.writable->exception.customExceptionCount;

    _firclsContext.readonly->logging.userKVStorage.maxCount = initData.maxKeyValues;
    _firclsContext.readonly->logging.userKVStorage.incrementalPath =
        FIRCLSContextAppendToRoot(rootPath, FIRCLSReportUserIncrementalKVFile);
    _firclsContext.readonly->logging.userKVStorage.compactedPath =
        FIRCLSContextAppendToRoot(rootPath, FIRCLSReportUserCompactedKVFile);

    _firclsContext.readonly->logging.internalKVStorage.maxCount = 32;  // Hardcode = bad
    _firclsContext.readonly->logging.internalKVStorage.incrementalPath =
        FIRCLSContextAppendToRoot(rootPath, FIRCLSReportInternalIncrementalKVFile);
    _firclsContext.readonly->logging.internalKVStorage.compactedPath =
        FIRCLSContextAppendToRoot(rootPath, FIRCLSReportInternalCompactedKVFile);

    FIRCLSUserLoggingInit(&_firclsContext.readonly->logging, &_firclsContext.writable->logging);
  });

  dispatch_group_async(group, queue, ^{
    _firclsContext.readonly->binaryimage.path =
        FIRCLSContextAppendToRoot(rootPath, FIRCLSReportBinaryImageFile);

    FIRCLSBinaryImageInit();
  });

  dispatch_group_async(group, queue, ^{
    NSString* rootPath = initData.previouslyCrashedFileRootPath;
    NSString* fileName = [NSString stringWithUTF8String:FIRCLSCrashedMarkerFileName];
    _firclsContext.readonly->previouslyCrashedFileFullPath =
        FIRCLSContextAppendToRoot(rootPath, fileName);
  });

  // To initialize Crashlytics handlers even if the Xcode debugger is attached, replace this check
  // with YES. Note that this is only possible to do on an actual device as it will cause the
  // simulator to crash.
  if (!_firclsContext.readonly->debuggerAttached) {
#if CLS_SIGNAL_SUPPORTED
    dispatch_group_async(group, queue, ^{
      _firclsContext.readonly->signal.path =
          FIRCLSContextAppendToRoot(rootPath, FIRCLSReportSignalFile);

      FIRCLSSignalInitialize(&_firclsContext.readonly->signal);
    });
#endif

#if CLS_MACH_EXCEPTION_SUPPORTED
    dispatch_group_async(group, queue, ^{
      _firclsContext.readonly->machException.path =
          FIRCLSContextAppendToRoot(rootPath, FIRCLSReportMachExceptionFile);

      FIRCLSMachExceptionInit(&_firclsContext.readonly->machException);
    });
#endif

    dispatch_group_async(group, queue, ^{
      _firclsContext.readonly->exception.path =
          FIRCLSContextAppendToRoot(rootPath, FIRCLSReportExceptionFile);
      _firclsContext.readonly->exception.maxCustomExceptions =
          initData.customExceptionsEnabled ? initData.maxCustomExceptions : 0;

      FIRCLSExceptionInitialize(&_firclsContext.readonly->exception,
                                &_firclsContext.writable->exception);
    });
  } else {
    FIRCLSSDKLog("Debugger present - not installing handlers\n");
  }

  dispatch_group_async(group, queue, ^{
    if (!FIRCLSContextRecordMetadata(rootPath, initData)) {
      FIRCLSSDKLog("Unable to record context metadata\n");
    }
  });

  // At this point we need to do two things. First, we need to do our memory protection *only* after
  // all of these initialization steps are really done. But, we also want to wait as long as
  // possible for these to be complete. If we do not, there's a chance that we will not be able to
  // correctly report a crash shortly after start.

  // Note at this will retain the group, so its totally fine to release the group here.
  dispatch_group_notify(group, queue, ^{
    _firclsContext.readonly->initialized = true;
    __sync_synchronize();

    if (!FIRCLSAllocatorProtect(_firclsContext.allocator)) {
      FIRCLSSDKLog("Error: Memory protection failed\n");
    }
    [initPromise fulfill:nil];
  });

  return initPromise;
}

void FIRCLSContextBaseInit(void) {
  NSString* sdkBundleID = FIRCLSApplicationGetSDKBundleID();

  NSString* loggingQueueName = [sdkBundleID stringByAppendingString:@".logging"];
  NSString* binaryImagesQueueName = [sdkBundleID stringByAppendingString:@".binary-images"];
  NSString* exceptionQueueName = [sdkBundleID stringByAppendingString:@".exception"];

  _firclsLoggingQueue = dispatch_queue_create([loggingQueueName UTF8String], DISPATCH_QUEUE_SERIAL);
  _firclsBinaryImageQueue =
      dispatch_queue_create([binaryImagesQueueName UTF8String], DISPATCH_QUEUE_SERIAL);
  _firclsExceptionQueue =
      dispatch_queue_create([exceptionQueueName UTF8String], DISPATCH_QUEUE_SERIAL);

  FIRCLSContextAllocate(&_firclsContext);

  _firclsContext.writable->internalLogging.logFd = -1;
  _firclsContext.writable->internalLogging.logLevel = FIRCLSInternalLogLevelDebug;
  _firclsContext.writable->crashOccurred = false;

  _firclsContext.readonly->initialized = false;

  __sync_synchronize();
}

static void FIRCLSContextAllocate(FIRCLSContext* context) {
  // create the allocator, and the contexts
  // The ordering here is really important, because the "stack" variable must be
  // page-aligned.  There's no mechanism to ask the allocator to do alignment, but we
  // do know the very first allocation in a region is aligned to a page boundary.

  context->allocator = FIRCLSAllocatorCreate(CLS_MINIMUM_READWRITE_SIZE, CLS_MINIMUM_READABLE_SIZE);

  context->readonly =
      FIRCLSAllocatorSafeAllocate(context->allocator, sizeof(FIRCLSReadOnlyContext), CLS_READONLY);
  memset(context->readonly, 0, sizeof(FIRCLSReadOnlyContext));

#if CLS_MEMORY_PROTECTION_ENABLED
#if CLS_MACH_EXCEPTION_SUPPORTED
  context->readonly->machStack = FIRCLSAllocatorSafeAllocate(
      context->allocator, CLS_MACH_EXCEPTION_HANDLER_STACK_SIZE, CLS_READWRITE);
#endif
#if CLS_USE_SIGALTSTACK
  context->readonly->signalStack =
      FIRCLSAllocatorSafeAllocate(context->allocator, CLS_SIGNAL_HANDLER_STACK_SIZE, CLS_READWRITE);
#endif
#else
#if CLS_MACH_EXCEPTION_SUPPORTED
  context->readonly->machStack = valloc(CLS_MACH_EXCEPTION_HANDLER_STACK_SIZE);
#endif
#if CLS_USE_SIGALTSTACK
  context->readonly->signalStack = valloc(CLS_SIGNAL_HANDLER_STACK_SIZE);
#endif
#endif

#if CLS_MACH_EXCEPTION_SUPPORTED
  memset(_firclsContext.readonly->machStack, 0, CLS_MACH_EXCEPTION_HANDLER_STACK_SIZE);
#endif
#if CLS_USE_SIGALTSTACK
  memset(_firclsContext.readonly->signalStack, 0, CLS_SIGNAL_HANDLER_STACK_SIZE);
#endif

  context->writable = FIRCLSAllocatorSafeAllocate(context->allocator,
                                                  sizeof(FIRCLSReadWriteContext), CLS_READWRITE);
  memset(context->writable, 0, sizeof(FIRCLSReadWriteContext));
}

void FIRCLSContextBaseDeinit(void) {
  _firclsContext.readonly->initialized = false;

  FIRCLSAllocatorDestroy(_firclsContext.allocator);
}

bool FIRCLSContextIsInitialized(void) {
  __sync_synchronize();
  if (!FIRCLSIsValidPointer(_firclsContext.readonly)) {
    return false;
  }

  return _firclsContext.readonly->initialized;
}

bool FIRCLSContextHasCrashed(void) {
  if (!FIRCLSContextIsInitialized()) {
    return false;
  }

  // we've already run a full barrier above, so this read is ok
  return _firclsContext.writable->crashOccurred;
}

void FIRCLSContextMarkHasCrashed(void) {
  if (!FIRCLSContextIsInitialized()) {
    return;
  }

  _firclsContext.writable->crashOccurred = true;
  __sync_synchronize();
}

bool FIRCLSContextMarkAndCheckIfCrashed(void) {
  if (!FIRCLSContextIsInitialized()) {
    return false;
  }

  if (_firclsContext.writable->crashOccurred) {
    return true;
  }

  _firclsContext.writable->crashOccurred = true;
  __sync_synchronize();

  return false;
}

static const char* FIRCLSContextAppendToRoot(NSString* root, NSString* component) {
  return FIRCLSDupString(
      [[root stringByAppendingPathComponent:component] fileSystemRepresentation]);
}

static bool FIRCLSContextRecordIdentity(FIRCLSFile* file,
                                        const char* sessionId,
                                        const char* betaToken,
                                        const char* appQualitySessionId) {
  FIRCLSFileWriteSectionStart(file, "identity");

  FIRCLSFileWriteHashStart(file);

  FIRCLSFileWriteHashEntryString(file, "generator", FIRCLSSDKGeneratorName().UTF8String);
  FIRCLSFileWriteHashEntryString(file, "display_version", FIRCLSSDKVersion().UTF8String);
  FIRCLSFileWriteHashEntryString(file, "build_version", FIRCLSSDKVersion().UTF8String);
  FIRCLSFileWriteHashEntryUint64(file, "started_at", time(NULL));

  FIRCLSFileWriteHashEntryString(file, "session_id", sessionId);
  FIRCLSFileWriteHashEntryString(file, "app_quality_session_id", appQualitySessionId);

  // install_id is written into the proto directly. This is only left here to
  // support Apple Report Converter.
  FIRCLSFileWriteHashEntryString(file, "install_id", "");
  FIRCLSFileWriteHashEntryString(file, "beta_token", betaToken);
  FIRCLSFileWriteHashEntryBoolean(file, "absolute_log_timestamps", true);

  FIRCLSFileWriteHashEnd(file);
  FIRCLSFileWriteSectionEnd(file);

  return true;
}

static bool FIRCLSContextRecordApplication(FIRCLSFile* file, const char* customBundleId) {
  FIRCLSFileWriteSectionStart(file, "application");

  FIRCLSFileWriteHashStart(file);

  FIRCLSFileWriteHashEntryString(file, "bundle_id",
                                 [FIRCLSApplicationGetBundleIdentifier() UTF8String]);
  FIRCLSFileWriteHashEntryString(file, "custom_bundle_id", customBundleId);
  FIRCLSFileWriteHashEntryString(file, "build_version",
                                 [FIRCLSApplicationGetBundleVersion() UTF8String]);
  FIRCLSFileWriteHashEntryString(file, "display_version",
                                 [FIRCLSApplicationGetShortBundleVersion() UTF8String]);
  FIRCLSFileWriteHashEntryString(file, "extension_id",
                                 [FIRCLSApplicationExtensionPointIdentifier() UTF8String]);

  FIRCLSFileWriteHashEnd(file);
  FIRCLSFileWriteSectionEnd(file);

  return true;
}

bool FIRCLSContextRecordMetadata(NSString* rootPath, const FIRCLSContextInitData* initData) {
  const char* sessionId = [[initData sessionId] UTF8String];
  const char* betaToken = [[initData betaToken] UTF8String];
  const char* customBundleId = [[initData customBundleId] UTF8String];
  const char* appQualitySessionId = [[initData appQualitySessionId] UTF8String];
  const char* path =
      [[rootPath stringByAppendingPathComponent:FIRCLSReportMetadataFile] fileSystemRepresentation];
  if (!FIRCLSUnlinkIfExists(path)) {
    FIRCLSSDKLog("Unable to unlink existing metadata file %s\n", strerror(errno));
  }

  FIRCLSFile file;

  if (!FIRCLSFileInitWithPath(&file, path, false)) {
    FIRCLSSDKLog("Unable to open metadata file %s\n", strerror(errno));
    return false;
  }

  if (!FIRCLSContextRecordIdentity(&file, sessionId, betaToken, appQualitySessionId)) {
    FIRCLSSDKLog("Unable to write out identity metadata\n");
  }

  if (!FIRCLSHostRecord(&file)) {
    FIRCLSSDKLog("Unable to write out host metadata\n");
  }

  if (!FIRCLSContextRecordApplication(&file, customBundleId)) {
    FIRCLSSDKLog("Unable to write out application metadata\n");
  }

  if (!FIRCLSBinaryImageRecordMainExecutable(&file)) {
    FIRCLSSDKLog("Unable to write out executable metadata\n");
  }

  FIRCLSFileClose(&file);

  return true;
}
