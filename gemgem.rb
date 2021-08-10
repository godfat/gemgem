
module Gemgem
  class << self
    attr_accessor :dir, :spec, :submodules, :spec_create
  end

  module_function
  def gem_tag    ; "#{spec.name}-#{spec.version}"     ; end
  def gem_path   ; "#{pkg_dir}/#{gem_tag}.gem"        ; end
  def spec_path  ; "#{dir}/#{spec.name}.gemspec"      ; end
  def pkg_dir    ; "#{dir}/pkg"                       ; end
  def escaped_dir; @escaped_dir ||= Regexp.escape(dir); end

  def init dir, options={}, &block
    self.dir = dir
    ENV['RUBYLIB'] = "#{dir}/lib:#{ENV['RUBYLIB']}"
    ENV['PATH']    = "#{dir}/bin:#{ENV['PATH']}"
    self.submodules  = options[:submodules] || []
    self.spec_create = block

    $LOAD_PATH.unshift("#{dir}/lib", *submodules_libs)
  end

  def create
    spec = Gem::Specification.new do |s|
      s.authors     = ['Lin Jen-Shin (godfat)']
      s.email       = ['godfat (XD) godfat.org']

      s.description = description.join
      s.summary     = description.first
      s.license     = license

      s.date        = Time.now.strftime('%Y-%m-%d')
      s.files       = gem_files
      s.test_files  = test_files
      s.executables = bin_files
    end
    spec_create.call(spec)
    spec.homepage ||= "https://github.com/godfat/#{spec.name}"
    self.spec = spec
  end

  def gem_install
    require 'rubygems/commands/install_command'
    require 'rubygems/package'
    # read ~/.gemrc
    Gem.use_paths(Gem.configuration[:gemhome], Gem.configuration[:gempath])
    Gem::Command.extra_args = Gem.configuration[:gem]

    # setup install options
    cmd = Gem::Commands::InstallCommand.new
    cmd.handle_options([])

    # install
    gem_package = Gem::Package.new(gem_path)
    install = Gem::Installer.new(gem_package, cmd.options)
    install.install
    puts "\e[35mGem installed: \e[33m#{strip_path(install.gem_dir)}\e[0m"
  end

  def gem_spec
    create
    write
  end

  def gem_build
    require 'fileutils'
    require 'rubygems/package'
    gem = nil
    Dir.chdir(dir) do
      gem = Gem::Package.build(Gem::Specification.load(spec_path))
      FileUtils.mkdir_p(pkg_dir)
      FileUtils.mv(gem, pkg_dir) # gem is relative path, but might be ok
    end
    puts "\e[35mGem built: \e[33m#{strip_path("#{pkg_dir}/#{gem}")}\e[0m"
  end

  def gem_release
    sh_git('tag', gem_tag)
    sh_git('push')
    sh_git('push', '--tags')
    sh_gem('push', gem_path)
  end

  def gem_check
    unless git('status', '--porcelain').empty?
      puts("\e[35mWorking copy is not clean.\e[0m")
      exit(3)
    end

    ver = spec.version.to_s

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

  def test
    return if test_files.empty?

    if ENV['COV'] || ENV['CI']
      require 'simplecov'
      if ENV['CI']
        begin
          require 'coveralls'
          SimpleCov.formatter = Coveralls::SimpleCov::Formatter
        rescue LoadError => e
          puts "Cannot load coveralls, skip: #{e}"
        end
      end
      SimpleCov.start do
        add_filter('test/')
        add_filter('test.rb')
        submodules_libs.each(&method(:add_filter))
      end
    end

    test_files.each{ |file| require "#{dir}/#{file[0..-4]}" }
  end

  def clean
    return if ignored_files.empty?

    require 'fileutils'
    trash = File.expand_path("~/.Trash/#{spec.name}")
    puts "Move the following files into: \e[35m#{strip_path(trash)}\e[33m"

    ignored_files.each do |file|
      from = "#{dir}/#{file}"
      to   = "#{trash}/#{File.dirname(file)}"
      puts strip_path(from)

      FileUtils.mkdir_p(to)
      FileUtils.mv(from, to)
    end

    print "\e[0m"
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

  def strip_path path
    strip_home_path(strip_cwd_path(path))
  end

  def strip_home_path path
    path.sub(/\A#{Regexp.escape(ENV['HOME'])}\//, '~/')
  end

  def strip_cwd_path path
    path.sub(/\A#{Regexp.escape(Dir.pwd)}\//, '')
  end

  def submodules_libs
    submodules.map{ |path| "#{dir}/#{path}/lib" }
  end

  def git *args
    `git --git-dir=#{dir}/.git #{args.join(' ')}`
  end

  def sh_git *args
    Rake.sh('git', "--git-dir=#{dir}/.git", *args)
  end

  def sh_gem *args
    Rake.sh(Gem.ruby, '-S', 'gem', *args)
  end

  def glob path=dir
    Dir.glob("#{path}/**/*", File::FNM_DOTMATCH)
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
    # JRuby String#lines is returning an enumerator
    @description ||= (readme['DESCRIPTION']||'').sub(/.+\n\n/, '').lines.to_a
  end

  def license
    readme['LICENSE'].sub(/.+\n\n/, '').lines.first.
      split(/[()]/).map(&:strip).reject(&:empty?).last
  end

  def all_files
    @all_files ||= fold_files(glob).sort
  end

  def fold_files files
    files.inject([]){ |r, path|
      if File.file?(path) && path !~ %r{/\.git(/|$)}  &&
         (rpath = path[%r{^#{escaped_dir}/(.*$)}, 1])
        r << rpath
      elsif File.symlink?(path) # walk into symlinks...
        r.concat(fold_files(glob(File.expand_path(path,
                                                  File.readlink(path)))))
      else
        r
      end
    }
  end

  def gem_files
    @gem_files ||= all_files.reject{ |f|
      f =~ submodules_pattern ||
        (f =~ ignored_pattern && !git_files.include?(f))
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
                     git('ls-files').split("\n")
                   else
                     []
                   end
  end

  def ignored_files
    @ignored_files ||= all_files.grep(ignored_pattern)
  end

  def ignored_pattern
    @ignored_pattern ||= if gitignore.empty?
                           /^$/
                         else
                           Regexp.new(expand_patterns(gitignore).join('|'))
                         end
  end

  def submodules_pattern
    @submodules_pattern ||= if submodules.empty?
                              /^$/
                            else
                              Regexp.new(submodules.map{ |path|
                                "^#{Regexp.escape(path)}/" }.join('|'))
                            end
  end

  def expand_patterns pathes
    # http://git-scm.com/docs/gitignore
    pathes.flat_map{ |path|
      # we didn't implement negative pattern for now
      Regexp.escape(path).sub(%r{^/}, '^').gsub(/\\\*/, '[^/]*')
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
  Gemgem.gem_install
end

desc 'Build gem'
task :build => [:spec] do
  Gemgem.gem_build
end

desc 'Generate gemspec'
task :spec do
  Gemgem.gem_spec
end

desc 'Release gem'
task :release => [:spec, :check, :build] do
  Gemgem.gem_release
end

task :check do
  Gemgem.gem_check
end

end # of gem namespace

desc 'Run tests'
task :test do
  Gemgem.test
end

desc 'Trash ignored files'
task :clean => ['gem:spec'] do
  Gemgem.clean
end

task :default do
  # Is there a reliable way to do this in the current process?
  # It failed miserably before between Rake versions...
  exec "#{Gem.ruby} -S #{$PROGRAM_NAME} -f #{Rake.application.rakefile} -T"
end
