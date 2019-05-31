#!/usr/bin/env ruby

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

# Generate a module map file from a podspec.

require 'cocoapods'

# Enable ruby options after 'require' because cocoapods is noisy
#$VERBOSE = true   # ruby -w
#$DEBUG = true    # ruby --debug

def usage()
  script = File.basename($0)
  STDERR.puts <<~EOF
  USAGE: #{script} podspec output_file

  podspec is the podspec to generate the module map for.
  output_file is the file to write the modulemap.
  EOF
end

def main(args)
  if args.size < 2 then
    usage()
    exit(1)
  end

  podspec_file = args[0]

  trace('loading', podspec_file)
  spec = Pod::Spec.from_file(podspec_file)

  consumer = spec.consumer("ios")
  module_name = spec.module_name
  frameworks = consumer.frameworks.map {|framework| "link framework \"#{framework}\""}
  libraries = consumer.libraries.map {|library| "link \"#{library}\""}

  trace('generating module map for ', module_name)
  contents = generate(module_name, frameworks, libraries)
  File.open(args[1], 'w') { |file| file.write(contents) }

end


# Generates the contents of the module.modulemap file.
#
# @return [String]
#
def generate(name, frameworks, libraries)
  <<-MODULE_MAP.strip_heredoc
framework module #{name} {
umbrella header "#{name}.h"
export *
module * { export * }
  #{frameworks.join("\n  ")}
  #{libraries.join("\n  ")}
}
  MODULE_MAP
end


def trace(*args)
  return if not $DEBUG

  STDERR.puts(args.join(' '))
end

main(ARGV)
