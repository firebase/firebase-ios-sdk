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

require 'cocoapods'
require 'set'

# Enable ruby options after 'require' because cocoapods is noisy
$VERBOSE = true   # ruby -w
#$DEBUG = true    # ruby --debug

def usage()
  script = File.basename($0)
  STDERR.puts <<~EOF
  USAGE: #{script} podspec [options]

  podspec is the podspec to lint

  options can be any options for pod spec lint
  EOF
end

def main(args)
  if args.size < 1 then
    usage()
    exit(1)
  end

  command = %w(bundle exec pod lib lint --sources=https://cdn.cocoapods.org/)

  # Figure out which dependencies are local
  podspec_file = args[0]
  deps = find_local_deps(podspec_file)
  arg = make_include_podspecs(deps)
  command.push(arg) if arg

  command.push(*args)
  puts command.join(' ')
  exec(*command)
end

# Loads all the specs (inclusing subspecs) from the given podspec file.
def load_specs(podspec_file)
  trace('loading', podspec_file)
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

  result = result.to_a
  trace('   deps', *result)
  return result
end

# Given a podspec file, finds all local dependencies that have a local podspec
# in the same directory. Modifies seen to include all seen podspecs, which
# guarantees that a given podspec will only be processed once.
def find_local_deps(podspec_file, seen = Set[])
  # Mark the current podspec seen to prevent a pod from depending upon itself
  # (as might happen if a subspec of the pod depends upon another subpsec of
  # the pod.
  seen.add(File.basename(podspec_file))

  results = []
  spec_dir = File.dirname(podspec_file)

  specs = load_specs(podspec_file)
  deps = all_deps(specs)

  deps.each do |dep_name|
    dep_file = File.join(spec_dir, "#{dep_name}.podspec")
    if File.exist?(dep_file) then
      dep_podspec = File.basename(dep_file)
      if seen.add?(dep_podspec)
        # Depend on the podspec we found and any podspecs it depends upon.
        results.push(dep_podspec)
        results.push(*find_local_deps(dep_file, seen))
      end
    end
  end

  return results
end

# Returns an --include-podspecs argument that indicates the given deps are
# locally available. Returns nil if deps is empty.
def make_include_podspecs(deps)
  return nil if deps.empty?

  if deps.size == 1 then
    deps_joined = deps[0]
  else
    deps_joined  = "{" + deps.join(',') + "}"
  end
  return "--include-podspecs=#{deps_joined}"
end

def trace(*args)
  return if not $DEBUG

  STDERR.puts(args.join(' '))
end

main(ARGV)
