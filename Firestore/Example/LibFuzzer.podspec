# Copyright 2018 Google LLC
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

# A podspec for libFuzzer. Excludes the 'FuzzerMain.cpp' because the pod
# installation would require the 'LLVMFuzzerTestOneInput' function to be
# linked when the pod is being created, but it will be available in
# the fuzzing application. Hence, users of this Pod are required to
# provide their main function similar to 'FuzzerMain.cpp'.
# See the build script of libFuzzer for more details:
# https://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer/build.sh

Pod::Spec.new do |s|
  s.name                = 'LibFuzzer'
  s.version             = '1.0'
  s.summary             = 'libFuzzer for fuzz testing'
  s.homepage            = 'https://llvm.org/docs/LibFuzzer.html'
  s.license             = { :type => 'BSD-Like' }
  s.authors             = 'LLVM Team'

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'

  s.source              = {
    :git => 'https://github.com/llvm/llvm-project.git'
  }

  # The fuzzer is self-contained so only add its source files.
  s.source_files        = 'compiler-rt/lib/fuzzer/*.{h,cpp,def}'

  # We run fuzz tests via FSTFuzzTestsPrincipal, so avoid linking a `main`
  # function.
  s.exclude_files       = 'compiler-rt/lib/fuzzer/FuzzerMain.cpp'

  s.library             = 'c++'

  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11'
  }
end
