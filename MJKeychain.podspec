#
# Be sure to run `pod lib lint MJKeychain.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MJKeychain'
  s.version          = '0.1.3'
  s.summary          = 'MJKeychain is use to access the Keychain in iOS'

  s.homepage         = 'https://github.com/Musjoy/MJKeychain'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Raymomd' => 'Ray.musjoy@gmail.com' }
  s.source           = { :git => 'https://github.com/Musjoy/MJKeychain.git', :tag => "v-#{s.version}" }

  s.ios.deployment_target = '8.0'

  s.source_files = 'MJKeychain/Classes/**/*'

  s.user_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' => 'MODULE_KEYCHAIN'
  }
  s.dependency 'ModuleCapability'
  s.prefix_header_contents = '#import <ModuleCapability.h>'

end
