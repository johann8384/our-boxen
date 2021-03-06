#!/usr/bin/env ruby
#
# Required Gems: daemons, termios, curb gems
#
# on ubuntu curb you will need the package libwww-dev
#
# listens on 127.0.0.1:PMPDADDY_PORT
#
# Configuration options go in
# ~/.pmpdaddyrc 
#
# Recommended ~/.pmpdaddyrc contents:
############
# keepalive_interval=300
# verbose=false
# pmp_host=https://pmp.contegix.com
# strip_string=.managed.contegix.com
# strip_string=.contegix.backnet
# convert_cond=.jira.com
# convert_resource=Jira Studio Instance
############


#These should not need to be changed
PMPDADDY_VERSION = "1.0.1"
PMPDADDY_HOST = "localhost"
PMPDADDY_PORT = 10127
PMPDADDY_SLEEP_INTERVAL = 1
PMPDADDYRC = ENV['HOME'] + "/.pmpdaddyrc"

require 'rubygems'
require 'uri'
require 'curb'
require 'gserver'
require 'daemons'
require 'net/telnet'
require 'termios'
require 'optparse'

class PmpDaddy < GServer
  include Daemonize
  def initialize
    @properties = Hash.new
    @properties[:verbose] = false # Can change this in .pmpdaddyrc
    @strip_strings = Array.new
    @cookiefile = ENV['HOME'] + "/.pmpcookie"
    @password = ""
    @auth = "" 
    @converts = Array.new(2) { Hash.new }
    @convert_current = 0
    super(PMPDADDY_PORT)
    parse_config
    if @properties[:pmp_host] == nil
      self.pmp_host=get_pmp_host
      write_config
    end
    if @properties[:username] == nil
      self.username=get_username
      write_config
    end
    if @properties[:keepalive_interval] == nil
      self.keepalive_interval=120
      write_config
    end
  end

  def parse_config
    begin
    File.readlines(PMPDADDYRC).each do |line|
      if line =~ /^(\w+)=(.+)$/
        begin
          self.send($1.downcase + "=", $2)
        rescue => e
          print "Unknown option #{$1} (#{e})\n"
        end
      end
    end
    rescue
     return
    end
  end
  def get_config
    parse_config
    return @properties
  end
  def newline=(value)
    @properties[:newline] = value
  end

  def username=(value)
    @properties[:username] = value
  end

  def keepalive_interval=(value)
    @properties[:keepalive_interval] = value.to_i
  end

  def strip_string=(value)
    @strip_strings.push(value)
  end

  def pmp_host=(value)
    @properties[:pmp_host] = value
  end

  def convert_cond=(value)
    @converts[@convert_current][:cond] = value
  end

  def convert_resource=(value)
    @converts[@convert_current][:resource] = value
    @convert_current =+ 1
  end

  def alert=(value)
    if value == "true"
      @properties[:alert] = true
    elsif value == "false"
      @properties[:alert] = false
    else
      print "Invalid option for alert"
    end
  end

  def verbose=(value)
    if value == "true"
      @properties[:verbose] = true
    elsif value == "false"
      @properties[:verbose] = false
    else
      print "Invalid option for verbose"
    end
  end

  def write_config
    f = open(PMPDADDYRC, "w+")
    @properties.each do |key, value|
      f.puts("#{key}=#{value}")
    end
    f.close
  end

  def get_username
      return ask("Username: ", true).chomp
  end

  def get_pmp_host
    return ask("Example: https://pmp.contegix.com\nBase URL for PMP Server (including http/https): ", true).chomp
  end

  def ask(prompt, verbose = false)
    if verbose
      print prompt
      return $stdin.gets
    end
    begin
      $stdin.extend Termios
    rescue
      print "Terminating.."
      exit
    end
    oldt = $stdin.tcgetattr
    newt = oldt.dup
    newt.lflag &= ~Termios::ECHO
    $stdin.tcsetattr(Termios::TCSANOW, newt)
    print prompt
    a = $stdin.gets
    $stdin.tcsetattr(Termios::TCSANOW, oldt)
    return a.chomp
  end

  def initialize_pmpserver
    @c = Curl::Easy.new("#{@properties[:pmp_host]}/pmpdaddy.cc") do |curl|
      curl.enable_cookies = true

      if curl.enable_cookies? != true
        print "Couldn't enable cookies\n"
        exit
      end
      curl.ssl_verify_host = false
      curl.ssl_verify_peer = false
      curl.follow_location = true
      curl.cookiejar = @cookiefile
      curl.verbose = @properties[:verbose]
    end
    @c.perform
  end

  def login_to_pmpserver
    @c.url = "#{@properties[:pmp_host]}/j_security_check"
    @c.http_post(@auth)
    @c.perform
    # Yes it's successful on 404, I'd explain it but I just don't want to.
    if @c.response_code != 404
      print "Authentication to #{@properties[:pmp_host]}/ failed\n"
      #print @auth + "\n"
      exit 1
    end
  end

  def keepalive
    @c.url = "#{@properties[:pmp_host]}/j_security_check"
    @c.http_get
    if @c.response_code != 404
      print "Connection lost, attempting to reconnect\n"
      initialize_pmpserver
      login_to_pmpserver
    end
    
  end

  def serve(io)
    action = io.gets.chomp
    if action =~ /STOP/
      print "Dying\n"
      exit 1
    elsif action =~ /RANDOM/
      io.puts(generate_password())
      return
    elsif action =~ /ADD/
      resource = io.gets.chomp
    elsif action =~ /GET/
      resource = io.gets.chomp
    elsif action =~ /CHANGE/
      resource = io.gets.chomp
    elsif action =~ /MYPASSWORD/
      io.puts(@password) + "\r\n"
    else
      # Preserve backward compatibility for now
      resource = action
      action = "GET"
    end
    account = io.gets.chomp
    print "\nNew Request: #{action} : #{account}@#{resource}:"
    if action =~ /GET/
      io.puts(fetch_password(resource, account))
      print "retrieved\n"
    elsif action =~ /CHANGE/
      addlargs = io.gets.chomp
      io.puts(change_password(resource, account, addlargs))
      print "changed\n"
    elsif action =~ /ADD/
      resourceURL = io.gets.chomp
      location = io.gets.chomp
      application = io.gets.chomp
      io.puts(create_resource(resource, account, resourceURL, location, application))
      print "added\n"
    else
      print "\n"
    end  
  end

  def fetch_password(resource, account = 'contegix')
    STDOUT.flush
    if !@strip_strings.empty?
      @strip_strings.each { |s| 
        if resource.index(s) != nil
          print "Stripping #{s} from #{resource}\n"
          resource = resource.sub(s, "")
        end
      }
    end

    if !@converts.empty?
        print "\nDoing conversions\n" 
      @converts.each do |c|
	if (c[:cond].to_s != "")
	  print "Checking for condition #{c[:cond]}\n"
	  regex = Regexp.new(c[:cond])
	  if regex.match(resource) != nil
		print "matched, now changing #{resource} to #{c[:resource]}\n"
		resource = c[:resource]
	  end
	end
      end
    end
    print "Now retrieving password for #{account}@#{resource}\n"
    url = "#{@properties[:pmp_host]}/jsp/xmlhttp/AjaxResponse.jsp?RequestType=PasswordRetrived&SUBREQUEST=XMLHTTP&=&account=#{URI::encode(account)}&resource=#{URI::encode(resource)}"
    @c.url = url
    @c.http_get
    password = @c.body_str.strip
    if password.length > 200
      return "Error retrieving password from server, too much data returned"
    else
      return password
    end

  end

  def generate_password()
    time = "%i" % (Time.now.to_f * 1000)
    url = "#{@properties[:pmp_host]}/jsp/xmlhttp/AjaxResponse.jsp?RequestType=generate&Rule=Standard&time=#{time}"
    @c.url = url
    @c.http_get
    @c.body_str.strip
  end

  def change_password(resource, account = 'contegix', addlargs = '')
    STDOUT.flush
    if !@strip_strings.empty?
      @strip_strings.each { |s| 
        if resource.index(s) != nil
          print "Stripping #{s} from #{resource}\n"
          resource = resource.sub(s, "")
        end
      }
    end

    if !@converts.empty?
        print "\nDoing conversions\n" 
      @converts.each do |c|
	if (c[:cond].to_s != "")
	  print "Checking for condition #{c[:cond]}\n"
	  regex = Regexp.new(c[:cond])
	  if regex.match(resource) != nil
		print "matched, now changing #{resource} to #{c[:resource]}\n"
		resource = c[:resource]
	  end
	end
      end
    end

    password = generate_password()

    print "Now changing password for #{account}@#{resource} to #{password}\n"
    url = "#{@properties[:pmp_host]}/jsp/xmlhttp/AjaxResponse.jsp?RequestType=PasswordChange&hostName=#{URI::encode(resource)}&accountName=#{URI::encode(account)}&defaultvalue_schar1=#{URI::encode(password)}&notes=N/A#{addlargs}"
    @c.url = url
    @c.http_get
    response = @c.body_str.strip
    if response == "SUCCESS"
      return password
    elsif response.length > 200
      return "Error changing password, too much data returned"
    else
      return response
    end

  end

  def create_resource(resource, account, resourceURL, location, application)
    password = generate_password()
    url = "#{@properties[:pmp_host]}/CreateResources.do"
    @c.url = url
    @c.http_post("SysName=#{resource}",
                 "DNSName=",
                 "SysType=Application",
                 "group=Default+Group",
                 "desc=Managed+VM",
                 "dept=",
                 "resourceURL=#{resourceURL}",
                 "location=#{location}",
                 "Rule=Standard",
                 "resourcedefaultvalue_char1=#{application}",
                 "tmp=#{resource}",
                 "User1=",
                 "Pass1=",
                 "spassword=",
                 "isEnforcePolicy=false",
                 "cpassword=",
                 "Note1=",
                 "Domain1=",
                 "UserAccount=",
                 "Password=",
                 "Notes=",
                 "Domain=",
                 "ConfirmPass=",
                 "Password=#{password}",
                 "Domain=",
                 "Notes=",
                 "ConfirmPass=#{password}",
                 "UserAccount=#{account}",
                 "remotesync=0",
                 "remotemode=ssh")
    password
  end

  def launch_daemon()
    print "Connecting to pmp server #{@properties[:pmp_host]} ...\n"
    self.initialize_pmpserver
    
    @password = ask("#{@properties[:username]}'s password:")
    @auth = "j_username=#{@properties[:username]}&username=#{@properties[:username]}&j_password=#{URI::encode(@password)}&domainName=LDAP&submit="
    print "\n"
    
    self.login_to_pmpserver
    print "Login successful.  Forking daemon.\n"
    
    pid = Process.fork {
    	daemonize("/tmp/pmpdaddy", "pmpdaddy")
    	self.audit =  false                 # Turn logging on.
    	server_thread = Thread.new { self.start }
    	refresher_thread = Thread.new { 
    	  loop do 
    	    self.keepalive
    	    sleep @properties[:keepalive_interval]
    	  end
   	 	}
    	server_thread.join
   	 	refresher_thread.join
   	 	exit
    }
    Process.detach(pid)
  end

  def self.add_resource(resource, account = 'contegix', resourceURL = '', location = '', application = '')
    print "Adding #{resource} with #{account} account...\n"
    server = Net::Telnet::new("Host" => PMPDADDY_HOST,
                        "Port" => PMPDADDY_PORT,
                        "Telnetmode" => false,
                        "Timeout"    => 20)
    server.puts("ADD")
    server.puts(resource)
    server.puts(account)
    server.puts(resourceURL)
    server.puts(location)
    server.puts(application)
    server.waitfor("\n")
  end
	
  def self.get_password(resource, account = 'contegix')
    server = Net::Telnet::new("Host" => PMPDADDY_HOST,
                        "Port" => PMPDADDY_PORT,
                        "Telnetmode" => false,
                        "Timeout"    => 20)
    server.puts("GET")
    server.puts(resource.to_s)
    server.puts(account)
    server.waitfor("\n")
  end

  def self.change_password(resource, account = 'contegix', pmponly = false)
    addlargs = ''
    if !pmponly
      addlargs = '&remote=1'
    end
    server = Net::Telnet::new("Host" => PMPDADDY_HOST,
                        "Port" => PMPDADDY_PORT,
                        "Telnetmode" => false,
                        "Timeout"    => 60)
    server.puts("CHANGE")
    server.puts(resource.to_s)
    server.puts(account)
    server.puts(addlargs)
    server.waitfor("\n")
  end

  def self.generate_password()
    server = Net::Telnet::new("Host" => PMPDADDY_HOST,
                        "Port" => PMPDADDY_PORT,
                        "Telnetmode" => false,
                        "Timeout"    => 20)
    server.puts("RANDOM")
    server.waitfor("\n")
  end

  def self.kill
    begin
      server = Net::Telnet::new("Host" => PMPDADDY_HOST,
                              "Port" => PMPDADDY_PORT,
                              "Telnetmode" => false)
      server.puts("STOP")
    rescue
      # Can't connect? then it's probably not running
      return
    end
   exit
  end  

  def self.test_connection
    server = Net::Telnet::new("Host" => PMPDADDY_HOST,
                              "Port" => PMPDADDY_PORT,
                              "Telnetmode" => false)
  end

