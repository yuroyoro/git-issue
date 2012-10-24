#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

$KCODE="UTF8" if RUBY_VERSION < '1.9.0'

require 'pp'
require 'rubygems'
require 'uri'
require 'open-uri'
require "net/http"
require "net/https"
require "uri"
require 'fileutils'
require 'json'
require 'optparse'
require 'tempfile'
require 'active_support/all'
require 'shellwords'
require 'win32console' if RUBY_PLATFORM.downcase =~ /mswin(?!ce)|mingw|bccwin|cygwin/
require 'term/ansicolor'

module GitIssue
  class Command
    attr_reader :name, :short_name, :description
    def initialize(name, short_name, description)
      @name, @short_name, @description = name, short_name, description
    end
  end

  module Helper

    CONFIGURE_MESSAGE = <<-END
    please set issue tracker %s.

      %s
    END

    def configure_error(attr_name, example)
      raise CONFIGURE_MESSAGE % [attr_name, example]
    end


    def configured_value(name, trim = true)
      res = `git config #{name}`
      res = trim ? res.strip : res
      res
    end

    def global_configured_value(name)
      res = `git config --global #{name}`
      res.strip
    end

    def its_klass_of(its_type)
      case its_type
        when /redmine/i then GitIssue::Redmine
        when /github/i  then GitIssue::Github
        else
          raise "unknown issue tracker type : #{its_type}"
      end
    end

    def git_editor
      # possible: ~/bin/vi, $SOME_ENVIRONMENT_VARIABLE, "C:\Program Files\Vim\gvim.exe" --nofork
      editor = `git var GIT_EDITOR`
      editor = ENV[$1] if editor =~ /^\$(\w+)$/
      editor = File.expand_path editor if (editor =~ /^[~.]/ or editor.index('/')) and editor !~ /["']/
      editor.shellsplit
    end

    def git_dir
      `git rev-parse -q --git-dir`.strip
    end

    def split_head_and_body(text)
      title, body = '', ''
      text.each_line do |line|
        next if line.index('#') == 0
        ((body.empty? and line =~ /\S/) ? title : body) << line
      end
      title.tr!("\n", ' ')
      title.strip!
      body.strip!

      [title =~ /\S/ ? title : nil, body =~ /\S/ ? body : nil]
    end

    def read_body(file)
      f = open(file)
      body = f.read
      f.close
      body.strip
    end

    def get_title_and_body_from_editor(message=nil)
      open_editor(message) do |text|
        title, body = split_head_and_body(text)
        abort "Aborting due to empty issue title" unless title
        [title, body]
      end
    end

    def get_body_from_editor(message=nil)
      open_editor(message) do |text|
        abort "Aborting due to empty message" if text.empty?
        text
      end
    end

    def open_editor(message = nil, abort_if_not_modified = true , &block)
      message_file = File.join(git_dir, 'ISSUE_MESSAGE')
      File.open(message_file, 'w') { |msg|
        msg.puts message
      }
      edit_cmd = Array(git_editor).dup
      edit_cmd << '-c' << 'set ft=gitcommit' if edit_cmd[0] =~ /^[mg]?vim$/
      edit_cmd << message_file

      system(*edit_cmd)
      abort "can't open text editor for issue message" unless $?.success?

      text = read_body(message_file)
      abort "Aborting cause messages didn't modified." if message == text && abort_if_not_modified

      yield text
    end

    module_function :configured_value, :global_configured_value, :configure_error, :its_klass_of, :get_title_and_body_from_editor, :get_body_from_editor
  end

  def self.main(argv)
    status = true

    begin
      its_type = Helper.configured_value('issue.type')

      # Use global config for hub
      if its_type.blank?
        github_user = Helper.global_configured_value('github.user')
        unless github_user.blank?
          its_type = 'github'
        end
      end

      Helper.configure_error('type (redmine | github)', "git config issue.type redmine") if its_type.blank?

      its_klass = Helper.its_klass_of(its_type)
      status = its_klass.new(ARGV).execute || true
    rescue => e
      puts e
      puts e.backtrace.join("\n")
      status = false
    end

    exit(status)
  end

end

require File.dirname(__FILE__) + '/git_issue/base'
require File.dirname(__FILE__) + '/git_issue/redmine'
require File.dirname(__FILE__) + '/git_issue/github'
