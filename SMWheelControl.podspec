Pod::Spec.new do |s|
  s.name         = 'SMWheelControl'
  s.version      = '0.1'
  s.summary      = 'SMWheelControl is an iOS component allowing the selection of an item from a 360° spinning wheel.'
  s.author = {
    'Cesare Rocchi' => ''
    'Simone Civetta' => 'viteinfinite@gmail.com'
  }
  s.source = {
    :git => 'https://github.com/viteinfinite/SMWheelControl.git',
    :tag => '0.1'
  }
  s.source_files = 'SMWheelControlSample/SMWheelControl/*.{h,m}'
  s.dependency     'QuartzCore'
end