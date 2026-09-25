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

#import "PersistenceBufferWrapper.h"
#import "PersistenceSpan+Internal.h"

#include <memory>
#include <string>
#include <vector>
#include <utility>

#include "firebase/telemetry/persistence/mmap_size.h"
#include "firebase/telemetry/persistence/span.h"
#include "firebase/telemetry/persistence/mutable_span_data.h"
#include "firebase/telemetry/persistence/initialize.h"

namespace ftp = firebase::telemetry::persistence;

static ftp::MmapSize MapBufferSize(PersistenceBufferSize size) {
  switch (size) {
    case PersistenceBufferSizeMedium: return ftp::MmapSize::Medium;
    case PersistenceBufferSizeLarge:  return ftp::MmapSize::Large;
    case PersistenceBufferSizeSmall:
    default:                           return ftp::MmapSize::Small;
  }
}

/// Private helper extracting and converting C++ spans into Objective-C models.
static NSArray<PersistenceSpan *> *ExtractRecoveredSpans(ftp::unspecified_context_t *context) {
  if (!context) return @[];

  auto cppSpans = ftp::get_recovered_spans(context);
  if (cppSpans.empty()) return @[];

  NSMutableArray<PersistenceSpan *> *recovered = [NSMutableArray arrayWithCapacity:cppSpans.size()];
  for (const auto &cppSpan : cppSpans) {
    [recovered addObject:[[PersistenceSpan alloc] initWithCppSpan:cppSpan]];
  }

  return [recovered copy];
}

@interface PersistenceBufferWrapper () {
  ftp::unspecified_context_t *_context;
  std::shared_ptr<ftp::MutableSpanData> _mutableSpanData;
}
- (instancetype)initWithContext:(ftp::unspecified_context_t *)context
                mutableSpanData:(std::shared_ptr<ftp::MutableSpanData>)spanData NS_DESIGNATED_INITIALIZER;
@end

@implementation PersistenceBufferWrapper

- (instancetype)initWithContext:(ftp::unspecified_context_t *)context
                mutableSpanData:(std::shared_ptr<ftp::MutableSpanData>)spanData {
  self = [super init];
  if (self) {
    _context = context;
    _mutableSpanData = spanData;
  }
  return self;
}

+ (nullable instancetype)initializeWithFilePath:(NSString *)filePath
                                     bufferSize:(PersistenceBufferSize)bufferSize
                                 recoveredSpans:(NSArray<PersistenceSpan *> * _Nullable * _Nonnull)outRecoveredSpans {
  *outRecoveredSpans = @[];

  ftp::unspecified_context_t *context = ftp::initialize_span_data(
      std::string(filePath.fileSystemRepresentation), MapBufferSize(bufferSize));
  if (!context) {
    return nil;
  }

  *outRecoveredSpans = ExtractRecoveredSpans(context);

  auto mutableSpanData = ftp::get_mutable_span_data(context);
  if (!mutableSpanData) {
    ftp::release_span_data(context);
    return nil;
  }

  return [[PersistenceBufferWrapper alloc] initWithContext:context mutableSpanData:mutableSpanData];
}

- (void)dealloc {
  _mutableSpanData.reset();
  if (_context != nullptr) {
    ftp::release_span_data(_context);
  }
}

- (void)addSpan:(PersistenceSpan *)span {
  if (!_mutableSpanData) return;
  _mutableSpanData->add([span toCppSpan]);
}

- (void)setAttribute:(NSString *)value forKey:(NSString *)key onSpanId:(uint64_t)spanId {
  if (!_mutableSpanData) return;
  _mutableSpanData->set_attribute_on_span(
      spanId,
      std::string(key.UTF8String ?: ""),
      std::string(value.UTF8String ?: "")
  );
}

- (void)endSpanId:(uint64_t)spanId endTime:(uint64_t)endTime {
  if (!_mutableSpanData) return;
  _mutableSpanData->end(spanId, endTime);
}

- (void)removeSpanId:(uint64_t)spanId {
  if (!_mutableSpanData) return;
  _mutableSpanData->remove(spanId);
}

@end
