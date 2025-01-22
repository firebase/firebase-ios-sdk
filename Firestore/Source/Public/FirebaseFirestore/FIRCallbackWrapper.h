/*
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>
#include <memory>
#include <vector>

namespace firebase {
namespace firestore {
namespace api {
class Firestore;
class PipelineResult;
}  // namespace api

namespace core {
template <typename T>
class EventListener;
}  // namespace core

}  // namespace firestore
}  // namespace firebase

namespace api = firebase::firestore::api;
namespace core = firebase::firestore::core;

NS_ASSUME_NONNULL_BEGIN

typedef api::PipelineResult CppPipelineResult;

typedef void (^PipelineBlock)(CppPipelineResult *_Nullable result, NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(CallbackWrapper)
@interface FIRCallbackWrapper : NSObject

// Note: Marking callbacks in callback-based APIs as `Sendable` can help prevent crashes when they
// are invoked on a different thread than the one they were originally defined in. If this callback
// is expected to be called on a different thread, it should be marked as `Sendable` to ensure
// thread safety.
+ (std::shared_ptr<core::EventListener<api::PipelineResult>>)
    wrapPipelineCallback:(std::shared_ptr<api::Firestore>)firestore
              completion:(void (^NS_SWIFT_SENDABLE)(CppPipelineResult *_Nullable result,
                                                    NSError *_Nullable error))completion
    NS_SWIFT_NAME(wrapPipelineCallback(firestore:completion:));

@end

NS_ASSUME_NONNULL_END
