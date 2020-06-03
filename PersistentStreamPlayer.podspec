Pod::Spec.new do |s|
  s.name             = 'PersistentStreamPlayer'
  s.version          = '1.0.0'
  s.summary          = 'Stream audio over http while persisting the streamed data to a local file'
  s.description      = 'Stream audio over http while persisting the streamed data to a local file'
  s.homepage         = 'https://github.com/calmcom/PersistentStreamPlayer'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'calmcom' => 'support@calm.com' }
  s.source           = { :git => 'https://github.com/calmcom/PersistentStreamPlayer.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.source_files = '*.{h,m}'
  s.frameworks = 'AVFoundation', 'MobileCoreServices'
end
