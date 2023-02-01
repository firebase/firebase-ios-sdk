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

def main(args)
    # TODO(ncooke3): Generalize this to take a module name as an argument.
    if args.length != 1
        puts "Usage: build_private_module_map.rb <module_name>"
        exit 1
    end

    STDOUT.sync = true

    # Build of the private module map in the following template:
    #
    #       framework module FirebaseAuth_Private {
    #         header "PrivateHeader_1.h"
    #         header "PrivateHeader_2.h"
    #         header "PrivateHeader_3.h"
    #       }
    #
    module_name = "framework module FirebaseAuth_Private {\n"

    # TODO(ncooke3): This could hopefully be read from the podspec.
    Dir[
        'FirebaseAuth/Sources/**/*.h',
        'FirebaseCore/Extension/*.h',
        'FirebaseAuth/Interop/*.h'
    ]
        .reject{ |f| f['FirebaseAuth/Sources/Public/'] }
        .each do |filepath|
            filename = File.basename(filepath)
            module_name << "  header \"#{filename}\"\n"
        end

    module_name << "}\n"

    # Overwrite the private module map with the generated contents.
    File.write(
        'FirebaseAuth/Sources/FirebaseAuth.private.modulemap', 
        module_name
    )
    
end

main(ARGV)
