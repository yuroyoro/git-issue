# -*- coding: utf-8 -*-

module GitIssue
class GitIssue::Github < GitIssue::Base
  def initialize(args, options = {})
    super(args, options)

    @apikey = options[:apikey] || configured_value('apikey')
    @apikey = global_configured_value('github.token') if @apikey.blank?
    configure_error('apikey', "git config issue.apikey some_api_key") if @apikey.blank?

    @repo = options[:repo] || configured_value('repo')
    configure_error('repo', "git config issue.repo git-issue")  if @repo.blank?

    @user = options[:user] || configured_value('user')
    @user = global_configured_value('github.user') if @user.blank?
    configure_error('user', "git config issue.user yuroyoro")  if @user.blank?

  end

  def show(options = {})
    ticket = options[:ticket_id]
    raise 'ticket_id is required.' unless ticket
    issue = fetch_issue(ticket, options)

    if options[:oneline]
      puts oneline_issue(issue, options)
    else
      comments = []
      if issue['comments'].to_i > 0
        comments = fetch_comments(ticket) unless options[:supperss_comments]
      end
      puts ""
      puts format_issue(issue, comments, options)
    end
  end

  def list(options = {})
    state = options[:state] || "open"

    query_names = [:state, :milestone, :assignee, :mentioned, :labels, :sort, :direction]
    params = query_names.inject({}){|h,k| h[k] = options[k] if options[k];h}
    params[:state] ||= "open"

    url = to_url("repos",@user, @repo, 'issues')

    issues = fetch_json(url, params)
    issues = issues.sort_by{|i| i['number'].to_i} unless params[:sort] || params[:direction]

    t_max = issues.map{|i| mlength(i['title'])}.max
    l_max = issues.map{|i| mlength(i['labels'].join(","))}.max
    u_max = issues.map{|i| mlength(i['user']['login'])}.max

    or_zero = lambda{|v| v.blank? ? "0" : v }

    issues.each do |i|
      puts sprintf("#%-4d  %s  %s  %s  %s c:%s v:%s p:%s %s %s",
                   i['number'].to_i,
                   i['state'],
                   mljust(i['title'], t_max),
                   mljust(i['user']['login'], u_max),
                   mljust(i['labels'].join(','), l_max),
                   or_zero.call(i['comments']),
                   or_zero.call(i['votes']),
                   or_zero.call(i['position']),
                   to_date(i['created_at']),
                   to_date(i['updated_at'])
                   )
    end

  end

  def add(options = {})

  end

  def update(options = {})
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

  private

  ROOT = 'https://api.github.com/'
  def to_url(*path_list)
    URI.join(ROOT, path_list.join("/"))
  end

  def fetch_json(url, params = {})
    url += "?" + params.map{|k,v| "#{k}=#{v}"}.join("&") unless params.empty?

    if @debug
      puts url
    end
    json = open(url, {"Authorizaion" => "#{@user}/token:#{@apikey}"}) {|io|
      JSON.parse(io.read)
    }

    if @debug
      puts '-' * 80
      puts url
      pp json
      puts '-' * 80
    end

    json
  end

  def fetch_issue(ticket_id, params = {})
    url = to_url("repos",@user, @repo, 'issues', ticket_id)
    url += "?" + params.map{|k,v| "#{k}=#{v}"}.join("&") unless params.empty?
    json = fetch_json(url)

    issue = json['issue'] || json
    raise "no such issue #{ticket} : #{base}" unless issue

    issue
  end

  def fetch_comments(ticket_id)
    url = to_url("repos",@user, @repo, 'issues', ticket_id, 'comments')
    json = fetch_json(url) || []
  end

  def oneline_issue(issue, options)
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

    msg << sprintf("%s : %s", mljust('labels', 18), issue['labels'].join(","))
    msg << sprintf("%s : %s", mljust('html_url', 18), issue['html_url'])
    msg << sprintf("%s : %s", mljust('updated_at', 18), Time.parse(issue['updated_at']))

    # display description
    msg << "-" * 80
    msg << "#{issue['body']}"
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
    "[#{issue['state']}] ##{issue['number']} #{issue['title']}"
  end

  def issue_author(issue)
    author     = issue['user']['login']
    created_at = issue['created_at']

    msg = "#{author} opened this issue #{Time.parse(created_at)}"
    msg
  end

  def format_comments(comments)
    cmts = []
    comments.sort_by{|c| c['created_at']}.each_with_index do |c,n|
      cmts += format_comment(c,n)
    end
    cmts
  end

  def format_comment(c, n)
    cmts = []

    cmts << "##{n + 1} - #{c['user']['login']}が#{time_ago_in_words(c['created_at'])}に更新"
    cmts << "-" * 78
    cmts +=  c['body'].split("\n").to_a if c['body']
    cmts << ""
  end

  def opt_parser
    opts = super
    opts.on("--supperss_comments", "-sc", "show issue journals"){|v| @options[:supperss_comments] = true}
    opts.on("--state=VALUE",   "Where 'state' is either 'open' or 'closed'"){|v| @options[:state] = v}
    opts.on("--milestone=VALUE", "Query of listing issue, (Integer Milestone number)"){|v| @options[:milestone] = v }
    opts.on("--assignee=VALUE", "Query of listing issue, (String User login)"){|v| @options[:assignee] = v }
    opts.on("--mentioned=VALUE", "Query of listing issue, (String User login)"){|v| @options[:mentioned] = v }
    opts.on("--lables=VALUE", "Query of listing issue, (String list of comma separated Label names)"){|v| @options[:labels] = v }
    opts.on("--sort=VALUE", "Query of listing issue, (created,  updated,  comments,  default: created)"){|v| @options[:sort] = v }
    opts.on("--direction=VALUE", "Query of listing issue, (asc or desc,  default: desc.)"){|v| @options[:direction] = v }
    opts.on("--since=VALUE", "Query of listing issue, (Optional string of a timestamp in ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ)"){|v| @options[:since] = v }


    opts
  end

end
end
