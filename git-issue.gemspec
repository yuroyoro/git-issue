# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "git_issue/version"

Gem::Specification.new do |s|
  s.name        = "git-issue"
  s.version     = GitIssue::VERSION
  s.authors     = ["Tomohito Ozaki"]
  s.email       = ["ozaki@yuroyoro.com"]
  s.homepage    = "https://github.com/yuroyoro/git-issue"
  s.summary     = %q{git extention command for issue tracker system.}

  s.rubyforge_project = "git-issue"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # dependencies
  s.add_dependency 'activesupport'
  s.add_dependency 'pit'
end

