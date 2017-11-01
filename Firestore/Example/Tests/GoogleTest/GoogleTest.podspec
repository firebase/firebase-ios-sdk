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
  s.version          = '1.8.0'
  s.summary          = 'Google Test'

  s.description      = <<-DESC
Google's C++ test framework.
                       DESC

  s.homepage         = 'https://github.com/google/googletest/'
  s.license          = 'BSD'
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/google/googletest.git',
    :tag => 'release-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'
  s.requires_arc = false

  s.source_files = [
    'googletest/src/*.{h,cc}',
    'googletest/include/**/*.h',
  ]

  s.library = 'c++'
end
