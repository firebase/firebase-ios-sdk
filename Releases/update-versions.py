#!/usr/bin/python

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

"""update-versions.py creates a release branch and commit with version updates.

With the required --version parameter, this script will update all files in
the repo based on the versions in Releases/Manifests/{version}.json.

It will create a release branch, push and tag the updates, and push the
updated podspecs to cpdc-internal.
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile

test_mode = False  # Flag to disable external repo updates


def SetupArguments():
  """SetupArguments sets up the set of command-line arguments.

  Returns:
    Args: The set of command line arguments
  """
  parser = argparse.ArgumentParser(description='Update Pod Versions')

  parser.add_argument('--version', required=True, help='Firebase version')

  parser.add_argument(
      '--test_mode',
      dest='test_mode',
      action='store_true',
      help='Log commands instead of updating public repo')

  parser.add_argument(
      '--tag_update',
      dest='tag_update',
      action='store_true',
      help='Update the tags only')

  args = parser.parse_args()
  return args


def LogOrRun(command):
  """Log or run a command depending on test_mode value.

  Args:
    command: command to log or run.
  """
  if test_mode:
    print 'Log only: {}'.format(command)
  else:
    os.system(command)


def GetVersionData(git_root, version):
  """Update version specifier in FIROptions.m.

  Args:
    git_root: root of git checkout.
    version: the next version to release.
  Returns:
    Dictionary with pod keys and version values.
  """
  json_file = os.path.join(git_root, 'Releases', 'Manifests',
                           '{}.json'.format(version))
  if os.path.isfile(json_file):
    return json.load(open(json_file))
  else:
    sys.exit('Missing version file:{}'.format(json_file))


def CreateReleaseBranch(release_branch):
  """Create and push the release branch.

  Args:
    release_branch: the name of the git release branch.
  """
  os.system('git checkout master')
  os.system('git pull')
  os.system('git checkout -b {}'.format(release_branch))
  LogOrRun('git push origin {}'.format(release_branch))
  LogOrRun('git branch --set-upstream-to=origin/{} {}'.format(release_branch,
                                                              release_branch))


def UpdateFIROptions(git_root, version_data):
  """Update version specifier in FIROptions.m.

  Args:
    git_root: root of git checkout.
    version_data: dictionary of versions to be updated.
  """
  core_version = version_data['FirebaseCore']
  major, minor, patch = core_version.split('.')
  path = os.path.join(git_root, 'Firebase', 'Core', 'FIROptions.m')
  os.system("sed -E -i.bak 's/[[:digit:]]+\"[[:space:]]*\\/\\/ Major/"
            "{}\"     \\/\\/ Major/' {}".format(major, path))
  os.system("sed -E -i.bak 's/[[:digit:]]+\"[[:space:]]*\\/\\/ Minor/"
            "{}\"    \\/\\/ Minor/' {}".format(minor.zfill(2), path))
  os.system("sed -E -i.bak 's/[[:digit:]]+\"[[:space:]]*\\/\\/ Build/"
            "{}\"    \\/\\/ Build/' {}".format(patch.zfill(2), path))


def UpdatePodSpecs(git_root, version_data, firebase_version):
  """Update the podspecs with the right version.

  Args:
    git_root: root of git checkout.
    version_data: dictionary of versions to be updated.
    firebase_version: the Firebase version.
  """
  core_podspec = os.path.join(git_root, 'FirebaseCore.podspec')
  os.system("sed -i.bak -e \"s/\\(Firebase_VERSION=\\).*'/\\1{}'/\" {}".format(
      firebase_version, core_podspec))
  for pod, version in version_data.items():
    podspec = os.path.join(git_root, '{}.podspec'.format(pod))
    os.system("sed -i.bak -e \"s/\\(\\.version.*=[[:space:]]*'\\).*'/\\1{}'/\" "
              '{}'.format(version, podspec))


def UpdatePodfiles(git_root, version):
  """Update Podfile's to reference the latest Firebase pod.

  Args:
    git_root: root of git checkout.
    version: the next Firebase version to release.
  """
  firebase_podfile = os.path.join(git_root, 'Example', 'Podfile')
  firestore_podfile = os.path.join(git_root, 'Firestore', 'Example', 'Podfile')

  sed_command = ("sed -i.bak -e \"s#\\(pod "
                 "'Firebase/Core',[[:space:]]*'\\).*'#\\1{}'#\" {}")
  os.system(sed_command.format(version, firebase_podfile))
  os.system(sed_command.format(version, firestore_podfile))


def UpdateTags(version_data, firebase_version, first=False):
  """Update tags.

  Args:
    version_data: dictionary of versions to be updated.
    firebase_version: the Firebase version.
    first: set to true the first time the versions are set.
  """
  if not first:
    LogOrRun("git push --delete origin '{}'".format(firebase_version))
    LogOrRun("git tag --delete  '{}'".format(firebase_version))
  LogOrRun("git tag '{}'".format(firebase_version))
  for pod, version in version_data.items():
    name = pod[len('Firebase'):]
    tag = '{}-{}'.format(name, version)
    if not first:
      LogOrRun("git push --delete origin '{}'".format(tag))
      LogOrRun("git tag --delete  '{}'".format(tag))
    LogOrRun("git tag '{}'".format(tag))
  LogOrRun('git push origin --tags')


def GetCpdcInternal():
  """Find the cpdc-internal repo.

