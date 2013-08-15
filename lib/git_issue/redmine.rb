# -*- coding: utf-8 -*-

module GitIssue
class Redmine < GitIssue::Base

  def initialize(args, options = {})
    super(args, options)

    @apikey = options[:apikey] || configured_value('issue.apikey')
    configure_error('apikey', "git config issue.apikey some_api_key") if @apikey.blank?

    @url = options[:url] || configured_value('issue.url')
    configure_error('url', "git config issue.url http://example.com/redmine")  if @url.blank?
  end

  def default_cmd
    Helper.configured_value('issue.project').blank? ? :list : :project
  end

  def commands
    cl = super
    cl << GitIssue::Command.new(:local, :loc, 'listing local branches tickets')
    cl << GitIssue::Command.new(:project, :pj, 'listing ticket belongs to sspecified project ')
  end

  def show(options = {})
    ticket = options[:ticket_id]
    raise 'ticket_id is required.' unless ticket

    issue = fetch_issue(ticket, options)

    if options[:oneline]
      puts oneline_issue(issue, options)
    else
      puts ""
      puts format_issue(issue, options)
    end
  end

  def list(options = {})
    url = to_url('issues')
    max_count = options[:max_count].to_s if options[:max_count]
    params = {"limit" => max_count || "100" }
    params.merge!("assigned_to_id" => "me") if options[:mine]
    params.merge!(Hash[*(options[:query].split("&").map{|s| s.split("=") }.flatten)]) if options[:query]

    param_list = Hash[*params.map{|k,v| [k,v.split(/,/)] }.flatten(1)]
    keys = param_list.keys
    pl,*pls = param_list.values

    jsons = pl.product(*pls).map{|vs| Hash[*keys.zip(vs).flatten]}.map{|p|
      fetch_json(url, p)['issues']
    }.flatten

    known_ids = []
    issues = jsons.reject{|i|
      known = known_ids.include?(i["id"])
      known_ids << i['id'] unless known
      known
    }

    # json = fetch_json(url, params)

    # output_issues(json['issues'])
    output_issues(issues)
  end

  def mine(options = {})
    list(options.merge(:mine => true))
  end

  def commit(options = {})
    ticket = options[:ticket_id]
    raise 'ticket_id is required.' unless ticket

    issue = fetch_issue(ticket)

    f = File.open("./commit_msg_#{ticket}", 'w')
    f.write("refs ##{ticket} #{issue['subject']}")
    f.close

    cmd = "git commit --edit #{options[:all] ? '-a' : ''} --file #{f.path}"
    system(cmd)

    File.unlink f.path if f.path
  end

  def add(options = {})
    property_names = [:project_id, :subject, :description, :done_ratio, :status_id, :priority_id, :tracker_id, :assigned_to_id, :category_id, :fixed_version_id, :notes]

    project_id = options[:project_id] || Helper.configured_value('issue.project')
    if options.slice(*property_names).empty?
      issue = read_issue_from_editor({"project" => {"id" => project_id}}, options)
      description = issue.delete(:notes)
      issue[:description] = description
      options.merge!(issue)
    end

    required_properties = [:subject, :description]
    required_properties.each do |name|
      options[name] = prompt(name) unless options[name]
    end

    json = build_issue_json(options, property_names)
    json["issue"][:project_id] ||= Helper.configured_value('issue.project')

    url = to_url('issues')

    json = post_json(url, json, options)
    puts "created issue #{oneline_issue(json["issue"])}"
  end

  def update(options = {})
    ticket = options[:ticket_id]
    raise 'ticket_id is required.' unless ticket

    property_names = [:subject, :done_ratio, :status_id, :priority_id, :tracker_id, :assigned_to_id, :category_id, :fixed_version_id, :notes]

    if options.slice(*property_names).empty?
      org_issue = fetch_issue(ticket, options)
      update_attrs = read_issue_from_editor(org_issue, options)
      update_attrs = update_attrs.reject{|k,v| v.present? && org_issue[k] == v}
      options.merge!(update_attrs)
    end

    json = build_issue_json(options, property_names)

    url = to_url('issues', ticket)
    put_json(url, json, options)
    issue = fetch_issue(ticket)
    puts "updated issue #{oneline_issue(issue)}"
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

  def local(option = {})
    branches = %x(git branch).split(/\n/).select{|b| b.scan(/(\d+)_/).present?}.map{|b| b.gsub(/^(\s+|\*\s+)/, "")}
    branches.each do |b|
      puts b
      issues = b.scan(/(\d+)_/).map{|ticket_id| fetch_issue(ticket_id) rescue nil}.compact
      issues.each do |i|
        puts "  #{oneline_issue(i, options)}"
      end
      puts ""
    end
  end

  def project(options = {})
    project_id = Helper.configured_value('issue.project')
    project_id = options[:ticket_id] if project_id.blank?
    raise 'project_id is required.' unless project_id
    list(options.merge(:query => "project_id=#{project_id}"))
  end

  private

  def to_url(*path_list)
    URI.join(@url, path_list.join("/"))
  end

  def fetch_json(url, params = {})
    url_cert = parse_url(url)
    cert = url_cert[:cert]

    url = "#{url_cert[:url]}.json?key=#{@apikey}"
    url += "&" + params.map{|k,v| "#{k}=#{v}"}.join("&") unless params.empty?

    option = Hash.new
    option[:ssl_verify_mode] = OpenSSL::SSL::VERIFY_NONE if url.start_with? 'https'
    option[:http_basic_authentication] = cert unless cert == nil

    json = open(url, option) {|io| JSON.parse(io.read) }

    if @debug
      puts '-' * 80
      puts url
      pp json
      puts '-' * 80
    end

    json
  end

  def fetch_issue(ticket_id, options = {})
    url = to_url("issues", ticket_id)
    includes = issue_includes(options)
    params = includes.empty? ? {} : {"include" => includes }
    json = fetch_json(url, params)

    issue = json['issue'] || json
    raise "no such issue #{ticket} : #{base}" unless issue

    issue
  end

  def post_json(url, json, options, params = {})
    response = send_json(url, json, options, params, :post)
    JSON.parse(response.body) if response_success?(response)
  end

  def put_json(url, json, options, params = {})
    send_json(url, json, options, params, :put)
  end

  def send_json(url, json, options, params = {}, method = :post)
    url_cert = parse_url(url)
    cert = url_cert[:cert]

    url = "#{url_cert[:url]}.json"
    uri = URI.parse(url)

    if @debug
      puts '-' * 80
      puts url
      pp json
      puts '-' * 80
    end

    http = connection(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    http.set_debug_output $stderr if @debug && http.respond_to?(:set_debug_output)
    http.start{|http|

      path = "#{uri.path}?key=#{@apikey}"
      path += "&" + params.map{|k,v| "#{k}=#{v}"}.join("&") unless params.empty?

      request = case method
        when :post then Net::HTTP::Post.new(path)
        when :put  then Net::HTTP::Put.new(path)
        else raise "unknown method #{method}"
      end

      request.basic_auth cert[0], cert[1] unless cert == nil

      request.set_content_type("application/json")
      request.body = json.to_json

      response = http.request(request)
      if @debug
        puts "#{response.code}: #{response.msg}"
        puts response.body
      end
      response
    }
  end

  def issue_includes(options)
    includes = []
    includes << "journals"   if ! options[:supperss_journals]   || options[:verbose]
    includes << "changesets" if ! options[:supperss_changesets] || options[:verbose]
    includes << "relations"  if ! options[:supperss_relations]  || options[:verbose]
    includes.join(",")
  end


  def issue_title(issue)
    "[#{apply_colors(issue['project']['name'], :green)}] #{apply_colors(issue['tracker']['name'], :yellow)} #{apply_fmt_colors(:id, "##{issue['id']}")} #{issue['subject']}"
  end

  def issue_author(issue)
    author     = issue['author']['name']
    created_on = issue['created_on']
    updated_on = issue['updated_on']

    msg = "#{apply_fmt_colors(:assigned_to, author)}が#{time_ago_in_words(created_on)}に追加"
    msg += ", #{time_ago_in_words(updated_on)}に更新" unless created_on == updated_on
    msg
  end

  PROPERTY_TITLES= {"status"=>"ステータス",  "start_date"=>"開始日",  "category"=>"カテゴリ",  "assigned_to"=>"担当者",  "estimated_hours"=>"予定工数",  "priority"=>"優先度",  "fixed_version"=>"対象バージョン",  "due_date"=>"期日",  "done_ratio"=>"進捗"}

  def property_title(name)
    PROPERTY_TITLES[name] || name
  end

  def oneline_issue(issue, options = {})
    "#{apply_fmt_colors(:id, "##{issue['id']}")} #{issue['subject']}"
  end

  def format_issue(issue, options)
    msg = [""]

    msg << issue_title(issue)
    msg << "-" * 80
    msg << issue_author(issue)
    msg << ""

    props = []
    prop_name = Proc.new{|name|
      "#{issue[name]['name']}(#{issue[name]['id']})" if issue[name] && issue[name]['name']
    }
    add_prop = Proc.new{|name|
      title = property_title(name)
      value = issue[name] || ""
      props << [title, value, name]
    }
    add_prop_name = Proc.new{|name|
      title = property_title(name)
      value = ''
      value = prop_name.call(name)
      props << [title, value, name]
    }

    add_prop_name.call('status')
    add_prop.call("start_date")
    add_prop_name.call('priority')
    add_prop.call('due_date')
    add_prop_name.call('assigned_to')
    add_prop.call('done_ratio')
    add_prop_name.call('category')
    add_prop.call('estimated_hours')

    # acd custom_fields if it have value.
    if custom_fields = issue[:custom_fields] && custom_fields.reject{|cf| cf['value'].nil? || cf['value'].empty? }
      custom_fields.each do |cf|
        props << [cf['name'], cf['value'], cf['name']]
      end
    end

    props.each_with_index do |p,n|
      title, value, name = p
      row = sprintf("%s : %s", mljust(title, 18), apply_fmt_colors(name, mljust(value.to_s, 24)))
      if n % 2 == 0
        msg << row
      else
        msg[-1] = "#{msg.last} #{row}"
      end
    end

    msg <<  sprintf("%s : %s", mljust(property_title('fixed_version'),18), mljust(prop_name.call('fixed_version'), 66))

    # display relations tickets
    if ! options[:supperss_relations] || options[:verbose]
      relations = issue['relations']
      if relations && !relations.empty?
        msg << "関連するチケット"
        msg << "-" * 80
        rels = format_relations(relations)
        msg += rels
      end
    end

    # display description
    msg << "-" * 80
    msg << "#{issue['description']}"
    msg << ""

    # display journals
    if ! options[:supperss_journals] || options[:verbose]
      journals = issue['journals']
      if journals && !journals.empty?
        msg << "履歴"
        msg << "-" * 80
        msg << ""
        jnl = format_jounals(journals)
        msg += jnl.map{|s| "  #{s}"}
      end
    end

    # display changesets
    if ! options[:supperss_changesets] || options[:verbose]
      changesets = issue['changesets']
      if changesets && !changesets.empty?
        msg << "関係しているリビジョン"
        msg << "-" * 80
        msg << ""
        cs = format_changesets(changesets)
        msg += cs.map{|s| "  #{s}"}
      end
    end

    msg.join("\n")

  end

  def format_jounals(journals)
    jnl = []
    journals.sort_by{|j| j['created_on']}.each_with_index do |j,n|
      jnl += format_jounal(j,n)
    end
    jnl
  end

  def format_jounal(j, n)
    jnl = []

    jnl << "##{n + 1} - #{apply_fmt_colors(:assigned_to, j['user']['name'])}が#{time_ago_in_words(j['created_on'])}に更新"
    jnl << "-" * 78
    j['details'].each do |d|
      log = "#{property_title(d['name'])}を"
      if d['old_value']
        log += "\"#{d['old_value']}\"から\"#{d['new_value']}\"へ変更"
      else
        log += "\"#{d['new_value']}\"にセット"
      end
      jnl << log
    end
    jnl +=  j['notes'].split("\n").to_a if j['notes']
    jnl << ""
  end

  def format_changesets(changesets)
    cs = []
    changesets.sort_by{|c| c['committed_on'] }.each do |c|
      cs << "リビジョン: #{apply_colors((c['revision'] || "")[0..10], :cyan)} #{apply_fmt_colors(:assigned_to, (c['user'] || {})['name'])}が#{time_ago_in_words(c['committed_on'])}に追加"
      cs +=  c['comments'].split("\n").to_a
      cs << ""
    end
    cs
  end

  def format_relations(relations)
    relations.map{|r|
      issue = fetch_issue(r['issue_id'])
      "#{relations_label(r['relation_type'])} #{issue_title(issue)} #{apply_fmt_colors(:status, issue['status']['name'])} #{issue['start_date']} "
    }
  end

  DEFAULT_FORMAT = "%I  %S | %A | %s %T %P | %V %C |"

  def format_issue_tables(issues_json)
    name_of = lambda{|issue, name| issue[name]['name'] rescue ""}

    issues = issues_json.map{ |issue|{
      :id => sprintf("#%-4d", issue['id']), :subject => issue['subject'],
      :project     => name_of.call(issue, 'project'),
      :tracker     => name_of.call(issue, 'tracker'),
      :status      => name_of.call(issue, 'status'),
      :assigned_to => name_of.call(issue, 'assigned_to'),
      :version     => name_of.call(issue, 'fixed_version'),
      :priority    => name_of.call(issue, 'priority'),
      :category    => name_of.call(issue, 'category'),
      :updated_on  => issue['updated_on'].to_date
    }}

    max_of = lambda{|name, limit|
      max = issues.map{|i| mlength(i[name])}.max
      [max, limit].compact.min
    }
    max_length = {
      :project     => max_of.call(:project, 20),
      :tracker     => max_of.call(:tracker, 20),
      :status      => max_of.call(:status, 20),
      :assigned_to => max_of.call(:assigned_to, 20),
      :version     => max_of.call(:version, 20),
      :priority    => max_of.call(:priority, 20),
      :category    => max_of.call(:category, 20),
      :subject => 80
    }

    fmt = configured_value('issue.defaultformat', false)
    fmt = DEFAULT_FORMAT unless fmt.present?

    fmt_chars =  { :I => :id, :S => :subject,
      :A => :assigned_to, :s => :status,  :T => :tracker,
      :P => :priority,    :p => :project, :V => :version,
      :C => :category,    :U => :updated_on }

    format_to = lambda{|i|
      res = fmt.dup
      fmt_chars.each do |k, v|
        res.gsub!(/\%(\d*)#{k}/) do |s|
          max = $1.blank? ? max_length[v] : $1.to_i
          str = max ? mljust(i[v], max) : i[v]
          colored =  fmt_colors[v] ? apply_fmt_colors(v, str) : str
          colored
        end
      end
      res
    }

    issues.map{|i| format_to.call(i) }
  end

  def apply_fmt_colors(key, str)
    fmt_colors[key.to_sym] ? apply_colors(str, *Array(fmt_colors[key.to_sym])) : str
  end

  def fmt_colors
    @fmt_colors ||= { :id => [:bold, :cyan], :status => :blue,
      :priority => :green, :assigned_to => :magenta,
      :tracker => :yellow}
  end

  def output_issues(issues)

    if options[:oneline]
      issues.each do |i|
        puts oneline_issue(i, options)
      end
    elsif options[:raw_id]
      issues.each do |i|
        puts i['id']
      end
    else
      format_issue_tables(issues).each do |i|
        puts i
      end
    end
  end

  RELATIONS_LABEL = { "relates"    => "関係している", "duplicates" => "重複している",
    "duplicated" => "重複されている", "blocks" => "ブロックしている",
    "blocked" => "ブロックされている", "precedes" => "先行する", "follows" => "後続する",
  }

  def relations_label(rel)
    RELATIONS_LABEL[rel] || rel
  end

  def build_issue_json(options, property_names)
    json = {"issue" => property_names.inject({}){|h,k| h[k] = options[k] if options[k].present?; h} }

    if custom_fields = options[:custom_fields]
      json['custom_fields'] = custom_fields.split(",").map{|s| k,*v = s.split(":");{'id' => k.to_i, 'value' => v.join }}
    end
    json
  end

  def read_issue_from_editor(issue, options = {})
    id_of = lambda{|name| issue[name] ? sprintf('%2s : %s', issue[name]["id"] , issue[name]['name'] ): ""}

    memofile = configured_value('issue.memofile')
    memo = File.open(memofile).read.lines.map{|l| "# #{l}"}.join("") unless memofile.blank?

    message = <<-MSG
#{issue["subject"].present? ? issue["subject"].chomp : "### subject here ###"}

Project  : #{id_of.call("project")}
Tracker  : #{id_of.call("tracker")}
Status   : #{id_of.call("status")}
Priority : #{id_of.call("priority")}
Category : #{id_of.call("category")}
Assigned : #{id_of.call("assigned_to")}
Version  : #{id_of.call("fixed_version")}

# Please enter the notes for your changes. Lines starting
# with '#' will be ignored, and an empty message aborts.
#{memo}
MSG
    body =  get_body_from_editor(message)

    subject, dummy, project_id, tracker_id, status_id, priority_id, category_id, assigned_to_id, fixed_version_id, dummy, *notes = body.lines.to_a

    notes = if notes.present?
      notes.reject{|l| l =~ /^#/}.join("")
    else
      nil
    end

    if @debug
      puts "------"
      puts "sub: #{subject}"
      puts "pid: #{project_id}"
      puts "tid: #{tracker_id}"
      puts "sid: #{status_id}"
      puts "prd: #{priority_id}"
      puts "cat: #{category_id}"
      puts "ass: #{assigned_to_id}"
      puts "vss: #{fixed_version_id}"
      puts "nos: #{notes}"
      puts "------"
    end

    take_id = lambda{|s|
      x, i, name = s.chomp.split(":")
      i.present? ? i.strip.to_i : nil
    }

    { :subject => subject.chomp, :project_id => take_id.call(project_id),
      :tracker_id => take_id.call(tracker_id),
      :status_id => take_id.call(status_id),
      :priority_id => take_id.call(priority_id),
      :category_id => take_id.call(category_id),
      :assigned_to_id => take_id.call(assigned_to_id),
      :fixed_version_id => take_id.call(fixed_version_id),
      :notes => notes
    }
  end

  def opt_parser
    opts = super
    opts.on("--supperss_journals",   "-j", "do not show issue journals"){|v| @options[:supperss_journals] = true}
    opts.on("--supperss_relations",  "-r", "do not show issue relations tickets"){|v| @options[:supperss_relations] = true}
    opts.on("--supperss_changesets", "-c", "do not show issue changesets"){|v| @options[:supperss_changesets] = true}
    opts.on("--query=VALUE",'-q=VALUE', "filter query of listing tickets") {|v| @options[:query] = v}

    opts.on("--mine", "lists issues assigned_to me"){|v| @options[:mine] = true}
    opts.on("--project_id=VALUE", "use the given value to create subject"){|v| @options[:project_id] = v}
    opts.on("--description=VALUE", "use the given value to create subject"){|v| @options[:description] = v}
    opts.on("--subject=VALUE", "use the given value to create/update subject"){|v| @options[:subject] = v}
    opts.on("--ratio=VALUE", "use the given value to create/update done-ratio(%)"){|v| @options[:done_ratio] = v.to_i}
    opts.on("--status=VALUE", "use the given value to create/update issue statues id"){|v| @options[:status_id] = v }
    opts.on("--priority=VALUE", "use the given value to create/update issue priority id"){|v| @options[:priority_id] = v }
    opts.on("--tracker=VALUE", "use the given value to create/update tracker id"){|v| @options[:tracker_id] = v }
    opts.on("--assigned_to_id=VALUE", "use the given value to create/update assigned_to id"){|v| @options[:assigned_to_id] = v }
    opts.on("--category=VALUE", "use the given value to create/update category id"){|v| @options[:category_id] = v }
    opts.on("--fixed_version=VALUE", "use the given value to create/update fixed_version id"){|v| @options[:fixed_version_id] = v }
    opts.on("--custom_fields=VALUE", "value should be specifies '<custom_fields_id1>:<value2>,<custom_fields_id2>:<value2>, ...' "){|v| @options[:custom_fields] = v }

    opts.on("--notes=VALUE", "add notes to issue"){|v| @options[:notes] = v}

    opts
  end

  def parse_url(url)
    matches = url.to_s.match(%r{(http|https)://((.*):(.*)@|)(.*)})
    url = "#{matches[1]}://#{matches[5]}"
    cert = matches[3] == nil ? nil : matches[3, 2].map{|elem| URI.decode(elem)}
    {:url => url, :cert => cert}
  end
end
end
