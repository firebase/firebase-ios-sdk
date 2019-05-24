#!/usr/bin/env ruby

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

require 'cocoapods'
require 'set'

def usage()
  script = File.basename($0)
  STDERR.puts <<~EOF
  USAGE: #{script} podspec
  EOF
end

def main(args)
  if args.size < 1 then
    usage()
    exit(1)
  end

  seen = Set[]
  deps = find_local_deps(args[0], seen)
  deps.sort.each do |dep|
    puts dep
  end
end

# Loads all the specs (inclusing subspecs) from the given podspec file.
def load_specs(podspec_file)
  results = []

  spec = Pod::Spec.from_file(podspec_file)
  results.push(spec)

  results.push(*spec.subspecs)
  return results
end

# Finds all dependencies of the given list of specs
def all_deps(specs)
  result = Set[]

  specs.each do |spec|
    spec.dependencies.each do |dep|
      name = dep.name.sub(/\/.*/, '')
      result.add(name)
    end
  end

  return result.to_a
end

# Given a podspec file, finds all local dependencies that have a local podspec
# in the same directory. Modifies seen to include all seen podspecs, which
# guarantees that a given podspec will only be processed once.
def find_local_deps(podspec_file, seen)
  results = []
  spec_dir = File.dirname(podspec_file)

  specs = load_specs(podspec_file)
  deps = all_deps(specs)

  deps.each do |dep_name|
    dep_file = File.join(spec_dir, "#{dep_name}.podspec")
    if File.exist?(dep_file) then
      if seen.add?(dep_file)
        # Depend on the podspec we found and any podspecs it depends upon.
        results.push(File.basename(dep_file))
        results.push(*find_local_deps(dep_file, seen))
      end
    end
  end

  return results
end

main(ARGV)