end

def parse_options(args)
  options = { :add => false, :change => false, :pmponly => false, :generate => false, :resource => '', :verbose => true, :daemon => false, :kill => false, :account => 'contegix', :resourceURL => '', :location => '', :application => '', :password_only => false, :newline => true }

  parser = OptionParser.new

  parser.on('-h', '--help','displays usage information') do
    puts parser
    exit
  end

  parser.on('-A', '--add', 'Add a new application resource instead of querying') do |v|
    options[:add] = true
  end

  parser.on('-C', '--change', 'Change a resource account password to a new random password via PMP') do |v|
    options[:change] = true
  end

  parser.on('-P', '--pmponly', 'Change the password only in PMP (only valid with -C)') do |v|
    options[:pmponly] = true
  end

  parser.on('-R', '--random', 'Generate a random password via PMP') do |v|
    options[:generate] = true
  end

  parser.on('-r resourcename', '--resource-name resourcename',  'Name of the resource to get, usually servername') do |v|
    options[:resource] = v
  end

  parser.on('-a accountname', '--account-name accountname',  'Name of the Account to get, default "contegix" ') do |v|
    options[:account] = v
  end

  parser.on('-u resourceURL', '--url resourceURL',  'URL of the resource being added (only valid with -A)') do |v|
    options[:resourceURL] = v
  end

  parser.on('-l location', '--location location',  'Location of the resource being added (only valid with -A)') do |v|
    options[:location] = v
  end

  parser.on('-t applicationtype', '--type applicationtype',  'Application type of the resource being added (only valid with -A)') do |v|
    options[:application] = v
  end

  parser.on('-q', '--quiet', 'Don\'t output any information. Only valid if pmpdaddy Daemon  is already running') do |v|
    options[:verbose] = false
  end

 parser.on('-po', '--password-only', 'Output only the password. Only valid if pmpdaddy Daemon  is already running') do |v|
    options[:password_only] = true
  end

  parser.on('-k', '--kill', 'Shutdown the PmpDaddy Server') do |v|
    options[:kill] = true
  end

  parser.on('-h host', '--pmphost host', 'Base URL for the PMP Server') do |v|
    options[:pmp_host] = v
  end

  options[:newline] = nil
  if (defined? @properties[:newline]) && (@properties[:newline] == "false")
    options[:newline] = " | tr -d '\n'"
  end
  parser.on('-n', '--nonewnline', 'Do not spit out a newline on the end of the password') do |v|
    options[:newline] = " | tr -d '\n'"
  end

  options[:alert] = @properties[:alert]
  parser.on('-g', '--growl', '"growl" all output to the OSX notification daemon (see the "terminal-notifier" gem)') do |v|
    options[:alert] = true
  end

  parser.on('-v', '--version', 'Print script version and exit') do
    print "PmpDaddy v#{PMPDADDY_VERSION}\n"
    exit 0
  end

