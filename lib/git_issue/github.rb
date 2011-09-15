module GitIssue
class GitIssue::Github < GitIssue::Base
  def initialize(args, options = {})
    super(args, options)

    @apikey = options[:apikey] || configured_value('apikey')
    configure_error('apikey', "git config issue.apikey some_api_key") if @apikey.blank?

    @repo = options[:repo] || configured_value('repo')
    configure_error('repo', "git config issue.repo git-issue")  if @repo.blank?

    @user = options[:user] || configured_value('user')
    configure_error('user', "git config issue.user yuroyoro")  if @user.blank?

  end

  def show(options = {})
    ticket = options[:ticket_id]
    raise 'ticket_id is required.' unless ticket
    issue = fetch_issue(ticket, options)

    if options[:oneline]
      puts oneline_issue(issue, options)
    else
      comments = fetch_comments(ticket) if options[:comments]
      puts ""
      puts format_issue(issue, comments, options)
    end
  end

  def list(options = {})
    status = options[:status] || "open"
    url = to_url("issues", "list", @user, @repo, status)

    json = fetch_json(url)
    issues = json['issues']

    t_max = issues.map{|i| mlength(i['title'])}.max
    l_max = issues.map{|i| mlength(i['labels'].join(","))}.max
    u_max = issues.map{|i| mlength(i['user'])}.max

    issues.each do |i|
      puts sprintf("#%-4d  %s  %s  %s  %s comments:%s votes:%s position:%s %s",
                   i['number'].to_i,
                   i['state'],
                   mljust(i['title'], t_max),
                   mljust(i['user'], u_max),
                   mljust(i['labels'].join(','), l_max),
                   i['comments'],
                   i['votes'],
                   i['position'],
                   to_date(i['created_at']))
    end

  end

  def branch(options = {})
    ticket = options[:ticket_id]
    raise 'ticket_id is required.' unless ticket

    branch_name = "ticket/id/#{ticket}"


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

  ROOT = 'https://github.com/api/v2/json'
  def to_url(*path_list)
    URI.join(ROOT, path_list.join("/"))
  end

  def fetch_json(url)
    json = open(url, {:http_basic_authentication => ["#{@user}/token", @apikey]}) {|io|
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
    url = to_url("issues", "show", @user, @repo, ticket_id)
    url += "?" + params.map{|k,v| "#{k}=#{v}"}.join("&") unless params.empty?
    json = fetch_json(url)

    issue = json['issue'] || json
    raise "no such issue #{ticket} : #{base}" unless issue

    issue
  end

  def fetch_comments(ticket_id)
    url = to_url("issues", "comments", @user, @repo, ticket_id)
    json = fetch_json(url)
    json['comments'] || []
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
    author     = issue['user']
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

    cmts << "##{n + 1} - #{c['user']}が#{time_ago_in_words(c['created_at'])}に更新"
    cmts << "-" * 78
    cmts +=  c['body'].split("\n").to_a if c['body']
    cmts << ""
  end

  def opt_parser
    opts = super
    opts.on("--comments", "-c", "show issue journals"){|v| @options[:comments] = true}
    opts.on("--status=VALUE",   "Where 'state' is either 'open' or 'closed'"){|v| @options[:status] = v}

    opts
  end

end
end
