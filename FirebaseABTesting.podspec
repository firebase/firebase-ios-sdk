Pod::Spec.new do |s|
  s.name             = 'FirebaseABTesting'
  s.version          = '4.2.0'
  s.summary          = 'Firebase ABTesting'

  s.description      = <<-DESC
A/B testing is a Firebase service that lets you run experiments across users of
your mobile apps. It lets you learn how well one or more changes to
your app work with a smaller set of users before you roll out changes to all
users. You can run experiments to find the most effective ways to use
Firebase Cloud Messaging and Firebase Remote Config in your app.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'ABTesting-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  base_dir = "FirebaseABTesting/Sources/"
  s.source_files = [
    base_dir + '**/*.[mh]',
   'Interop/Analytics/Public/*.h',
   'FirebaseCore/Sources/Private/*.h',
  ]
  s.requires_arc = base_dir + '*.m'
  s.public_header_files = base_dir + 'Public/FirebaseABTesting/*.h', base_dir + 'Private/*.h'
  s.private_header_files = base_dir + 'Private/*.h'
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'FIRABTesting_VERSION=' + String(s.version),
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }
  s.dependency 'FirebaseCore', '~> 6.10'

  s.test_spec 'unit' do |unit_tests|
    unit_tests.source_files = 'FirebaseABTesting/Tests/Unit/**/*.[mh]'
    unit_tests.resources = 'FirebaseABTesting/Tests/Unit/Resources/*.txt'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
  end
end
