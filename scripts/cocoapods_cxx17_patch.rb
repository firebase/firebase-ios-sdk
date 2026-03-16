# Copyright 2024 Google
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

module CocoapodsCXX17Patch
  def self.apply_patch
    Pod::HooksManager.register('cocoapods-cxx17-patch', :post_install) do |context|
      targets_to_patch = ['BoringSSL-GRPC', 'gRPC-C++', 'abseil']
      context.pods_project.targets.each do |target|
        if targets_to_patch.any? { |name| target.name.start_with?(name) }
          target.build_configurations.each do |config|
            config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++17'
            config.build_settings['CLANG_CXX_LIBRARY'] = 'libc++'
          end
        end
      end
    end
  end
end

if defined?(Pod::HooksManager)
  CocoapodsCXX17Patch.apply_patch
else
  # Hook into require to apply the patch once cocoapods is loaded
  module Kernel
    alias_method :original_require, :require
    def require(name)
      result = original_require(name)
      if name == 'cocoapods'
        CocoapodsCXX17Patch.apply_patch
      end
      result
    end
  end
end
