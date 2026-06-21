# Copyright 2019 Google
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

if(APPLE AND CXX_CLANG)
  # Sanitizers in Clang are supported by a specific runtime and Clang
  # automatically links against the right runtime. When building statically
  # linked binaries, the resulting binary will contain the runtime. Dynamically
  # linked binaries will link against the dynamic version of the library.
  #
  # xctest bundles are necessarily dynamically linked, but linked in such a way
  # that the sanitizer runtime is assumed to be on the @rpath. This finds the
  # clang runtimes so that they can be supplied as needed.
  get_filename_component(compiler_bin_dir ${CMAKE_CXX_COMPILER} DIRECTORY)
  get_filename_component(compiler_dir ${compiler_bin_dir} DIRECTORY)

  if(WITH_ASAN)
    file(
      GLOB_RECURSE CLANG_ASAN_DYLIB
      ${compiler_dir}/libclang_rt.asan_osx_dynamic.dylib
    )
  endif()

  if(WITH_TSAN)
    file(
      GLOB_RECURSE CLANG_TSAN_DYLIB
      ${compiler_dir}/libclang_rt.tsan_osx_dynamic.dylib
    )
  endif()
endif(APPLE AND CXX_CLANG)
