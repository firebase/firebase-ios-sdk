Pod::Spec.new do |s|
    s.name             = 'FirebaseInstallations'
    s.version          = '0.1.0'
    s.summary          = 'Firebase Installations for iOS'

    s.description      = <<-DESC
    Firebase Installations for iOS.
                         DESC

    s.homepage         = 'https://firebase.google.com'
    s.license          = { :type => 'Apache', :file => 'LICENSE' }
    s.authors          = 'Google, Inc.'

    s.source           = {
      :git => 'https://github.com/firebase/firebase-ios-sdk.git',
      :tag => 'Installations-' + s.version.to_s
    }
    s.social_media_url = 'https://twitter.com/Firebase'
    s.ios.deployment_target = '8.0'
    s.osx.deployment_target = '10.11'
    s.tvos.deployment_target = '10.0'

    s.cocoapods_version = '>= 1.4.0'
    s.static_framework = true
    s.prefix_header_file = false

    base_dir = "FirebaseInstallations/Source/"
    s.source_files = base_dir + '**/*.[mh]'
    s.exclude_files = base_dir + 'Tests/*'
    s.requires_arc = base_dir + '*.m'
    s.public_header_files = base_dir + 'Public/*.h'
    s.pod_target_xcconfig = {
      'GCC_C_LANGUAGE_STANDARD' => 'c99',
      'GCC_PREPROCESSOR_DEFINITIONS' =>
        'FIRInstallations_LIB_VERSION=' + String(s.version)
    }
    s.framework = 'Security'
    s.dependency 'FirebaseCore', '~> 6.0'
    s.dependency 'PromisesObjC', '~> 1.2'

    s.test_spec 'unit' do |unit_tests|
      unit_tests.source_files = base_dir + 'Tests/*.[mh]'
      unit_tests.requires_app_host = true
      unit_tests.dependency 'OCMock'
    end
  end
