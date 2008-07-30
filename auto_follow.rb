#!/usr/bin/env ruby

require 'rubygems'
require "logger"
require "yaml"
gem "twitter", '>=0.2.6'
require 'twitter'
require 'hpricot'

# 
# Usage:
# follower = AutoFollower.new('admin@example.com', 'password')
# follower.start
# follower.stalk('cincinnati')
# 
# Another option if you only want to follow your followers is
# running it off command line like auto_follow.rb admin@example.com password
# 
class AutoFollower
  
  FOLLOW_INTERVAL = 10
  TWITTER_PAGE_SIZE = 100
  BLACK_LIST = 'black_list.yml'
  
  attr_accessor :black_list
  
  def initialize(email, password, output = STDOUT, level = Logger::INFO)
    @twitter = Twitter::Base.new(email, password)
    
    output = eval(output) if output.is_a?(String)
    level = eval(level) if level.is_a?(String)
    
    @log = Logger.new(output)
    @log.sev_threshold = level
    
    @black_list = File.exist?(BLACK_LIST) ? YAML.load_file(BLACK_LIST) : []
  end
  
  def start
    peeps = (followers - friends).find_all { |n| !black_listed?(n) }
    
    @log.info "Need to follow #{peeps.size} people"
    peeps.each { |name| follow(name) }
  end

  def stalk(query, page = 1)
    doc = Hpricot(open("http://twitter.com/search/users?q=#{query}&page=#{page}"))
    names = doc.search(".screen_name span").collect { |d| d.innerHTML }
    return if names.empty?
    (names - friends).find_all { |n| !black_listed?(n) }.each { |name| follow(name) }
    page = page + 1
    stalk(query, page)
  end

  def followers
    @followers ||= find_followers
  end
  
  def friends
    @friends ||= find_friends
  end

  private
  
    def black_listed?(name)
      black_list.include?(name)
    end
  
    def follow(name, delay = FOLLOW_INTERVAL)
      @log.info "Following: #{name}"
      @twitter.create_friendship(name)
      sleep delay
    end
    
    def find_followers(page = 1)
      @log.debug "followers page: #{page}"
      f = @twitter.followers(:lite => true, :page => page).collect { |f| f.screen_name }
      return f if f.empty? || f.size < TWITTER_PAGE_SIZE
      f + find_followers(page + 1)
    end
    
    def find_friends(page = 1)
      @log.debug "friends page: #{page}"
      f = @twitter.friends(:lite => true, :page => page).collect { |f| f.screen_name }
      return f if f.empty? || f.size < TWITTER_PAGE_SIZE
      f + find_friends(page + 1)
    end
end

if $0 == __FILE__
  AutoFollower.new(*ARGV).start
end