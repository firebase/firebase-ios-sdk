Pod::Spec.new do |s|
  s.name                    = 'FirebaseStorageSwift'
  s.version                 = '7.3.0-beta'
  s.summary                 = 'Swift Extensions for Google Cloud Storage'

  s.description      = <<-DESC
Firebase Storage provides robust, secure file uploads and downloads from Firebase SDKs, powered by Google Cloud Storage.
                       DESC


  s.homepage                = 'https://developers.google.com/'
  s.license                 = { :type => 'Apache', :file => 'LICENSE' }
  s.authors                 = 'Google, Inc.'

  s.source                  = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.swift_version           = '5.0'
  s.ios.deployment_target   = '10.0'
  s.osx.deployment_target   = '10.12'
  s.tvos.deployment_target  = '10.0'
  s.watchos.deployment_target = '6.0'

  s.cocoapods_version       = '>= 1.4.0'
  s.prefix_header_file      = false

  s.source_files = [
    'FirebaseStorageSwift/Sources/*.swift',
  ]

  s.dependency 'FirebaseStorage', '~> 7.0'

  s.test_spec 'integration' do |int_tests|
    int_tests.platforms = {:ios => '10.0', :osx => '10.12', :tvos => '10.0'}
    int_tests.source_files = 'FirebaseStorageSwift/Tests/Integration/*.swift'
    int_tests.requires_app_host = true
    # Resources are shared with FirebaseStorage's integration tests.
    int_tests.resources = 'FirebaseStorage/Tests/Integration/Resources/1mb.dat',
                          'FirebaseStorage/Tests/Integration/Resources/GoogleService-Info.plist',
                          'FirebaseStorage/Tests/Integration/Resources/HomeImprovement.numbers'
    int_tests.dependency 'FirebaseAuth', '~> 7.0'
  end
end
