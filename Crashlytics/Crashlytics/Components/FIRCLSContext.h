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

#pragma once

#include "Crashlytics/Crashlytics/Components/FIRCLSBinaryImage.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSHost.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSUserLogging.h"
#include "Crashlytics/Crashlytics/Handlers/FIRCLSException.h"
#include "Crashlytics/Crashlytics/Handlers/FIRCLSMachException.h"
#include "Crashlytics/Crashlytics/Handlers/FIRCLSSignal.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSAllocate.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSFeatures.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSInternalLogging.h"

#include <dispatch/dispatch.h>
#include <stdbool.h>

// The purpose of the crash context is to hold values that absolutely must be read and/or written at
// crash time.  For robustness against memory corruption, they are protected with guard pages.
// Further, the context is separated into read-only and read-write sections.

__BEGIN_DECLS

#ifdef __OBJC__
@class FIRCLSInternalReport;
@class FIRCLSSettings;
@class FIRCLSInstallIdentifierModel;
@class FIRCLSFileManager;
@class FIRCLSContextInitData;
@class FBLPromise;
#endif

typedef struct {
  volatile bool initialized;
  volatile bool debuggerAttached;
  const char* previouslyCrashedFileFullPath;
  const char* logPath;
  // Initial report path represents the report path used to initialized the context;
  // where non-on-demand exceptions and other crashes will be written.
  const char* initialReportPath;
#if CLS_USE_SIGALTSTACK
  void* signalStack;
#endif
#if CLS_MACH_EXCEPTION_SUPPORTED
  void* machStack;
#endif

  FIRCLSBinaryImageReadOnlyContext binaryimage;
  FIRCLSExceptionReadOnlyContext exception;
  FIRCLSHostReadOnlyContext host;
#if CLS_SIGNAL_SUPPORTED
  FIRCLSSignalReadContext signal;
#endif
#if CLS_MACH_EXCEPTION_SUPPORTED
  FIRCLSMachExceptionReadContext machException;
#endif
  FIRCLSUserLoggingReadOnlyContext logging;
} FIRCLSReadOnlyContext;

typedef struct {
  FIRCLSInternalLoggingWritableContext internalLogging;
  volatile bool crashOccurred;
  FIRCLSBinaryImageReadWriteContext binaryImage;
  FIRCLSUserLoggingWritableContext logging;
  FIRCLSExceptionWritableContext exception;
} FIRCLSReadWriteContext;

typedef struct {
  FIRCLSReadOnlyContext* readonly;
  FIRCLSReadWriteContext* writable;
  FIRCLSAllocatorRef allocator;
} FIRCLSContext;
#ifdef __OBJC__
FBLPromise* FIRCLSContextInitialize(FIRCLSContextInitData* initData,
                                    FIRCLSFileManager* fileManager);
FIRCLSContextInitData* FIRCLSContextBuildInitData(FIRCLSInternalReport* report,
                                                  FIRCLSSettings* settings,
                                                  FIRCLSFileManager* fileManager,
                                                  NSString* appQualitySessionId);
bool FIRCLSContextRecordMetadata(NSString* rootPath, FIRCLSContextInitData* initData);
#endif

void FIRCLSContextBaseInit(void);
void FIRCLSContextBaseDeinit(void);

bool FIRCLSContextIsInitialized(void);
bool FIRCLSContextHasCrashed(void);
void FIRCLSContextMarkHasCrashed(void);
bool FIRCLSContextMarkAndCheckIfCrashed(void);

__END_DECLS
