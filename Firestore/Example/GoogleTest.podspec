# Copyright 2017 Google
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

# A Private podspec for GoogleTest. Suitable only for use inside this source
# tree.

Pod::Spec.new do |s|
  s.name             = 'GoogleTest'
  s.version          = '99.99.99'
  s.summary          = 'Google Test'

  s.description      = <<-DESC
Google's C++ test framework.
                       DESC

  s.homepage         = 'https://github.com/google/googletest/'
  s.license          = 'BSD'
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/google/googletest.git',
    :commit => 'bf66935e07825318ae519675d73d0f3e313b3ec6'
  }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'

  s.requires_arc = false

  # Exclude include/gtest/internal/custom files from public headers. These
  # files cause problems because they have the same basenames as other headers
  # (e.g. gtest.h). We don't need them because they're effectively empty:
  # they're compile-time hooks for third-party customization that we don't use.
  s.public_header_files = [
    'googlemock/include/gmock/*.h',
    'googlemock/include/gmock/internal/*.h',
    'googletest/include/gtest/*.h',
    'googletest/include/gtest/internal/*.h'
  ]
  s.header_mappings_dir = 'googletest/include'

  # Internal headers accessed only by the implementation. These can't be
  # mentioned in source_files because header_mappings_dir will complain about
  # headers outside its directory.
  s.preserve_paths = [
    'googletest/src/*.h',
  ]

  s.source_files = [
    'googlemock/src/*.cc',
    'googlemock/include/gmock/*.h',
    'googlemock/include/gmock/internal/*.h',
    'googletest/src/*.cc',
    'googletest/include/gtest/*.h',
    'googletest/include/gtest/internal/*.h'
  ]

  s.exclude_files = [
    # A convenience wrapper for a simple command-line build. If included in
    # this build, results in duplicate symbols.
    'googlemock/src/gmock-all.cc',
    'googletest/src/gtest-all.cc',
    # Both gmock and gtest define a main function but we only need one.
    'googletest/src/gtest_main.cc',
  ]

  s.library = 'c++'

  # When building this pod there are headers in googletest/src.
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' =>
      '"${PODS_ROOT}/GoogleTest/googlemock/include" ' +
      '"${PODS_ROOT}/GoogleTest/googletest/include" ' +
      '"${PODS_ROOT}/GoogleTest/googletest"'
  }

  s.compiler_flags = '$(inherited) -Wno-comma'

  s.prepare_command = <<-'CMD'
    # Remove includes of files in internal/custom
    sed -i.bak -e '/include.*internal\/custom/ d' \
      googlemock/include/gmock/gmock-matchers.h \
      googlemock/include/gmock/gmock-more-actions.h \
      googlemock/include/gmock/internal/gmock-port.h \
      googletest/include/gtest/gtest-printers.h \
      googletest/include/gtest/internal/gtest-port.h \
      googletest/src/gtest-death-test.cc \
      googletest/src/gtest.cc
  CMD
end
