# Copyright 2023 Google LLC
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

def usage()
    script = File.basename($0)
    STDERR.puts <<~EOF
    USAGE: #{script} <podspec> [options]

    Generates a private module map for the given podspec. The generated module
    map contains the private headers listed in the podspec's
    'private_header_files' attribute.

    This generated module map will resemble the following template:

        framework module $(SPEC_MODULE_NAME)_Private {
          header "PrivateHeader_1.h"
          header "PrivateHeader_2.h"
          header "PrivateHeader_3.h"
          // And so on for each of the spec's private headers...
        }

    OPTIONS:
      --dry-run: Prints the generated private module map to STDOUT without
                 writing it to the filesystem.
    EOF
  end

def main(args)
    if args.length < 1 || args.length > 2
        usage()
        exit 1
    end

    STDOUT.sync = true

    begin
        spec = Pod::Spec.from_file(args[0])
    rescue => e
        STDERR.puts "#{e}"
        exit(1)
    end

    private_module_map_contents = "framework module #{spec.module_name}_Private {\n"

    private_hdrs = spec.attributes_hash['private_header_files']
        # Expand all path globs to get the complete list of private headers.
        .flat_map { |hdr_path_glob| Dir[hdr_path_glob] }
        # Add each private header to the private module map's contents.
        .each do |hdr_path|
            # Note: Only the header file's name is needed in the module map.
            # This is because the module map evaluates its headers relative to
            # the private headers directory (Foo.framework/PrivateHeaders)
            # within the CocoaPods-generated framework.
            hdr_name = File.basename(hdr_path)
            private_module_map_contents << "  header \"#{hdr_name}\"\n"
        end

    private_module_map_contents << "}\n"

    if args.length == 2 && args[1] == '--dry-run'
        STDOUT.puts private_module_map_contents
    else
        # Overwrite the private module map with the generated contents.
        File.write(
            "#{spec.module_name}/Sources/#{spec.module_name}.private.modulemap",
            private_module_map_contents
        )
    end
end

main(ARGV)
