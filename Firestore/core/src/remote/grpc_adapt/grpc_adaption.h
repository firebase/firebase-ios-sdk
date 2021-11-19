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

#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_ADAPTION_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_ADAPTION_H_

#ifdef GRPC_SWIFT
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_byte_buffer.h"
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_misc.h"
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_slice.h"
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_status.h"
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_channel.h"
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_client.h"
#else
#include "Firestore/core/src/remote/grpc_adapt/grpc_cpp_adaption.h"
#endif  // GRPC_SWIFT

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_ADAPTION_H_
