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


    def configured_value(name)
      res = `git config issue.#{name}`
      res.strip
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

    module_function :configured_value, :global_configured_value, :configure_error, :its_klass_of
  end

  def self.main(argv)
    status = true

    begin
      its_type = Helper.configured_value('type')

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
