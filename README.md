# Gemgem

## DESCRIPTION:

Provided tasks:

    rake clean        # Trash ignored files
    rake gem:build    # Build gem
    rake gem:install  # Install gem
    rake gem:release  # Release gem
    rake gem:spec     # Generate gemspec
    rake test         # Run tests

## REQUIREMENTS:

* Tested with MRI (official CRuby) and JRuby.

## INSTALLATION:

    git submodule add git://github.com/godfat/gemgem.git task

And in Rakefile:

``` ruby
begin
  require "#{__dir__}/task/gemgem"
rescue LoadError
  sh 'git submodule update --init --recursive'
  exec Gem.ruby, '-S', $PROGRAM_NAME, *ARGV
end

Gemgem.init(__dir__, :submodules => %w[your-dep]) do |s|
  s.name    = 'your-gem'
  s.version = '0.1.0'
end
```

## LICENSE:

Apache License 2.0 (Apache-2.0)

Copyright (c) 2011-2021, Lin Jen-Shin (godfat)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
