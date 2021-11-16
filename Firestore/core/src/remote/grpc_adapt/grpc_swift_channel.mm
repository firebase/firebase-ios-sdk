/*
 * Copyright 2021 Google LLC
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
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_channel.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace grpc_adapt {

ClientContext::ClientContext() {
}
ClientContext::~ClientContext() {
}
void ClientContext::AddMetadata(const std::string& meta_key,
                                const std::string& meta_value) {
}
void ClientContext::TryCancel() {
}
const std::multimap<string_ref, string_ref>&
ClientContext::GetServerInitialMetadata() const {
  return {};
}
void ClientContext::set_initial_metadata_corked(bool) {
}

}  // namespace grpc_adapt
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
