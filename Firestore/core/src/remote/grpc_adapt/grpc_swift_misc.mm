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
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_misc.h"

#import "GRPCSwiftShim/GRPCSwiftShim-Swift.h"

#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_status.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace grpc_adapt {

string_ref::const_iterator string_ref::begin() const {
  return nullptr;
}

size_t string_ref::size() const {
  return 0;
}

int string_ref::compare(string_ref x) const {
  return 0;
}

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

Slice::Slice(const void* buf, size_t len) {
}
Slice::Slice(const std::string& s) {
}
size_t Slice::size() const {
  return 0;
}
const uint8_t* Slice::begin() const {
  return nullptr;
}

ByteBuffer::ByteBuffer() {
}
ByteBuffer::ByteBuffer(const Slice* slices, size_t nslices) {
}
size_t ByteBuffer::Length() const {
  return 0;
}
Status ByteBuffer::Dump(std::vector<Slice>* slices) const {
  return Status();
}

WriteOptions::WriteOptions() {
}
WriteOptions::WriteOptions(const WriteOptions& other) {
}
WriteOptions& WriteOptions::set_last_message() {
  return *this;
}

void GenericClientAsyncReaderWriter::StartCall(void* tag) {
}
void GenericClientAsyncReaderWriter::Read(ByteBuffer* msg, void* tag) {
}
void GenericClientAsyncReaderWriter::Write(const ByteBuffer& msg, void* tag) {
}
void GenericClientAsyncReaderWriter::Write(const ByteBuffer& msg,
                                           WriteOptions options,
                                           void* tag) {
}
void GenericClientAsyncReaderWriter::Finish(Status* status, void* tag) {
}
void GenericClientAsyncReaderWriter::WriteLast(const ByteBuffer& msg,
                                               WriteOptions options,
                                               void* tag) {
}

void GenericClientAsyncResponseReader::StartCall() {
}
void GenericClientAsyncResponseReader::Finish(ByteBuffer* msg,
                                              Status* status,
                                              void* tag) {
}

bool CompletionQueue::Next(void** tag, bool* ok) {
  return false;
}
void CompletionQueue::Shutdown() {
}

grpc_connectivity_state Channel::GetState(bool try_to_connect) {
  return GRPC_CHANNEL_SHUTDOWN;
}

void ChannelArguments::SetSslTargetNameOverride(const std::string& name) {
}
void ChannelArguments::SetInt(const std::string& key, int value) {
}

GenericStub::GenericStub(std::shared_ptr<Channel> channel) {
}
std::unique_ptr<GenericClientAsyncReaderWriter> GenericStub::PrepareCall(
    ClientContext* context, const std::string& method, CompletionQueue* cq) {
  return nullptr;
}
std::unique_ptr<GenericClientAsyncResponseReader> GenericStub::PrepareUnaryCall(
    ClientContext* context,
    const std::string& method,
    const ByteBuffer& request,
    CompletionQueue* cq) {
  return nullptr;
}

}  // namespace grpc_adapt
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
