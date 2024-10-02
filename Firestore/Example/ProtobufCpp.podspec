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

# A Private podspec for Protobuf which exposes the C++ headers (rather than
# only the Obj-C headers). Suitable only for use inside this source tree.

Pod::Spec.new do |s|
  s.name             = 'ProtobufCpp'
  s.version          = '25.0'
  s.summary          = 'Protocol Buffers v.3 runtime library for C++.'
  s.homepage         = 'https://github.com/protocolbuffers/protobuf'
  s.license          = '3-Clause BSD License'
  s.authors          = { 'The Protocol Buffers contributors' => 'protobuf@googlegroups.com' }
  s.cocoapods_version = '>= 1.0'

  s.source           = {
    :git => 'https://github.com/google/protobuf.git',
    :tag => "v#{s.version}"
  }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'

  s.source_files = 'src/**/*.{h,cc,inc}',
                   # utf8_range is needed too, to avoid build errors.
                   'third_party/utf8_range/*.{h,cc,inc}'
  s.exclude_files = # skip test files. (Yes, the test files are intermixed with
                    # the source. No there doesn't seem to be a common/simple
                    # pattern we could use to exclude them; 'test' appears in
                    # various places throughout the file names and also in a
                    # non-test file. So, we'll exclude all files that either
                    # start with 'test' or include test and have a previous
                    # character that isn't "y" (so that bytestream isn't
                    # matched.))
                    'src/**/test*.*',
                    'src/**/*[^y]test*.*',
                    'src/**/testing/**',
                    'src/**/mock*',
                    'third_party/utf8_range/*_test.{h,cc,inc}',
                    # skip benchmark code that failed to compile.
                    'src/**/map_probe_benchmark.cc',
                    # skip the javascript handling code.
                    'src/**/js/**',
                    # skip the protoc compiler
                    'src/google/protobuf/compiler/**/*'

  s.header_mappings_dir = 'src/'

  s.dependency 'abseil', '~> 1.20240116.1'

  # Set a CPP symbol so the code knows to use framework imports.
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      '$(inherited) ' +
      'GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 ' +
      'HAVE_PTHREAD=1',
    'HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/ProtobufCpp/src" "${PODS_ROOT}/ProtobufCpp/third_party/utf8_range"',

    # Cocoapods flattens header imports, leading to much anguish.  The
    # following two statements work around this.
    # - https://github.com/CocoaPods/CocoaPods/issues/1437
    'USE_HEADERMAP' => 'NO',
    'ALWAYS_SEARCH_USER_PATHS' => 'NO',
  }

  # Disable warnings that upstream does not concern itself with
  s.compiler_flags = '$(inherited) ' +
    '-Wno-comma ' +
    '-Wno-inconsistent-missing-override ' +
    '-Wno-invalid-offsetof ' +
    '-Wno-shorten-64-to-32 ' +
    '-Wno-unreachable-code ' +
    '-Wno-unused-parameter'

  s.requires_arc = false
  s.library = 'c++'
end
