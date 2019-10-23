Pod::Spec.new do |s|
  s.name             = 'GoogleUtilitiesComponentContainer'
  s.version          = '1.0.0'
  s.summary          = 'Google Utilities Component Container for Apple platforms.'

  s.description      = <<-DESC
An internal Google utility that is a dependency injection system for SDKs to depend on other SDKs in
a type safe and potentially weak manner.
Not intended for direct public usage.
                       DESC

  s.homepage         = 'https://github.com/firebase/firebase-ios-sdk/tree/master/GoogleUtilitiesComponentContainer'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'UtilitiesComponentContainer-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  s.source_files = 'GoogleUtilitiesComponentContainer/Sources/**/*.[mh]'
  s.public_header_files = 'GoogleUtilitiesComponentContainer/Sources/Private/*.h'
  s.private_header_files = 'GoogleUtilitiesComponentContainer/Sources/Private/*.h'
  s.dependency 'GoogleUtilities/Logger'

  s.test_spec 'unit' do |unit_tests|
    unit_tests.source_files = 'GoogleUtilitiesComponentContainer/Tests/**/*.[mh]'
    unit_tests.requires_arc = 'GoogleUtilitiesComponentContainer/Tests/*/*.[mh]'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
  end
end
