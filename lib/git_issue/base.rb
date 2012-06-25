# -*- coding: utf-8 -*-

class GitIssue::Base
  include GitIssue::Helper
  include Term::ANSIColor

  attr_reader :apikey, :command, :tickets, :options
  attr_accessor :sysout, :syserr

  def initialize(args, options = {})

    @opt_parse_obj = opt_parser
    args = parse_options(args)

    @sysout = options[:sysout] || $stdout
    @syserr = options[:syserr] || $stderr

    split_ticket = lambda{|s| s.nil? || s.empty? ? nil : s.split(/,/).map{|v| v.strip.to_i} }

    @tickets = []
    cmd = args.shift

    if cmd =~ /(\d+,?\s?)+/
      @tickets = split_ticket.call(cmd)
      cmd = nil
    end

    @tickets += args.map{|s| split_ticket.call(s)}.flatten.uniq
    @tickets = [guess_ticket].compact if @tickets.empty?

    cmd ||= (@tickets.nil? || @tickets.empty?) ? default_cmd : :show
    cmd = cmd.to_sym

    @command = find_command(cmd)

    exit_with_message("invalid command <#{cmd}>") unless @command
  end

  def default_cmd
    :list
  end

  def execute
    if @tickets.nil? ||  @tickets.empty?
      self.send(@command.name, @options)
    else
      @tickets.each do |ticket|
        self.send(@command.name, @options.merge(:ticket_id => ticket))
      end
    end
    true
  end

  def help(options = {})
    puts @opt_parse_obj.banner
    puts "  Commnads:"
    puts usage
    puts ""
    puts "  Options:"
    puts @opt_parse_obj.summarize
  end

  def publish(options = {})
    ticket, branch_name = ticket_and_branch(options)
    remote = options[:remote] || "origin"
    system "git push -u #{remote} #{branch_name}"
  end

  def rebase(options = {})
    raise '--onto is required.' unless options[:onto]
    ticket, branch_name = ticket_and_branch(options)
    onto = options[:onto]

    cb = current_branch

    system "git rebase --onto #{onto} #{onto} #{branch_name}"
    system "git checkout #{cb}"
  end

  def commands
    [
    GitIssue::Command.new(:show,   :s, 'show given issue summary. if given no id,  geuss id from current branch name.'),
    GitIssue::Command.new(:list,   :l, 'listing issues.'),
    GitIssue::Command.new(:mine,   :m, 'display issues that assigned to you.'),
    GitIssue::Command.new(:commit, :c, 'commit with filling issue subject to messsage.if given no id, geuss id from current branch name.'),
    GitIssue::Command.new(:add,    :a, 'create issue.'),
    GitIssue::Command.new(:update, :u, 'update issue properties. if given no id, geuss id from current branch name.'),
    GitIssue::Command.new(:branch, :b, "checout to branch using specified issue id. if branch dose'nt exisits, create it. (ex ticket/id/<issue_id>)"),

    GitIssue::Command.new(:publish,:pub, "push branch to remote repository and set upstream "),
    GitIssue::Command.new(:rebase, :rb,  "rebase branch onto specific newbase"),

    GitIssue::Command.new(:help,   :h, "show usage.")
    ]
  end

  def find_command(cmd)
    cmd = cmd.to_sym
    commands.find{|c| c.name == cmd || c.short_name == cmd }
  end

  def usage
    commands.map{|c| "%-8s %s %s" % [c.name, c.short_name, c.description ] }.join("\n")
  end

  def time_ago_in_words(time)
    t = Time.parse(time)
    a = (Time.now - t).to_i

    case a
      when 0              then return 'just now'
      when 1..59          then return a.to_s + '秒前'
      when 60..119        then return '1分前'
      when 120..3540      then return (a/60).to_i.to_s + '分前'
      when 3541..7100     then return '1時間前'
      when 7101..82800    then return ((a+99)/3600).to_i.to_s + '時間前'
      when 82801..172000  then return '1日前'
      when 172001..432000 then return ((a+800)/(60*60*24)).to_i.to_s + '日前'
      else return ((a+800)/(60*60*24)).to_i.to_s + '日前'
    end
  end

  def exit_with_message(msg, status=1)
    err msg
    exit(status)
  end

  BRANCH_NAME_FORMAT = "ticket/id/%s"

  def ticket_branch(ticket_id)
    BRANCH_NAME_FORMAT % ticket_id
  end

  def current_branch
    %x(git branch -l | grep "*" | cut -d " " -f 2).strip
  end

  def guess_ticket
    branch = current_branch
    if branch =~ %r!id/(\d+)! || branch =~ /^(\d+)_/ || branch =~ /_(\d+)$/
      ticket = $1
    end
  end

  def ticket_and_branch(options)
    if options[:ticket_id]
      ticket = options[:ticket_id]
      branch_name = ticket_branch(ticket)
    else
      branch_name = current_branch
      ticket = guess_ticket
    end
    [ticket, branch_name]
  end

  def response_success?(response)
    code = response.code.to_i
    code >= 200 && code < 300
  end

  def prompt(name)
   print "#{name}: "
   $stdin.gets.chop
  end

  # this is unnecessary hacks for multibytes charactors handling...
  def mlength(s)
    width = 0
    cnt = 0
    s.split(//u).each{|c| cnt += 1 ;width += 1 if c.length > 1 }
    cnt + width
  end

  # this is unnecessary hacks for multibytes charactors handling...
  def mljust(s, n)
    return "" unless s
    cnt = 0
    chars = []

    s.split(//u).each do |c|
      next if cnt > n
      chars << c
      cnt += c =~ /^[^ -~｡-ﾟ]*$/ ? 2 : 1
    end
    if cnt > n
      chars.pop
      cnt -= chars.last =~ /^[^ -~｡-ﾟ]*$/ ? 2 : 1
    end
    chars << " " * (n - cnt) if n > cnt
    chars.join
  end

  # for 1.8.6...
  def mktmpdir(prefix_suffix=nil, tmpdir=nil)
    case prefix_suffix
    when nil
      prefix = "d"
      suffix = ""
    when String
      prefix = prefix_suffix
      suffix = ""
    when Array
      prefix = prefix_suffix[0]
      suffix = prefix_suffix[1]
    else
      raise ArgumentError, "unexpected prefix_suffix: #{prefix_suffix.inspect}"
    end
    tmpdir ||= Dir.tmpdir
    t = Time.now.strftime("%Y%m%d")
    n = nil
    begin
      path = "#{tmpdir}/#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}"
      path << "-#{n}" if n
      path << suffix
      Dir.mkdir(path, 0700)
    rescue Errno::EEXIST
      n ||= 0
      n += 1
      retry
    end

    if block_given?
      begin
        yield path
      ensure
        FileUtils.remove_entry_secure path
      end
    else
      path
    end
  end

  def to_date(d)
    Date.parse(d).strftime('%Y/%m/%d') rescue d
  end

  def parse_options(args)
    @options = {}
    @opt_parse_obj.parse!(args)
    args
  end

  def opt_parser
    OptionParser.new{|opts|
      opts.banner = 'git issue <command> [ticket_id] [<args>]'
      opts.on("--all",        "-a", "update all paths in the index file "){ @options[:all] = true }
      opts.on("--force",      "-f", "force create branch"){ @options[:force] = true }
      opts.on("--verbose",    "-v", "show issue details"){|v| @options[:verbose] = true}
      opts.on("--max-count=VALUE", "-n=VALUE", "maximum number of issues "){|v| @options[:max_count] = v.to_i}
      opts.on("--oneline",          "display short info"){|v| @options[:oneline] = true}
      opts.on("--raw-id",           "output ticket number only"){|v| @options[:raw_id] = true}
      opts.on("--remote=VALUE",     'on publish, remote repository to push branch ') {|v| @options[:remote] = v}
      opts.on("--onto=VALUE",       'on rebase, start new branch with HEAD equal to "newbase" ') {|v| @options[:onto] = v}

      opts.on("--no-color", "turn off colored output"){@no_color = true }
      opts.on("--debug", "debug print"){@debug= true }
    }

  end

  def puts(msg)
    @sysout.puts msg
  end

  def err(msg)
    @syserr.puts msg
  end

  def apply_colors(str, *colors)
    @no_color.present? ? str : (colors.map(&method(:send)) + [str, reset]).join
  end
end

