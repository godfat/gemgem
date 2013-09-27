
module Gemgem
  class << self
    attr_accessor :dir, :spec
  end

  module_function
  def init dir
    self.dir = dir
    $LOAD_PATH.unshift("#{dir}/lib")
    ENV['PATH'] = "#{dir}/bin:#{ENV['PATH']}"
  end

  def create
    yield(spec = Gem::Specification.new{ |s|
      s.authors     = ['Lin Jen-Shin (godfat)']
      s.email       = ['godfat (XD) godfat.org']

      s.description = description.join
      s.summary     = description.first
      s.license     = readme['LICENSE'].sub(/.+\n\n/, '').lines.first.strip

      s.rubygems_version = Gem::VERSION
      s.date             = Time.now.strftime('%Y-%m-%d')
      s.files            = gem_files
      s.test_files       = test_files
      s.executables      = bin_files
      s.require_paths    = %w[lib]
    })
    spec.homepage ||= "https://github.com/godfat/#{spec.name}"
    spec
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

  def changes
    @changes ||=
      if (path = "#{Gemgem.dir}/CHANGES.md") && File.exist?(path)
        date = '\d+{4}\-\d+{2}\-\d{2}'
        File.read(path).match(
          /([^\n]+#{date}\n\n(.+?))(?=\n\n[^\n]+#{date}\n|\Z)/m)[1]
      else
        ''
      end
  end

  def ann_md
     "#{readme['HEADER'].sub(/([\w\-]+)/, "[\\1](#{spec.homepage})")}\n\n" \
    "##{readme['DESCRIPTION'][/[^\n]+\n\n[^\n]+/]}\n\n"                    \
    "### CHANGES:\n\n"                                                     \
    "###{changes}\n\n"                                                     \
    "##{readme['INSTALLATION']}\n\n"                                       +
    if readme['SYNOPSIS'] then "##{readme['SYNOPSIS'][/[^\n]+\n\n[^\n]+/]}"
    else '' end
  end

  def ann_html
    gem 'nokogiri'
    gem 'kramdown'

    IO.popen('kramdown', 'r+') do |md|
      md.puts Gemgem.ann_md
      md.close_write
      require 'nokogiri'
      html = Nokogiri::XML.parse("<gemgem>#{md.read}</gemgem>")
      html.css('*').each{ |n| n.delete('id') }
      html.root.children.to_html
    end
  end

  def ann_email
    "#{readme['HEADER'].sub(/([\w\-]+)/, "\\1 <#{spec.homepage}>")}\n\n" \
    "#{readme['DESCRIPTION']}\n\n"                                       \
    "#{readme['INSTALLATION']}\n\n"                                      +
    if readme['SYNOPSIS'] then "##{readme['SYNOPSIS']}\n\n" else '' end  +
    "## CHANGES:\n\n"                                                    \
    "##{changes}\n\n"
  end

  def gem_tag
    "#{spec.name}-#{spec.version}"
  end

  def write
    File.open("#{dir}/#{spec.name}.gemspec", 'w'){ |f|
      f << split_lines(spec.to_ruby) }
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

  def escaped_dir
    @escaped_dir ||= Regexp.escape(dir)
  end

  def gem_files
    @gem_files ||=
      Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH).inject([]){ |files, path|
        if File.file?(path) && path !~ %r{/\.git(/|$)}  &&
           (rpath = path[%r{^#{escaped_dir}/(.*$)}, 1]) &&
           (rpath !~ ignored_pattern || git_files.include?(rpath))
          files << rpath
        else
          files
        end
      }.sort
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
  sh("#{Gem.ruby} -S gem install pkg/#{Gemgem.gem_tag}.gem")
end

desc 'Build gem'
task :build => [:spec] do
  sh("#{Gem.ruby} -S gem build #{Gemgem.spec.name}.gemspec")
  sh("mkdir -p pkg")
  sh("mv #{Gemgem.gem_tag}.gem pkg/")
end

desc 'Release gem'
task :release => [:spec, :check, :build] do
  sh("git tag #{Gemgem.gem_tag}")
  sh("git push")
  sh("git push --tags")
  sh("#{Gem.ruby} -S gem push pkg/#{Gemgem.gem_tag}.gem")
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

desc 'Run tests with shell'
task 'test:shell', :RUBY_OPTS do |t, args|
  cmd = [Gem.ruby, args[:RUBY_OPTS],
         '-I', 'lib', '-S', 'bacon', '--quiet', *Gemgem.test_files]

  sh(cmd.compact.join(' '))
end

desc 'Generate ann markdown'
task 'ann:md' => ['gem:spec'] do
  puts Gemgem.ann_md
end

desc 'Generate ann html'
task 'ann:html' => ['gem:spec'] do
  puts Gemgem.ann_html
end

desc 'Generate ann email'
task 'ann:email' => ['gem:spec'] do
  puts Gemgem.ann_email
end

desc 'Generate rdoc'
task :doc => ['gem:spec'] do
  sh("yardoc -o rdoc --main README.md" \
     " --files #{Gemgem.spec.extra_rdoc_files.join(',')}")
end

desc 'Remove ignored files'
task :clean => ['gem:spec'] do
  trash = "~/.Trash/#{Gemgem.spec.name}/"
  sh "mkdir -p #{trash}" unless File.exist?(File.expand_path(trash))
  Gemgem.ignored_files.each{ |file| sh "mv #{file} #{trash}" }
end

task :default do
  exec "#{Gem.ruby} -S #{$PROGRAM_NAME} -f #{Rake.application.rakefile} -T"
end
