#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

$KCODE="UTF8"

require 'pp'
require 'rubygems'
require 'uri'
require 'open-uri'
require "net/http"
require "uri"
require 'fileutils'
require 'json'
require 'optparse'
require 'tempfile'

require File.dirname(__FILE__) + '/git_issue/base'
require File.dirname(__FILE__) + '/git_issue/redmine'

module GitIssue

  COMMAND = [:show, :list, :mine, :commit, :update, :branch, :help]
  COMMAND_ALIAS = { :s => :show, :l => :list, :m=> :mine, :c => :commit, :u => :update, :b => :branch, :h => :help}

  USAGE = <<-END
      show    show given issue summary. if given no id, geuss id from current branch name.
      list    listing issues.
      mine    display issues that assigned to you.
      commit  commit with filling issue subject to messsage.if given no id, geuss id from current branch name.
      update  update issue properties. if given no id, geuss id from current branch name.
      branch  checout to branch using specified issue id. if branch dose'nt exisits, create it. (ex ticket/id/<issue_id>)
      help    show usage
  END

  CONFIGURE_MESSAGE = <<-END
  please set issue tracker %s.

    %s
  END

  def self.configure_error(attr_name, example)
    puts CONFIGURE_MESSAGE % [attr_name, example]
    exit(1)
  end


  def self.configured_value(name)
    res = `git config issue.#{name}`
    res.strip
  end

  def self.main(argv)
    its_type = configured_value('type')
    root     = configured_value('url')
    apikey   = configured_value('apikey')

    configure_error('type (redmine | github)', "git config issue.type redmine") if its_type.empty?
    configure_error('url', "git config issue.url http://example.com/redmine")   if root.empty?
    configure_error('apikey', "git config issue.apikey some_api_key")           if apikey.empty?

    its_klass = its_klass_of(its_type)
    its_klass.new(root, apikey, ARGV).execute

  end

  def self.its_klass_of(its_type)
    case its_type
      when /redmine/i then GitIssue::Redmine
      when /github/i  then GitIssue::Github
      else
        puts "unknown issue tracker type : #{its_type}"
        exit(1)
    end
  end


  # ITS.new(ARGV).execute
end

