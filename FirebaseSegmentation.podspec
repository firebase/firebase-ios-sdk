#
# Be sure to run `pod lib lint FirebaseSegmentation.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FirebaseSegmentation'
  s.version          = '0.1.0'
  s.summary          = 'Firebase Segmentation SDK for user segmentation.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Firebase Segmentation enables you to associate your custom application instance ID with Firebase for user segmentation.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Segmentation-' + s.version.to_s
  }
   s.social_media_url = 'https://twitter.com/Firebase'

  s.ios.deployment_target = '8.0'

  base_dir = "Firebase/Segmentation/"
  s.source_files = base_dir + '**/*.[mh]'
  s.requires_arc = base_dir + '*.m'
  s.public_header_files = base_dir + 'Public/*.h'
  s.private_header_files = base_dir + 'Private/*.h'
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_TREAT_WARNINGS_AS_ERRORS' => 'YES',
    'CLANG_UNDEFINED_BEHAVIOR_SANITIZER_NULLABILITY' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
    'FIRSegmentation_LIB_VERSION=' + String(s.version)
  }
  s.framework = 'Foundation'
  s.dependency 'FirebaseCore', '~> 6.0'
  s.dependency 'FirebaseInstanceID', '~> 4.1.1'

  s.test_spec 'unit' do |unit_tests|
    unit_tests.source_files = 'Example/Segmentation/Tests/*.[mh]'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
    unit_tests.pod_target_xcconfig = {
      # Unit tests do library imports using repo-root relative paths.
      'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"/Firebase/Segmentation/**',
      'CLANG_ENABLE_OBJC_WEAK' => 'YES'
    }
  end
end
