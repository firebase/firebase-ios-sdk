Pod::Spec.new do |s|
  s.name                    = 'HeartbeatLoggingTestUtils'
  s.version                 = '10.0.0'
  s.summary                 = 'Testing utilities for testing the HeartbeatLogging module'

  s.description             = <<-DESC
  Type declarations and utilities needed for unit testing the HeartbeatLogging module.
  This podspec is for internal testing only and should not be published.
                         DESC

  s.homepage                = 'https://developers.google.com/'
  s.license                 = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors                 = 'Google, Inc.'

  s.source                  = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.pod_target_xcconfig = {
    'ENABLE_TESTING_SEARCH_PATHS'=>'YES'
  }

  s.swift_version           = '5.3'

  s.ios.deployment_target     = '10.0'
  s.osx.deployment_target     = '10.13'
  s.tvos.deployment_target    = '12.0'
  s.watchos.deployment_target = '6.0'

  s.source_files = [
    'HeartbeatLoggingTestUtils/Sources/**/*.swift',
  ]

  s.framework = 'XCTest'

  s.dependency 'FirebaseCoreInternal', '~> 10.0'
end
