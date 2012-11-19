# -*- coding: utf-8 -*-
require 'base64'
require 'pit'

module GitIssue
class GitIssue::Bitbucket < GitIssue::Base
  def initialize(args, options = {})
    super(args, options)

    @repo = configured_value('issue.repo')
    if @repo.blank?
      url = `git config remote.origin.url`.strip
      @repo = url.match(/bitbucket.org[:\/](.+)\.git/)[1]
    end

    @user = options[:user] || configured_value('issue.user')
    @user = global_configured_value('bitbucket.user') if @user.blank?
    @user = Pit.get("bitbucket", :require => {
        "user" => "Your user name in Bitbucket",
    })["user"] if @user.blank?

    configure_error('user', "git config issue.user yuroyoro")  if @user.blank?
    @ssl_options = {}
    if @options.key?(:sslNoVerify) && RUBY_VERSION < "1.9.0"
      @ssl_options[:ssl_verify_mode] = OpenSSL::SSL::VERIFY_NONE
    elsif configured_value('http.sslVerify') == "false"
      @ssl_options[:ssl_verify_mode] = OpenSSL::SSL::VERIFY_NONE
    end
    if (ssl_cert = configured_value('http.sslCert'))
      @ssl_options[:ssl_ca_cert] = ssl_cert
    end
  end

  def commands
    cl = super
    cl << GitIssue::Command.new(:mention, :men, 'create a comment to given issue')
    cl << GitIssue::Command.new(:close , :cl, 'close an issue with comment. comment is optional.')
  end

  def show(options = {})
    ticket = options[:ticket_id]
    raise 'ticket_id is required.' unless ticket
    issue = fetch_issue(ticket, options)

    if options[:oneline]
      puts oneline_issue(issue, options)
    else
      comments = []

      if issue['comment_count'] > 0
        comments = fetch_comments(ticket) unless options[:supperss_comments]
      end
      puts ""
      puts format_issue(issue, comments, options)
    end
  end

  def list(options = {})
    state = options[:status] || "open"

    query_names = [:status, :milestone, :assignee, :mentioned, :labels, :sort, :direction]
    params = query_names.inject({}){|h,k| h[k] = options[k] if options[k];h}
    params[:status] ||= "open"
    params[:per_page] = options[:max_count] || 30

    url = to_url("repositories", @repo, 'issues')

    issues = fetch_json(url, options, params)
    issues = issues['issues']
    issues = issues.sort_by{|i| i['local_id']} unless params[:sort] || params[:direction]

    t_max = issues.map{|i| mlength(i['title'])}.max
    l_max = issues.map{|i| mlength(i['metadata']['kind'])}.max
    u_max = issues.map{|i| mlength(i['reported_by']['username'])}.max

    or_zero = lambda{|v| v.blank? ? "0" : v }

    issues.each do |i|
      puts sprintf("%s  %s  %s  %s  %s c:%s v:%s p:%s %s %s",
                   apply_fmt_colors(:id, sprintf('#%-4d', i['local_id'])),
                   apply_fmt_colors(:state, i['status']),
                   mljust(i['title'], t_max),
                   apply_fmt_colors(:login, mljust(i['reported_by']['username'], u_max)),
                   apply_fmt_colors(:labels, mljust(i['metadata']['kind'], l_max)),
                   or_zero.call(i['comment_count']),
                   or_zero.call(i['votes']),
                   or_zero.call(i['position']),
                   to_date(i['created_on']),
                   to_date(i['utc_last_updated'])
                   )
    end

  end

  def mine(options = {})
    raise "Not implemented yet."

    list(options.merge(:assignee => @user))
  end

  def add(options = {})
    property_names = [:title, :content, :assignee, :milestone, :labels]

    message = <<-MSG
### Write title here ###

