
module Gemgem
  class << self
    attr_accessor :dir, :spec, :spec_create
  end

  module_function
  def gem_tag    ; "#{spec.name}-#{spec.version}"     ; end
  def gem_path   ; "#{pkg_dir}/#{gem_tag}.gem"        ; end
  def spec_path  ; "#{dir}/#{spec.name}.gemspec"      ; end
  def pkg_dir    ; "#{dir}/pkg"                       ; end
  def escaped_dir; @escaped_dir ||= Regexp.escape(dir); end

  def init dir, &block
    self.dir = dir
    $LOAD_PATH.unshift("#{dir}/lib")
    ENV['PATH'] = "#{dir}/bin:#{ENV['PATH']}"
    self.spec_create = block
  end

  def create
    spec = Gem::Specification.new do |s|
      s.authors     = ['Lin Jen-Shin (godfat)']
      s.email       = ['godfat (XD) godfat.org']

      s.description = description.join
      s.summary     = description.first
      s.license     = readme['LICENSE'].sub(/.+\n\n/, '').lines.first.strip

      s.date        = Time.now.strftime('%Y-%m-%d')
      s.files       = gem_files
      s.test_files  = test_files
      s.executables = bin_files
    end
    spec_create.call(spec)
    spec.homepage = "https://github.com/godfat/#{spec.name}"
    self.spec = spec
  end

  def write
    File.open(spec_path, 'w'){ |f| f << split_lines(spec.to_ruby) }
  end

  def split_lines ruby
    ruby.gsub(/(.+?)\s*=\s*\[(.+?)\]/){ |s|
      if $2.index(',')
        "#{$1} = [\n  #{$2.split(',').map(&:strip).join(",\n  ")}]"
      else
        s
      end
    }
  end

  def readme
    @readme ||=
      if (path = "#{Gemgem.dir}/README.md") && File.exist?(path)
        ps = "##{File.read(path)}".
             scan(/((#+)[^\n]+\n\n.+?(?=(\n\n\2[^#\n]+\n)|\Z))/m).map(&:first)
        ps.inject('HEADER' => ps.first){ |r, s, i|
          r[s[/\w+/]] = s
          r
        }
      else
        {}
      end
  end

  def description
    @description ||= (readme['DESCRIPTION']||'').sub(/.+\n\n/, '').lines
  end

  def all_files
    @all_files ||=
      Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH).inject([]){ |files, path|
        if File.file?(path) && path !~ %r{/\.git(/|$)}  &&
           (rpath = path[%r{^#{escaped_dir}/(.*$)}, 1])
          files << rpath
        else
          files
        end
      }.sort
  end

  def gem_files
    @gem_files ||= all_files.reject{ |f|
      f =~ ignored_pattern && !git_files.include?(f)
    }
  end

  def test_files
    @test_files ||= gem_files.grep(%r{^test/(.+?/)*test_.+?\.rb$})
  end

  def bin_files
    @bin_files ||= gem_files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  end

  def git_files
    @git_files ||= if File.exist?("#{dir}/.git")
                     `git --git-dir=#{dir}/.git ls-files`.split("\n")
                   else
                     []
                   end
  end

  def ignored_files
    @ignored_files ||= all_files.grep(ignored_pattern)
  end

  def ignored_pattern
    @ignored_pattern ||= Regexp.new(expand_patterns(gitignore).join('|'))
  end

  def expand_patterns pathes
    # http://git-scm.com/docs/gitignore
    pathes.flat_map{ |path|
      case path
      when %r{\*}
        Regexp.escape(path).gsub(/\\\*/, '[^/]*')
      when %r{^/}
        "^#{Regexp.escape(path[1..-1])}"
      else
        Regexp.escape(path)
      end
    }
  end

  def gitignore
    @gitignore ||= if File.exist?(path = "#{dir}/.gitignore")
                     File.read(path).lines.
                       reject{ |l| l == /^\s*(#|\s+$)/ }.map(&:strip)
                   else
                     []
                   end
  end
end

namespace :gem do

desc 'Install gem'
task :install => [:build] do
  sh("#{Gem.ruby} -S gem install #{Gemgem.gem_path}")
end

desc 'Build gem'
task :build => [:spec] do
  require 'fileutils'
  require 'rubygems/package'
  Dir.chdir(Gemgem.dir) do
    gem = Gem::Package.build(Gem::Specification.load(Gemgem.spec_path))
    FileUtils.mkdir_p(Gemgem.pkg_dir)
    FileUtils.mv(gem, Gemgem.pkg_dir) # gem is relative path, but might be ok
    puts "\e[35mGem built: \e[33m#{Gemgem.pkg_dir}/#{gem}\e[0m"
  end
end

desc 'Generate gemspec'
task :spec do
  Gemgem.create
  Gemgem.write
end

desc 'Release gem'
task :release => [:spec, :check, :build] do
  sh("git tag #{Gemgem.gem_tag}")
  sh("git push")
  sh("git push --tags")
  sh("#{Gem.ruby} -S gem push #{Gemgem.gem_path}")
end

task :check do
  ver = Gemgem.spec.version.to_s

  if ENV['VERSION'].nil?
    puts("\e[35mExpected "                                  \
         "\e[33mVERSION\e[35m=\e[33m#{ver}\e[0m")
    exit(1)

  elsif ENV['VERSION'] != ver
    puts("\e[35mExpected \e[33mVERSION\e[35m=\e[33m#{ver} " \
         "\e[35mbut got\n         "                         \
         "\e[33mVERSION\e[35m=\e[33m#{ENV['VERSION']}\e[0m")
    exit(2)
  end
end

end # of gem namespace

desc 'Run tests in memory'
task :test do
  require 'bacon'
  Bacon.extend(Bacon::TestUnitOutput)
  Bacon.summary_on_exit
  Gemgem.test_files.each{ |file| require "#{Gemgem.dir}/#{file[0..-4]}" }
end

desc 'Remove ignored files'
task :clean => ['gem:spec'] do
  trash = "~/.Trash/#{Gemgem.spec.name}/"
  sh "mkdir -p #{trash}" unless File.exist?(File.expand_path(trash))
  Gemgem.ignored_files.each{ |file| sh "mv #{file} #{trash}" }
end

task :default do
  # Is there a reliable way to do this in the current process?
  # It failed miserably before between Rake versions...
  exec "#{Gem.ruby} -S #{$PROGRAM_NAME} -f #{Rake.application.rakefile} -T"
end
