module GitIssue
class Base
  attr_reader :apikey, :command, :command, :tickets, :options
  attr_accessor :sysout, :syserr


  def initialize(apikey, args, sysout = $stdout, syserr = $stderr)
    @apikey = apikey
    @sysout, @syserr = sysout, syserr
    @opt_parse_obj = opt_parser
    args = parse_options(args)

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
    puts USAGE
    puts ""
    puts "  Options:"
    puts @opt_parse_obj.summarize
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
      opts.on("--journals",   "-h", "show issue journals"){|v| @options[:journals] = true}
      opts.on("--relations",  "-r", "show issue relations tickets"){|v| @options[:relations] = true}
      opts.on("--changesets", "-c", "show issue changesets"){|v| @options[:changesets] = true}
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
end

