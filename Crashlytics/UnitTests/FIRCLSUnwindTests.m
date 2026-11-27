// Copyright 2026 Google LLC
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

#include "Crashlytics/Crashlytics/Unwind/FIRCLSUnwind.h"

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include <sys/mman.h>
#include <unistd.h>

@interface FIRCLSUnwindTests : XCTestCase

@end

@implementation FIRCLSUnwindTests

- (void)testFirstExecutableAddressStopsAtUnreadableStackAddress {
  // The stack scan starts at a captured stack pointer, which may not be readable. It must only be
  // accessed through the guarded read, so the scan stops instead of faulting.
  const size_t pageSize = (size_t)getpagesize();
  void *page = mmap(NULL, pageSize, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0);
  XCTAssertNotEqual(page, MAP_FAILED);
  if (page == MAP_FAILED) {
    return;
  }

  const vm_address_t start = (vm_address_t)page;
  vm_address_t foundAddress = 1;

  XCTAssertFalse(FIRCLSUnwindFirstExecutableAddress(start, start + pageSize, &foundAddress));
  XCTAssertEqual(foundAddress, (vm_address_t)0);

  munmap(page, pageSize);
}

@end
