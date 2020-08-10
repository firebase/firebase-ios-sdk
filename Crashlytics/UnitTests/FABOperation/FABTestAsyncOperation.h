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

#import "Crashlytics/Shared/FIRCLSOperation/FIRCLSOperation.h"

FOUNDATION_EXPORT const NSUInteger FABTestAsyncOperationErrorCodeCancelled;

/// Example subclass of FABAsyncOperation to use for test cases. It schedules a block using
/// dispatch_after to mark itself as done after 2 seconds.
@interface FABTestAsyncOperation : FIRCLSFABAsyncOperation

@end
