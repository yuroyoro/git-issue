class GitIssue::Base
  include GitIssue::Helper

  attr_reader :apikey, :command, :command, :tickets, :options
  attr_accessor :sysout, :syserr

  def initialize(args, options = {})

    @opt_parse_obj = opt_parser
    args = parse_options(args)

    @sysout = options[:sysout] || $stdout
    @syserr = options[:syserr] || $stderr

    split_ticket = lambda{|s| s.nil? || s.empty? ? nil : s.split(/,/).map{|v| v.strip.to_i} }

    @tickets = []
    @command = args.shift || :show
    if @command =~ /(\d+,?\s?)+/
      @tickets = split_ticket.call(@command)
      @command = :show
    end
    @command = @command.to_sym

    @command = COMMAND_ALIAS[@command.to_sym] if  COMMAND_ALIAS[@command.to_sym]

    exit_with_message("invalid command <#{@command}>") unless COMMAND.include?(@command.to_sym)

    @tickets += args.map{|s| split_ticket.call(s)}.flatten.uniq
    @tickets = [guess_ticket] if @tickets.empty?
  end

  def execute
    if @tickets.nil? ||  @tickets.empty?
      self.send(@command, @options)
    else
      @tickets.each do |ticket|
        self.send(@command, @options.merge(:ticket_id => ticket))
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

  def commands
    [
    Command.new(:show,   :s, 'show given issue summary. if given no id,  geuss id from current branch name.'),
    Command.new(:list,   :l, 'listing issues.'),
    Command.new(:mine,   :m, 'display issues that assigned to you.'),
    Command.new(:commit, :c, 'commit with filling issue subject to messsage.if given no id, geuss id from current branch name.'),
    Command.new(:update, :u, 'update issue properties. if given no id, geuss id from current branch name.'),
    Command.new(:branch, :b, "checout to branch using specified issue id. if branch dose'nt exisits, create it. (ex ticket/id/<issue_id>)"),
    Command.new(:help,   :h, "show usage.")
    ]
  end

  def find_command(cmd)
    cmd = cmd.to_sym
    command.find{|c| c.name == cmd || c.short_name == c }
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

  def guess_ticket
    branch = %x(git branch -l | grep "*" | cut -d " " -f 2).strip
    if branch =~ %r!id/(\d+)!
      ticket = $1
    end
  end

  def mlength(s)
    width = 0
    cnt = 0
    s.split(//u).each{|c| cnt += 1 ;width += 1 if c.length > 1 }
    cnt + width
  end

  def mljust(s, n)
    cnt = 0
    chars = []

    s.split(//u).each do |c|
      next if cnt > n
      chars << c
      cnt += 1
      cnt += 1 if c.length > 1
    end
    if cnt > n
      chars.pop
      cnt -= 1
      cnt -= 1 if chars.last.length > 1
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

      opts.on("--debug", "debug print"){@debug= true }
    }

  end

  def puts(msg)
    @sysout.puts msg
  end

  def err(msg)
    @syserr.puts msg
  end

end

