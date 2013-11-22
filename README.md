# Gemgem

## DESCRIPTION:

Provided tasks:

    rake clean        # Remove ignored files
    rake gem:build    # Build gem
    rake gem:install  # Install gem
    rake gem:release  # Release gem
    rake gem:spec     # Generate gemspec
    rake test         # Run tests in memory

## REQUIREMENTS:

* Tested with MRI (official CRuby) 1.9.3, 2.0.0, Rubinius and JRuby.

## INSTALLATION:

    git submodule add git://github.com/godfat/gemgem.git task

And in Rakefile:

``` ruby
begin
  require "#{dir = File.dirname(__FILE__)}/task/gemgem"
rescue LoadError
  sh 'git submodule update --init'
  exec Gem.ruby, '-S', $PROGRAM_NAME, *ARGV
end

Gemgem.init(dir) do |s|
  s.name    = 'your-gem'
  s.version = '0.1.0'
end
```

## LICENSE:

Apache License 2.0

Copyright (c) 2011-2013, Lin Jen-Shin (godfat)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
