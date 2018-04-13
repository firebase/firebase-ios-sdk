#
# Be sure to run `pod lib lint FirebaseFunctions.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FirebaseFunctions'
  s.version          = '1.0.0'
  s.summary          = 'Cloud Functions for Firebase iOS SDK.'

  s.description      = <<-DESC
iOS SDK for Cloud Functions for Firebase.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.authors          = 'Google, Inc.'
  s.source           = { :git => 'https://github.com/TBD/FirebaseFunctions.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'Functions/FirebaseFunctions/**/*'
  s.public_header_files = 'Functions/FirebaseFunctions/Public/*.h'

  s.dependency 'FirebaseCore', '~> 4.0'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.1'
end
