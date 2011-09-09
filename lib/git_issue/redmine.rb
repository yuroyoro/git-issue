module GitIssue
class Redmine < GitIssue::Base

  def initialize(args, options = {})
    super(args, options)

    @apikey = options[:apikey] || configured_value('apikey')
    configure_error('apikey', "git config issue.apikey some_api_key") if @apikey.blank?

    @url = options[:url] || configured_value('url')
    configure_error('url', "git config issue.url http://example.com/redmine")  if @url.blank?
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
    params = {"limit" => options[:max_count] || 20 }
    params.merge!("assigned_to_id" => "me") if options[:mine]
    params.merge!(Hash[*(options[:query].split("&").map{|s| s.split("=") }.flatten)]) if options[:query]

    json = fetch_json(url, params)

    issues = json['issues'].map{ |issue|
      project     = issue['project']['name']     rescue ""
      tracker     = issue['tracker']['name']     rescue ""
      status      = issue['status']['name']      rescue ""
      assigned_to = issue['assigned_to']['name'] rescue ""
      [issue['id'], project, tracker, status, issue['subject'], assigned_to, issue['updated_on']]
    }

    p_max = issues.map{|i| mlength(i[1])}.max
    t_max = issues.map{|i| mlength(i[2])}.max
    s_max = issues.map{|i| mlength(i[3])}.max
    a_max = issues.map{|i| mlength(i[5])}.max

    issues.each do |i|
      puts sprintf("#%-4d  %s  %s  %s  %s %s  %s",  i[0].to_i, mljust(i[1], p_max), mljust(i[2], t_max), mljust(i[3], s_max),  mljust(i[4], 80), mljust(i[5], a_max), to_date(i[6]))
    end
  end

  def mine(options = {})
    list( options.merge(:mine => true))
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

  def update(options = {})
    ticket = options[:ticket_id]
    raise 'ticket_id is required.' unless ticket

    updatable_properties = [:done_ratio, :status_id, :priority_id, :tracker_id, :assigned_to_id, :category_id, :fixed_version_id, :notes]
    json = {"issue" => updatable_properties.inject({}){|h,k| h[k] = options[k] if options[k]; h} }

    if custom_fields = options[:custom_fields]
      json['custom_fields'] = custom_fields.split(",").map{|s| k,*v = s.split(":");{'id' => k.to_i, 'value' => v.join }}
    end

    url = to_url('issues', ticket)
    post_json(url, json)

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

  def to_url(*path_list)
    URI.join(@url, path_list.join("/"))
  end

  def fetch_json(url, params = {})
    url = "#{url}.json?key=#{@apikey}"
    url += "&" + params.map{|k,v| "#{k}=#{v}"}.join("&") unless params.empty?
    json = open(url) {|io| JSON.parse(io.read) }

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

  def post_json(url, json, params = {})
    url = "#{url}.json"
    uri = URI.parse(url)

    if @debug
      puts '-' * 80
      puts url
      pp json
      puts '-' * 80
    end

    Net::HTTP.start(uri.host, uri.port){|http|

      path = "#{uri.path}?key=#{@apikey}"
      path += "&" + params.map{|k,v| "#{k}=#{v}"}.join("&") unless params.empty?

      request = Net::HTTP::Put.new(path)

      request.set_content_type("application/json")
      request.body = json.to_json

      response = http.request(request)
      if @debug
        puts "#{response.code}: #{response.msg}"
        puts response.body
      end
    }

  end

  def issue_includes(options)
    includes = []
    includes << "journals"   if options[:journals]   || options[:verbose]
    includes << "changesets" if options[:changesets] || options[:verbose]
    includes << "relations"  if options[:relations]  || options[:verbose]
    includes.join(",")
  end


  def issue_title(issue)
    "[#{issue['project']['name']}] #{issue['tracker']['name']} ##{issue['id']} #{issue['subject']}"
  end

  def issue_author(issue)
    author     = issue['author']['name']
    created_on = issue['created_on']
    updated_on = issue['updated_on']

    msg = "#{author}が#{time_ago_in_words(created_on)}に追加"
    msg += ", #{time_ago_in_words(updated_on)}に更新" unless created_on == updated_on
    msg
  end

  PROPERTY_TITLES= {"status"=>"ステータス",  "start_date"=>"開始日",  "category"=>"カテゴリ",  "assigned_to"=>"担当者",  "estimated_hours"=>"予定工数",  "priority"=>"優先度",  "fixed_version"=>"対象バージョン",  "due_date"=>"期日",  "done_ratio"=>"進捗"}

  def property_title(name)
    PROPERTY_TITLES[name] || name
  end

  def oneline_issue(issue, options)
    "##{issue['id']} #{issue['subject']}"
  end

  def format_issue(issue, options)
    msg = [""]

    msg << issue_title(issue)
    msg << "-" * 80
    msg << issue_author(issue)
    msg << ""

    props = []
    add_prop = Proc.new{|name|
      title = property_title(name)
      value = issue[name] || ""
      props << [title, value]
    }
    add_prop_name = Proc.new{|name|
      title = property_title(name)
      value = ''
      value = issue[name]['name'] if issue[name] && issue[name]['name']
      props << [title, value]
    }

    add_prop_name.call('status')
    add_prop.call("start_date")
    add_prop_name.call('priority')
    add_prop.call('due_date')
    add_prop_name.call('assigned_to')
    add_prop.call('done_ratio')
    add_prop_name.call('category')
    add_prop.call('estimated_hours')
    add_prop_name.call('fixed_version')

    # acd custom_fields if it have value.
    if custom_fields = issue['custom_fields'].reject{|cf| cf['value'].nil? || cf['value'].empty? }
      custom_fields.each do |cf|
        props << [cf['name'], cf['value']]
      end
    end

    props.each_with_index do |p,n|
      row = sprintf("%s : %s", mljust(p.first, 18), mljust(p.last.to_s, 24))
      if n % 2 == 0
        msg << row
      else
        msg[-1] = "#{msg.last} #{row}"
      end
    end

    # display relations tickets
    if options[:relations] || options[:verbose]
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
    if options[:journals] || options[:verbose]
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
    if options[:changesets] || options[:verbose]
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

    jnl << "##{n + 1} - #{j['user']['name']}が#{time_ago_in_words(j['created_on'])}に更新"
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
      cs << "リビジョン: #{c['revision'][0..10]} #{c['user']['name']}が#{time_ago_in_words(c['committed_on'])}に追加"
      cs +=  c['comments'].split("\n").to_a
      cs << ""
    end
    cs
  end

  def format_relations(relations)
    relations.map{|r|
      issue = fetch_issue(r['issue_id'])
      "#{relations_label(r['relation_type'])} #{issue_title(issue)} #{issue['status']['name']} #{issue['start_date']} "
    }
  end


  RELATIONS_LABEL = { "relates"    => "関係している", "duplicates" => "重複している",
    "duplicated" => "重複されている", "blocks" => "ブロックしている",
    "blocked" => "ブロックされている", "precedes" => "先行する", "follows" => "後続する",
  }

  def relations_label(rel)
    RELATIONS_LABEL[rel] || rel
  end


  def opt_parser
    opts = super
    opts.on("--journals",   "-j", "show issue journals"){|v| @options[:journals] = true}
    opts.on("--relations",  "-r", "show issue relations tickets"){|v| @options[:relations] = true}
    opts.on("--changesets", "-c", "show issue changesets"){|v| @options[:changesets] = true}
    opts.on("--query=VALUE",'-q', "filter query of listing tickets") {|v| @options[:query] = v}

    opts.on("--subject=VALUE", "use the given value to update subject"){|v| @options[:subject] = v.to_i}
    opts.on("--ratio=VALUE", "use the given value to update done-ratio(%)"){|v| @options[:done_ratio] = v.to_i}
    opts.on("--status=VALUE", "use the given value to update issue statues id"){|v| @options[:status_id] = v }
    opts.on("--priority=VALUE", "use the given value to update issue priority id"){|v| @options[:priority_id] = v }
    opts.on("--tracker=VALUE", "use the given value to update tracker id"){|v| @options[:tracker_id] = v }
    opts.on("--assigned_to_id=VALUE", "use the given value to update assigned_to id"){|v| @options[:assigned_to_id] = v }
    opts.on("--category=VALUE", "use the given value to update category id"){|v| @options[:category_id] = v }
    opts.on("--fixed_version=VALUE", "use the given value to update fixed_version id"){|v| @options[:fixed_version_id] = v }
    opts.on("--custom_fields=VALUE", "value should be specifies '<custom_fields_id1>:<value2>,<custom_fields_id2>:<value2>, ...' "){|v| @options[:custom_fields] = v }

    opts.on("--notes=VALUE", "add notes to issue"){|v| @options[:notes] = v}

    opts
  end


end
end
