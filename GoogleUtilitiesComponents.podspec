Pod::Spec.new do |s|
  s.name             = 'GoogleUtilitiesComponents'
  s.version          = '2.0.0'
  s.summary          = 'Google Utilities Component Container for Apple platforms.'

  s.description      = <<-DESC
An internal Google utility that is a dependency injection system for libraries to depend on other
libraries in a type safe and potentially weak manner.
Not intended for direct public usage.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'UtilitiesComponents-' + s.version.to_s
  }

  s.ios.deployment_target = '12.0'

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false
  s.static_framework = true

  s.source_files = 'GoogleUtilitiesComponents/Sources/**/*.[mh]'
  s.public_header_files = 'GoogleUtilitiesComponents/Sources/Public/*.h', 'GoogleUtilitiesComponents/Sources/Private/*.h'
  s.private_header_files = 'GoogleUtilitiesComponents/Sources/Private/*.h'
  s.dependency 'GoogleUtilities/Logger', "~> 8.0"

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.source_files = 'GoogleUtilitiesComponents/Tests/**/*.[mh]'
    unit_tests.requires_arc = 'GoogleUtilitiesComponents/Tests/*/*.[mh]'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
  end
end
