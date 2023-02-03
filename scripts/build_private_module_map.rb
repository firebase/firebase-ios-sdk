# Copyright 2023 Google
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

require 'cocoapods'

def main(args)
    # TODO(ncooke3): Generalize this to take a module name as an argument.
    if args.length != 1
        puts "Usage: build_private_module_map.rb <module_name>"
        exit 1
    end

    STDOUT.sync = true

    module_name = args[0]
    spec = Pod::Spec.from_file("#{module_name}.podspec")

    # Build of the private module map in the following template:
    #
    #       framework module FirebaseAuth_Private {
    #         header "PrivateHeader_1.h"
    #         header "PrivateHeader_2.h"
    #         header "PrivateHeader_3.h"
    #       }
    #
    private_module_map_contents = "framework module #{module_name}_Private {\n"

    Dir[
        'FirebaseAuth/Sources/**/*.h',
        'FirebaseCore/Extension/*.h',
        'FirebaseAuth/Interop/*.h'
    ]
        .reject{ |f| f['FirebaseAuth/Sources/Public/'] }
        .each do |filepath|
            filename = File.basename(filepath)
            private_module_map_contents << "  header \"#{filename}\"\n"
        end

    private_module_map_contents << "}\n"

    # Overwrite the private module map with the generated contents.
    File.write(
        'FirebaseAuth/Sources/FirebaseAuth.private.modulemap', 
        private_module_map_contents
    )
    
end

main(ARGV)
