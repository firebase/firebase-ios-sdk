# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import logging
import json
import subprocess

SWIFT = 'Swift'
OBJECTIVE_C = 'Objective-C'

# List of Swift and Objective-C modules
MODULE_LIST = [
    'FirebaseABTesting',
    'FirebaseAnalytics',  # Not buildable from source
    'FirebaseAnalyticsOnDeviceConversion',  # Not buildable.
    'FirebaseAppCheck',
    'FirebaseAppDistribution',
    'FirebaseAuth',
    'FirebaseCore',
    'FirebaseCrashlytics',
    'FirebaseDatabase',
    'FirebaseDynamicLinks',
    'FirebaseFirestoreInternal',
    'FirebaseFirestore',
    'FirebaseFunctions',
    'FirebaseInAppMessaging'
    'FirebaseInstallations',
    'FirebaseMessaging',
    'FirebaseMLModelDownloader',
    'FirebasePerformance',
    'FirebaseRemoteConfig',
    # Not buildable. No scheme named "FirebaseSharedSwift"
    'FirebaseSharedSwift',
    'FirebaseStorage',
    # Not buildable. NO "source_files"
    'GoogleAppMeasurement',
    # Not buildable. NO "source_files"
    'GoogleAppMeasurementOnDeviceConversion'
]


def main():
  module_info()


def detect_changed_modules(changed_api_files):
  """Detect changed modules based on changed API files."""
  all_modules = module_info()
  changed_modules = {}
  for file_path in changed_api_files:
    for k, v in all_modules.items():
      if v['root_dir'] and v['root_dir'] in file_path:
        changed_modules[k] = v
        break

  logging.info(f'changed_modules:\n{json.dumps(changed_modules, indent=4)}')
  return changed_modules


def module_info():
  """retrieve module info in MODULE_LIST from `.podspecs`
    The module info helps to build Jazzy
    includes: module name, source_files, public_header_files,
              language, umbrella_header, framework_root
    """
  module_from_podspecs = module_info_from_podspecs()
  module_list = {}
  for k, v in module_from_podspecs.items():
    if k in MODULE_LIST:
      if k not in module_list:
        module_list[k] = v
        module_list[k]['language'] = OBJECTIVE_C if v.get(
            'public_header_files') else SWIFT
        module_list[k]['scheme'] = get_scheme(k)
        module_list[k]['umbrella_header'] = get_umbrella_header(
            k, v.get('public_header_files'))
        module_list[k]['root_dir'] = get_root_dir(k, v.get('source_files'))

  logging.info(f'all_module:\n{json.dumps(module_list, indent=4)}')
  return module_list


def get_scheme(module_name):
  """Jazzy documentation Info SWIFT only.

    Get scheme from module name in .podspecs Assume the scheme is the
    same as the module name:
    """
  MODULE_SCHEME_PATCH = {}
  if module_name in MODULE_SCHEME_PATCH:
    return MODULE_SCHEME_PATCH[module_name]
  return module_name


def get_umbrella_header(module_name, public_header_files):
  """Jazzy documentation Info OBJC only Get umbrella_header from
    public_header_files in .podspecs Assume the umbrella_header is with the
    format:

    {module_name}/Sources/Public/{module_name}/{module_name}.h
    """
  if public_header_files:
    if isinstance(public_header_files, list):
      return public_header_files[0].replace('*', module_name)
    elif isinstance(public_header_files, str):
      return public_header_files.replace('*', module_name)
  return ''


def get_root_dir(module_name, source_files):
  """Get source code root_dir from source_files in .podspecs Assume the
    root_dir is with the format:

    {module_name}/Sources or {module_name}/Source
    """
  MODULE_ROOT_PATCH = {
      'FirebaseFirestoreInternal': 'Firestore/Source',
      'FirebaseFirestore': 'Firestore/Swift/Source',
      'FirebaseCrashlytics': 'Crashlytics/Crashlytics',
  }
  if module_name in MODULE_ROOT_PATCH:
    return MODULE_ROOT_PATCH[module_name]
  if source_files:
    for source_file in source_files:
      if f'{module_name}/Sources' in source_file:
        return f'{module_name}/Sources'
      if f'{module_name}/Source' in source_file:
        return f'{module_name}/Source'
  return ''


def module_info_from_podspecs(root_dir=os.getcwd()):
  result = {}
  for filename in os.listdir(root_dir):
    if filename.endswith('.podspec'):
      podspec_data = parse_podspec(filename)
      source_files = podspec_data.get('source_files')
      if not podspec_data.get('source_files') and podspec_data.get('ios'):
        source_files = podspec_data.get('ios').get('source_files')
      result[podspec_data['name']] = {
          'name': podspec_data['name'],
          'source_files': source_files,
          'public_header_files': podspec_data.get('public_header_files')
      }
  return result


def parse_podspec(podspec_file):
  result = subprocess.run(f'pod ipc spec {podspec_file}',
                          stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE,
                          text=True,
                          shell=True)
  if result.returncode != 0:
    logging.info(f'Error: {result.stderr}')
    return None

  # Parse the JSON output
  podspec_data = json.loads(result.stdout)
  return podspec_data


if __name__ == '__main__':
  main()
