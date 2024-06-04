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

# A Private podspec for GoogleBenchmark. Suitable only for use inside this source
# tree.

Pod::Spec.new do |s|
  s.name             = 'GoogleBenchmark'
  s.version          = '1.5.0'
  s.summary          = 'Google Benchmark'

  s.description      = <<-DESC
Google's C++ benchmark framework.
                       DESC

  s.homepage         = 'https://github.com/google/benchmark/'
  s.license          = 'Apache-2.0'
  s.authors          = 'Google, Inc.'

  s.source           = {
      :git => 'https://github.com/google/benchmark.git',
      :tag => 'v' + s.version.to_s
  }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'

  s.requires_arc = false

  s.public_header_files = [
      'include/benchmark/*.h'
  ]
  s.header_mappings_dir = 'include'

  s.preserve_paths = [
      'src/*.h'
  ]
  s.source_files = [
      'src/*.cc',
      'include/benchmark/*.h'
  ]

  s.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' =>
        '"${PODS_ROOT}/GoogleBenchmark/include" "${PODS_ROOT}/GoogleBenchmark/src"'
  }

  s.compiler_flags = '$(inherited) -Wno-deprecated-declarations'

  s.library = 'c++'
end
