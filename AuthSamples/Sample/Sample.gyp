# GYP file to create the Xcode project for the sample app without any
# dependencies.
# This project won't work by itself but can be used to test the Coacopod-based
# distribution of the library with the appropriate Podfile.
{
  'targets': [
    {
      'target_name': 'Sample',
      'type': 'executable',
      'mac_bundle': 1,
      'sources': [
        '<!@(find . -name "*.h" -or -name "*.m")',
      ],
      'mac_bundle_resources': [
        '<!@(find . -name "*.xcassets" -or -name "*.xib" -or -name "*.plist")',
      ],
      'xcode_settings': {
        'INFOPLIST_FILE': 'Application.plist',
        'CODE_SIGN_IDENTITY': 'iPhone Developer',
        'LIBRARY_SEARCH_PATHS': [
          '$(inherited)',
        ],
      },
      'link_settings': {
        'libraries': [
          '$(SDKROOT)/System/Library/Frameworks/Foundation.framework',
          '$(SDKROOT)/System/Library/Frameworks/SafariServices.framework',
          '$(SDKROOT)/System/Library/Frameworks/UIKit.framework',
        ],
      },
    }
  ]
}