"""
  tmp_file = tempfile.mktemp()
  os.system('pod repo list | grep -B2 sso://cpdc-internal | head -1 > {}'
            .format(tmp_file))
  with open(tmp_file,'r') as o:
    output_var = ''.join(o.readlines()).strip()
  os.system('rm -rf {}'.format(tmp_file))
  return output_var


def PushPodspecs(version_data):
  """Push podspecs to cpdc-internal.

  Args:
    version_data: dictionary of versions to be updated.
  """
  pods = version_data.keys()
  pods.insert(0, pods.pop(pods.index('FirebaseCore')))  # Core should be first
  tmp_dir = tempfile.mkdtemp()
  for pod in pods:
    LogOrRun('pod cache clean {} --all'.format(pod))
    if pod == 'FirebaseFirestore':
      warnings_ok = ' --allow-warnings'
    else:
      warnings_ok = ''

    podspec = '{}.podspec'.format(pod)
    json = os.path.join(tmp_dir, '{}.json'.format(podspec))
    os.system('pod ipc spec {} > {}'.format(podspec, json))
    LogOrRun('pod repo push {} {}{}'.format(GetCpdcInternal(), json,
                                            warnings_ok))
  os.system('rm -rf {}'.format(tmp_dir))


def UpdateVersions():
  """UpdateVersions is the main body to create the branch and change versions.
  """
  global test_mode
  args = SetupArguments()
  test_mode = args.test_mode
  # Validate version is proper format
  major, minor, patch = args.version.split('.')
  if (not major.isdigit()) or (not minor.isdigit()) or (not patch.isdigit()):
    sys.exit('Invalid version parameter')

  git_root = subprocess.Popen(
      ['git', 'rev-parse', '--show-toplevel'],
      stdout=subprocess.PIPE).communicate()[0].rstrip().decode('utf-8')

  version_data = GetVersionData(git_root, args.version)
  if args.tag_update:
    UpdateTags(version_data, args.version)
    return

  release_branch = 'release-{}'.format(args.version)
  CreateReleaseBranch(release_branch)
  UpdateFIROptions(git_root, version_data)
  UpdatePodSpecs(git_root, version_data, args.version)
  UpdatePodfiles(git_root, args.version)

  LogOrRun('git commit -am "Update versions for Release {}"'
           .format(args.version))
  LogOrRun('git push origin {}'.format(release_branch))
  UpdateTags(version_data, args.version, True)
  PushPodspecs(version_data)


if __name__ == '__main__':
  UpdateVersions()
