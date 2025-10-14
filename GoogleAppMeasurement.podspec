Pod::Spec.new do |s|
    s.name             = 'GoogleAppMeasurement'
    s.version          = '12.5.0'
    s.summary          = 'Shared measurement methods for Google libraries. Not intended for direct use.'

    s.description      = <<-DESC
    Measurement methods that are shared between
    Google libraries. This pod does not expose
    any headers and isn't intended for direct
    use, but rather as a dependency of some
    Google libraries.
    DESC

    s.homepage         = 'https://developers.google.com/ios'
    s.license          = { :type => 'Copyright', :text => 'Copyright 2022 Google' }
    s.authors          = 'Google, Inc.'

    s.source           = {
        :http => 'https://dl.google.com/firebase/ios/analytics/2eb2929f64cc5fb8/GoogleAppMeasurement-12.4.0.tar.gz'
    }

    s.cocoapods_version = '>= 1.12.0'

    s.ios.deployment_target = '15.0'
    s.osx.deployment_target  = '10.15'
    s.tvos.deployment_target = '15.0'

    s.libraries  = 'c++', 'sqlite3', 'z'
    s.frameworks = 'StoreKit'

    s.dependency 'GoogleUtilities/AppDelegateSwizzler', '~> 8.1'
    s.dependency 'GoogleUtilities/MethodSwizzler', '~> 8.1'
    s.dependency 'GoogleUtilities/NSData+zlib', '~> 8.1'
    s.dependency 'GoogleUtilities/Network', '~> 8.1'
    s.dependency 'nanopb', '~> 3.30910.0'

    s.default_subspecs = 'Default'

    s.subspec 'Default' do |ss|
        ss.dependency 'GoogleAppMeasurement/Core', '12.5.0'
        ss.dependency 'GoogleAppMeasurement/IdentitySupport', '12.5.0'
        ss.ios.dependency 'GoogleAdsOnDeviceConversion', '~> 3.1.0'
    end

    s.subspec 'Core' do |ss|
        ss.vendored_frameworks = 'Frameworks/GoogleAppMeasurement.xcframework'
    end

    s.subspec 'IdentitySupport' do |ss|
        ss.dependency 'GoogleAppMeasurement/Core', '12.5.0'
        ss.vendored_frameworks = 'Frameworks/GoogleAppMeasurementIdentitySupport.xcframework'
    end
end
