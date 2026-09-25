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

#import "PersistenceSpan+Internal.h"

namespace ftp = firebase::telemetry::persistence;

@implementation PersistenceSpan

- (instancetype)initWithTraceIdHi:(uint64_t)traceIdHi
                        traceIdLo:(uint64_t)traceIdLo
                           spanId:(uint64_t)spanId
                     parentSpanId:(uint64_t)parentSpanId
                    startTimeNano:(uint64_t)startTimeNano
                      endTimeNano:(uint64_t)endTimeNano
                             name:(NSString *)name
                       attributes:(NSDictionary<NSString *, NSString *> *)attributes {
  self = [super init];
  if (self) {
    _traceIdHi = traceIdHi;
    _traceIdLo = traceIdLo;
    _spanId = spanId;
    _parentSpanId = parentSpanId;
    _startTimeNano = startTimeNano;
    _endTimeNano = endTimeNano;
    _name = [name copy];
    _attributes = [attributes copy] ?: @{};
  }
  return self;
}

- (instancetype)initWithCppSpan:(const ftp::Span &)cppSpan {
  NSMutableDictionary<NSString *, NSString *> *attributes = [NSMutableDictionary dictionary];
  for (const auto &pair : cppSpan.attributes()) {
    NSString *key = [NSString stringWithUTF8String:pair.first.c_str()];
    NSString *value = [NSString stringWithUTF8String:pair.second.c_str()];
    if (key && value) {
      attributes[key] = value;
    }
  }

  NSString *name = [NSString stringWithUTF8String:cppSpan.name().c_str()] ?: @"";

  return [self initWithTraceIdHi:cppSpan.trace_id().high
                       traceIdLo:cppSpan.trace_id().low
                          spanId:cppSpan.span_id()
                    parentSpanId:cppSpan.parent_span_id()
                   startTimeNano:cppSpan.start_time()
                     endTimeNano:cppSpan.end_time()
                            name:name
                      attributes:attributes];
}

- (ftp::Span)toCppSpan {
  ftp::AttributesList cppAttributes;
  cppAttributes.reserve(self.attributes.count);

  for (NSString *key in self.attributes) {
    NSString *value = self.attributes[key];
    cppAttributes.emplace_back(std::string(key.UTF8String ?: ""),
                               std::string(value.UTF8String ?: ""));
  }

  ftp::TraceId cppTraceId = {.high = self.traceIdHi, .low = self.traceIdLo};

  return ftp::Span(
    cppTraceId,
    self.spanId,
    self.parentSpanId,
    self.startTimeNano,
    self.endTimeNano,
    std::string(self.name.UTF8String ?: ""),
    cppAttributes
  );
}

@end
