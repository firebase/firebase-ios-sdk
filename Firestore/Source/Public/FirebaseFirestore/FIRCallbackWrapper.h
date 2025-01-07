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
#import <memory>

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

typedef void (^PipelineBlock)(std::shared_ptr<std::vector<api::PipelineResult>> result,
                              NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

typedef std::shared_ptr<std::vector<api::PipelineResult>> PipelineResultVectorPtr;

NS_SWIFT_SENDABLE
NS_SWIFT_NAME(CallbackWrapper)
@interface FIRCallbackWrapper : NSObject

+ (std::unique_ptr<core::EventListener<std::vector<api::PipelineResult>>>)
    wrapPipelineCallback:(std::shared_ptr<api::Firestore>)firestore
              completion:(void (^)(std::shared_ptr<std::vector<api::PipelineResult>> result,
                                   NSError *_Nullable error))completion
    NS_SWIFT_NAME(wrapPipelineCallback(firestore:completion:));

@end

NS_ASSUME_NONNULL_END
