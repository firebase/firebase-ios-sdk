Pod::Spec.new do |s|
    s.name             = 'GoogleAppMeasurement'
    s.version          = '11.14.0'
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
        :http => 'https://dl.google.com/firebase/ios/analytics/947bee486051ffca/GoogleAppMeasurement-11.14.0.tar.gz'
    }

    s.cocoapods_version = '>= 1.12.0'

    s.ios.deployment_target  = '12.0'
    s.osx.deployment_target  = '10.15'
    s.tvos.deployment_target = '13.0'

    s.libraries  = 'c++', 'sqlite3', 'z'
    s.frameworks = 'StoreKit'

    s.dependency 'GoogleUtilities/AppDelegateSwizzler', '~> 8.1'
    s.dependency 'GoogleUtilities/MethodSwizzler', '~> 8.1'
    s.dependency 'GoogleUtilities/NSData+zlib', '~> 8.1'
    s.dependency 'GoogleUtilities/Network', '~> 8.1'
    s.dependency 'nanopb', '~> 3.30910.0'

    s.default_subspecs = 'Default'

    s.subspec 'Default' do |ss|
        ss.dependency 'GoogleAppMeasurement/Core', '11.14.0'
        ss.dependency 'GoogleAppMeasurement/IdentitySupport', '11.14.0'
        ss.ios.dependency 'GoogleAdsOnDeviceConversion', '2.0.0'
    end

    s.subspec 'Core' do |ss|
        ss.vendored_frameworks = 'Frameworks/GoogleAppMeasurement.xcframework'
    end

    s.subspec 'IdentitySupport' do |ss|
        ss.dependency 'GoogleAppMeasurement/Core', '11.14.0'
        ss.vendored_frameworks = 'Frameworks/GoogleAppMeasurementIdentitySupport.xcframework'
    end

    # Deprecated. Use IdentitySupport subspec instead.
    s.subspec 'AdIdSupport' do |ss|
        ss.dependency 'GoogleAppMeasurement/IdentitySupport', '11.14.0'
    end

    # Deprecated. Use Core subspec instead.
    s.subspec 'WithoutAdIdSupport' do |ss|
        ss.dependency 'GoogleAppMeasurement/Core', '11.14.0'
    end
end
