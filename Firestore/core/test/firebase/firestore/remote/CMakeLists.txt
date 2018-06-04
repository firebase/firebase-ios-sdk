# Copyright 2018 Google
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cc_test(
  firebase_firestore_remote_test
  SOURCES
    datastore_test.cc
    serializer_test.cc
  DEPENDS
    # NB: Order is important. We need to include the ffp_libprotobuf library
    # before ff_remote, or else we'll end up with nanopb's headers earlier in
    # the include path than libprotobuf's, which makes using libprotobuf in the
    # test quite difficult. (protoc doesn't generate full include paths, so it
    # includes files like this: `#include google/proto/timestamp.pb.h` which
    # exists in both the libprotobuf path and the nanopb path.
    firebase_firestore_protos_libprotobuf
    firebase_firestore_remote
)

set_target_properties(firebase_firestore_remote_test
  PROPERTIES
    # Treat headers from dependencies as *non* system includes (i.e. use -I
    # rather than -isystem.) Required, as otherwise libprotobuf includes
    # imported via -isystem are examined last, allowing nanopb includes to take
    # priority.
    NO_SYSTEM_FROM_IMPORTED true

    # libprotobuf headers have plenty of unused parameters in them... which
    # wouldn't be a problem, except these are now considered local (not system)
    # headers due to the above.
    COMPILE_FLAGS "-Wno-unused-parameter"
)