begin
  resource = parser.parse(args)
  rescue OptionParser::ParseError => e
    print "Parse Error: " + e
  end

  if resource != nil
   options[:resource] = resource[0].to_s
  end
  options
end


def say(text)
  print text if @options[:verbose]
  # check for terminal notifier
  osxnotify=`which terminal-notifier |tr -d '\n'`
  if File.file?(osxnotify) and @options[:alert]
    `#{osxnotify} -message "#{text}"`
  end
end

######################
### Main Code Here ###
######################

if __FILE__ == $0
  @properties = PmpDaddy.new.get_config
  @options = parse_options(ARGV)

  if @options[:kill]
    say "Attempting to stop pmpdaddy Deamon\n"
    PmpDaddy.kill
    exit 1
  end

  begin
    if @options[:add]
      pass = PmpDaddy.add_resource(@options[:resource], @options[:account], @options[:resourceURL], @options[:location], @options[:application])
    elsif @options[:change]
      pass = PmpDaddy.get_password(@options[:resource], @options[:account])
      say "The old password for #{@options[:account]}@#{@options[:resource]} is " + pass
      say "Changing password.  Please stand by as this may take a minute ...\n"
      pass = PmpDaddy.change_password(@options[:resource], @options[:account], @options[:pmponly])
    elsif @options[:generate]
      pass = PmpDaddy.generate_password()
    else
      pass = PmpDaddy.get_password(@options[:resource], @options[:account])
    end
  rescue
    print "pmpdaddy daemon not running, starting daemon\n"

    app = PmpDaddy.new
    app.launch_daemon()

    print "Testing daemon\n"
    begin 
      PmpDaddy.test_connection
    rescue
      print "."
      STDOUT.flush
      sleep PMPDADDY_SLEEP_INTERVAL
      retry
    end
    sleep 1
    print "\n"
    retry
  end
  if (pass.class != NilClass) and !(pass =~ /DENIED/) 
    if @options[:generate] == false 
	if @options[:password_only] == false
      		say "The password for #{@options[:account]}@#{@options[:resource]} is " + pass
	end
    else
      say "Your random password is " + pass + "\n"
    end
    if @options[:password_only]
      print pass
    else
      if system("which xclip >/dev/null 2>&1") 
        system("echo '#{pass}' #{@options[:newline]} | xclip -selection clipboard")
        say "For your convenience I have copied it to your clipboard. \n\n" 
      elsif system("which pbcopy >/dev/null 2>&1")
        system("echo '#{pass}' #{@options[:newline]} | pbcopy")
        say "For your convenience I have copied it to your clipboard. \n\n"
      end
    end
  else
    say "Failed to retrieve password\n"
    exit 1
  end
  exit 0
end