### descriptions here ###
    MSG

    unless options[:title]
      options[:title], options[:content] = get_title_and_body_from_editor(message)
    end

    url = to_url("repositories", @repo, 'issues')

    issue = post_json(url, nil, options)
    puts "created issue #{oneline_issue(issue)}"
  end

  def update(options = {})

    ticket = options[:ticket_id]
    raise 'ticket_id is required.' unless ticket

    property_names = [:title, :content, :assignee, :milestone, :labels, :status]

    if options.slice(*property_names).empty?
      issue = fetch_issue(ticket)
      message = "#{issue['title']}\n\n#{issue['content']}"
      options[:title], options[:content] = get_title_and_body_from_editor(message)
    end

    url = to_url("repositories", @repo, 'issues', ticket)

    issue = put_json(url, nil, options) # use POST instead of PATCH.
    puts "updated issue #{oneline_issue(issue)}"
  end


  def mention(options = {})

    ticket = options[:ticket_id]
    raise 'ticket_id is required.' unless ticket

    unless options[:content]
      options[:content] = get_body_from_editor("### comment here ###")
    end
    raise 'comment content is required.' unless options[:content]

    url = to_url("repositories", @repo, 'issues', ticket, 'comments')

    issue = post_json(url, nil, options)

    issue = fetch_issue(ticket)
    puts "commented issue #{oneline_issue(issue)}"
  end

  def branch(options = {})
    ticket = options[:ticket_id]
    raise 'ticket_id is required.' unless ticket

    branch_name = ticket_branch(ticket)

    if options[:force]
      system "git branch -D #{branch_name}" if options[:force]
      system "git checkout -b #{branch_name}"
    else
      if %x(git branch -l | grep "#{branch_name}").strip.empty?
        system "git checkout -b #{branch_name}"
      else
        system "git checkout #{branch_name}"
      end
    end

    show(options)
  end

  def close(options = {})

    ticket = options[:ticket_id]
    raise 'ticket_id is required.' unless ticket

    unless options[:content]
      options[:content] = get_body_from_editor("### comment here ###")
    end

    options[:status] = "resolved" unless options[:status]

    url = to_url("repositories", @repo, 'issues', ticket)

    issue = put_json(url, nil, options)

    comment_url = to_url("repositories", @repo, 'issues', ticket, 'comments')
    post_json(comment_url, nil, options)

    puts "closed issue #{oneline_issue(issue)}"
  end

  private

  ROOT = 'https://api.bitbucket.org/1.0/'
  def to_url(*path_list)
    URI.join(ROOT, path_list.join("/"))
  end

  def fetch_json(url, options = {}, params = {})
    response = send_request(url, {},options, params, :get)
    json = JSON.parse(response.body)

    raise error_message(json) unless response_success?(response)

    if @debug
      puts '-' * 80
      puts url
      pp json
      puts '-' * 80
    end

    json
  end

  def fetch_issue(ticket_id, params = {})
    url = to_url("repositories", @repo, 'issues', ticket_id)
    # url += "?" + params.map{|k,v| "#{k}=#{v}"}.join("&") unless params.empty?
    json = fetch_json(url, {}, params)

    issue = json['issue'] || json
    raise "no such issue #{ticket} : #{base}" unless issue

    issue
  end

  def fetch_comments(ticket_id)
    url = to_url("repositories", @repo, 'issues', ticket_id, 'comments')
    json = fetch_json(url) || []
  end

  def build_issue_json(options, property_names)
    json = property_names.inject({}){|h,k| h[k] = options[k] if options[k]; h}
    json[:labels] = json[:labels].split(",") if json[:labels]
    json
  end

  def post_json(url, json, options, params = {})
    response = send_request(url, json, options, params, :post)
    json = JSON.parse(response.body)

    raise error_message(json) unless response_success?(response)
    json
  end

  def put_json(url, json, options, params = {})
    response = send_request(url, json, options, params, :put)
    json = JSON.parse(response.body)

    raise error_message(json) unless response_success?(response)
    json
  end

  def error_message(json)
    msg = [json['message']]
    msg += json['errors'].map(&:pretty_inspect) if json['errors']
    msg.join("\n  ")
  end

  def send_request(url, json = {}, options = {}, params = {}, method = :post)
    url = "#{url}"
    uri = URI.parse(url)

    if @debug
      puts '-' * 80
      puts url
      pp json
      puts '-' * 80
    end

    https = connection(uri.host, uri.port)
    https.use_ssl = true
    https.verify_mode = @ssl_options[:ssl_verify_mode] || OpenSSL::SSL::VERIFY_NONE

    store = OpenSSL::X509::Store.new
    if @ssl_options[:ssl_ca_cert].present?
      if File.directory? @ssl_options[:ssl_ca_cert]
        store.add_path @ssl_options[:ssl_ca_cert]
      else
        store.add_file @ssl_options[:ssl_ca_cert]
      end
      http.cert_store = store
    else
      store.set_default_paths
    end
    https.cert_store = store

    https.set_debug_output $stderr if @debug && https.respond_to?(:set_debug_output)

    https.start{|http|

      path = "#{uri.path}"
      if method == :post or method == :put then
        post_options = options.map{|k,v| "#{k}=#{v}"}.join("&")
      else
        path += "?" + params.map{|k,v| "#{k}=#{v}"}.join("&") unless params.empty?
      end

      request = case method
        when :post then Net::HTTP::Post.new(path)
        when :put  then Net::HTTP::Put.new(path)
        when :get  then Net::HTTP::Get.new(path)
        else raise "unknown method #{method}"
      end

      password = options[:password] || get_password(@user)

      request.basic_auth @user, password

      if json != nil then
        request.set_content_type("application/json")
        request.body = json.to_json if json.present?
      elsif method == :post or method == :put then
        request.set_content_type("application/x-www-form-urlencoded")
        request.body = post_options
      end

      response = http.request(request)
      if @debug
        puts "#{response.code}: #{response.msg}"
        puts response.body
      end

      response
    }
  end

  def get_password(user)
    Pit.get("bitbucket", :require => {
        "password" => "Your password in Bitbucket",
    })["password"]
  end

  def oneline_issue(issue, options = {})
    issue_title(issue)
  end

  def format_issue(issue, comments, options)
    msg = [""]

    msg << issue_title(issue)
    msg << "-" * 80
    msg << issue_author(issue)
    msg << ""

    props = []
    props << ['comments', issue['comments']]
    props << ['votes', issue['votes']]
    props << ['position', issue['position']]
    props << ['milestone', issue['milestone']['title']] unless issue['milestone'].blank?

    props.each_with_index do |p,n|
      row = sprintf("%s : %s", mljust(p.first, 18), mljust(p.last.to_s, 24))
      if n % 2 == 0
        msg << row
      else
        msg[-1] = "#{msg.last} #{row}"
      end
    end

    msg << sprintf("%s : %s", mljust('kind', 18), apply_fmt_colors(:labels, issue['metadata']['kind']))
    msg << sprintf("%s : %s", mljust('updated_at', 18), Time.parse(issue['utc_last_updated']))

    # display description
    msg << "-" * 80
    msg << "#{issue['content']}"
    msg << ""

    # display comments
    if comments && !comments.empty?
      msg << "-" * 80
      msg << ""
      cmts = format_comments(comments)
      msg += cmts.map{|s| "  #{s}"}
    end

    msg.join("\n")
  end

  def issue_title(issue)

    "[#{apply_fmt_colors(:state, issue['status'])}] #{apply_fmt_colors(:id, "##{issue['local_id']}")} #{issue['title']}"
  end

  def issue_author(issue)
    author     = issue['reported_by']['username']
    created_on = issue['created_on']

    msg = "#{apply_fmt_colors(:login, author)} opened this issue #{Time.parse(created_on)}"
    msg
  end

  def format_comments(comments)
    cmts = []
    comments.sort_by{|c| c['utc_created_on']}.each_with_index do |c,n|
      cmts += format_comment(c,n)
    end
    cmts
  end

  def format_comment(c, n)
    cmts = []

    cmts << "##{n + 1} - #{c['author_info']['username']}が#{time_ago_in_words(c['utc_created_on'])}に更新"
    cmts << "-" * 78
    cmts +=  c['content'].split("\n").to_a if c['content']
    cmts << ""
  end

  def opt_parser
    opts = super
    opts.on("--supperss_comments", "-sc", "show issue journals"){|v| @options[:supperss_comments] = true}
    opts.on("--title=VALUE", "Title of issue.Use the given value to create/update issue."){|v| @options[:title] = v}
    opts.on("--body=VALUE", "Body content of issue.Use the given value to create/update issue."){|v| @options[:content] = v}
    opts.on("--state=VALUE",   "Use the given value to create/update issue. or query of listing issues.Where 'state' is either 'open' or 'closed'"){|v| @options[:status] = v}
    opts.on("--milestone=VALUE", "Use the given value to create/update issue. or query of listing issues, (Integer Milestone number)"){|v| @options[:milestone] = v }
    opts.on("--assignee=VALUE", "Use the given value to create/update issue. or query of listing issues, (String User login)"){|v| @options[:assignee] = v }
    opts.on("--mentioned=VALUE", "Query of listing issues, (String User login)"){|v| @options[:mentioned] = v }
    opts.on("--labels=VALUE", "Use the given value to create/update issue. or query of listing issues, (String list of comma separated Label names)"){|v| @options[:labels] = v }
    opts.on("--sort=VALUE", "Query of listing issues, (created,  updated,  comments,  default: created)"){|v| @options[:sort] = v }
    opts.on("--direction=VALUE", "Query of listing issues, (asc or desc,  default: desc.)"){|v| @options[:direction] = v }
    opts.on("--since=VALUE", "Query of listing issue, (Optional string of a timestamp in ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ)"){|v| @options[:since] = v }

    opts.on("--password=VALUE", "For Authorizaion of create/update issue.  Github API v3 doesn't supports API token base authorization for now. then, use Basic Authorizaion instead token." ){|v| @options[:password]}
    opts.on("--sslnoverify", "don't verify SSL"){|v| @options[:sslNoVerify] = true}
    opts
  end

  def apply_fmt_colors(key, str)
    fmt_colors[key.to_sym] ? apply_colors(str, *Array(fmt_colors[key.to_sym])) : str
  end

  def fmt_colors
    @fmt_colors ||= { :id => [:bold, :cyan], :state => :blue,
      :login => :magenta, :labels => :yellow}
  end

end
end
