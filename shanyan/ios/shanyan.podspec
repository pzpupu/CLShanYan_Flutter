#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'shanyan'
  s.version          = '2.3.5.1'
  s.summary          = '闪验SDK Flutter plguin.'
  s.description      = <<-DESC
A new Flutter plugin.
                       DESC
  s.homepage         = 'https://shanyan.253.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { '253' => 'app@253.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.static_framework = true
  # 与官方 Flutter 提交配套的原生版本固定，避免 pod install 隐式升级二进制。
  s.ios.dependency 'CL_ShanYanSDK', '= 2.3.7.7'
  s.ios.deployment_target = '15.0'
end

