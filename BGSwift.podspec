Pod::Spec.new do |s|
    s.name = 'BGSwift'
    s.platform = :ios, '12.0'
    s.version = '0.5.0'
    s.summary          = 'Behavior Graph is a software library that greatly enhances our ability to program user facing software and control systems.'

    s.description      = <<-DESC
Behavior Graph  is a software library that greatly enhances our ability to program user facing software and control systems. Programs of this type quickly scale up in complexity as features are added. Behavior Graph directly addresses this complexity by shifting more of the burden to the computer. It works by offering the programmer a new unit of code organization called a behavior. Behaviors are blocks of code enriched with additional information about their stateful relationships. Using this information, Behavior Graph enforces _safe use of mutable state_, arguably the primary source of complexity in this class of software. It does this by taking on the responsibility of control flow between behaviors, ensuring they are are _run at the correct time and in the correct order_.
DESC

    s.license = { :type => 'Apache-2.0', :file => 'LICENSE.txt' }
    s.homepage = 'https://www.github.com/yahoo/BGSwift'
    s.authors = {
            'James Lou' => 'jlou@yahooinc.com',
	    'Sean Levin' => 'slevin@yahooinc.com'
    }
    s.source = {
      :git => 'https://github.com/yahoo/bgswift.git',
      :tag => s.version.to_s
    }
    s.requires_arc = true
    s.swift_versions = [4.0, 4.1, 4.2, 5.0, 5.1, 5.2, 5.3, 5.4, 5.5]
    
    s.default_subspecs = 'Core'
    
    s.subspec "Core" do |sp|
        sp.resources = []
        
        sp.source_files =[
        'BGSwift/Classes/**/*.{h,m,swift}',
        ]
        
        sp.public_header_files = [
        ]
        
        sp.frameworks = [
        'Foundation',
        ]
    end
end

