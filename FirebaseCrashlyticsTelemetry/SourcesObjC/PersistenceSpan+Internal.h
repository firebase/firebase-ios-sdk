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

#import "PersistenceSpan.h"

#include "firebase/telemetry/persistence/span.h"

NS_ASSUME_NONNULL_BEGIN

namespace ftp = firebase::telemetry::persistence;

@interface PersistenceSpan ()

/// Internal initializer that converts and initializes directly from a native C++ Span.
/// Visible only within the Objective-C++ target.
- (instancetype)initWithCppSpan:(const ftp::Span &)cppSpan;

/// Converts the Objective-C PersistenceSpan back into a native C++ Span.
/// Visible only within the Objective-C++ compilation unit.
- (ftp::Span)toCppSpan;

@end

NS_ASSUME_NONNULL_END
