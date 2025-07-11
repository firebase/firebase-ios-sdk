#!/usr/bin/env python3

"""Creates release notes files."""

import argparse
import os
import subprocess


def main():
  changelog_location = find_changelog_location()

  parser = argparse.ArgumentParser(description='Create release notes files.')
  parser.add_argument(
      '--version', '-v', required=True, help='Specify the release number.'
  )
  parser.add_argument('--date', help='Specify the date.')
  parser.add_argument(
      '--repo',
      '-r',
      required=True,
      help='The absolute path to the root of the repo containing changelogs.',
  )
  parser.add_argument(
      'products',
      help=(
          'The products to create changelogs for, separated by a comma (no'
          ' space).'
      ),
  )
  args = parser.parse_args()

  # Check all inputs are valid product names
  products = args.products.split(',')
  product_paths = product_relative_locations()
  for i, product in enumerate(products):
    if product_paths[product] is None:
      print('Unknown product ' + product, file=sys.stderr)
      sys.exit(-1)

  created_files = []
  repo = args.repo
  for i, product in enumerate(products):
    changelog = ''
    if product == 'Firestore' or product == 'Crashlytics':
      changelog = product + '/CHANGELOG.md'
    else:
      changelog = 'Firebase' + product + '/CHANGELOG.md'
    result = subprocess.run(
        [
            'python3',
            'scripts/make_release_notes.py',
            changelog,
            '-r',
            'firebase/firebase-ios-sdk',
        ],
        cwd=repo,
        capture_output=True,
        text=True,
        check=True,
    )
    generated_note = result.stdout
    target_path = (
        changelog_location
        + product_paths[product]
        + '-m'
        + args.version
        + '.md'
    )
    with open(target_path, 'w') as file:
      file.write(generated_note)
    created_files.append(target_path)

  output = '\n'.join(created_files)
  print(output)


def find_changelog_location():
  wd = os.getcwd()
  google3_index = wd.rfind('google3')
  if google3_index == -1:
    print('This script must be invoked from a SrcFS volume', file=sys.stderr)
    sys.exit(-1)
  google3_root = wd[: google3_index + len('google3')]
  changelog_relative = (
      '/third_party/devsite/firebase/en/docs/ios/_ios-release-notes/'
  )
  changelog_absolute = google3_root + changelog_relative
  return changelog_absolute


def product_relative_locations():
  module_names = [
      'ABTesting',
      'AI',
      # Note: Analytics is generated separately.
      'AppCheck',
      'Auth',
      'Core',
      'Crashlytics',
      'Database',
      'Firestore',
      'Functions',
      'Installations',
      'Messaging',
      'Storage',
      'RemoteConfig',
      # Note: Data Connect must be generated manually.
  ]
  # Most products follow the format Product/_product(-version.md)
  relative_paths = {}
  for index, name in enumerate(module_names):
    path = name + '/_' + name.lower()
    relative_paths[name] = path

  # There are a few exceptions
  relative_paths['AppDistribution'] = 'AppDistribution/_appdist'
  relative_paths['InAppMessaging'] = 'InAppMessaging/_fiam'
  relative_paths['Performance'] = 'Performance/_perf'
  return relative_paths


if __name__ == '__main__':
  main()
