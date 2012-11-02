require 'bundler/setup'
require 'gollum'
require 'fileutils'
require 'tmpdir'
require 'gitnesse/railtie' if defined?(Rails::Railtie)

# core module for settings
module Gitnesse

  # Public: Return String with url of the git wiki repo containing features.
  #
  def self.repository_url
    @@repository_url
  end

  # Public: Set url of the git-based wiki repo containing features.
  #
  # repository_url - A String containing your repo's url.
  #
  # Example:
  #
  #   Gitnesse.config do |config|
  #     config.repository_url = "git@github.com:luishurtado/gitnesse-wiki.wiki"
  #   end
  #
  def self.repository_url=(repository_url)
    @@repository_url = repository_url
  end

  # Public: Return String with branch of the git-based wiki repo containing features.
  #
  def self.branch
    @@branch ||= "master"
  end

  # Public: Set branch of the git-based wiki repo containing features.
  #
  # branch - A String containing which branch of your repo to use.
  #
  # Example:
  #
  #   Gitnesse.config do |config|
  #     config.branch = "master"
  #   end
  #
  def self.branch=(branch)
    @@branch = branch
  end

  # Public: Return String with which directory being used to sync with git-wiki stored feature stories.
  #
  def self.target_directory
    @@target_directory ||= File.join(Dir.pwd, 'features')
  end

  # Public: Set local directory used to sync with git-wiki stored feature stories.
  #
  # target_directory - A String containing which directory to use.
  #
  # Example:
  #
  #   Gitnesse.config do |config|
  #     config.target_directory = "features"
  #   end
  #
  def self.target_directory=(target_directory)
    @@target_directory = target_directory
  end

  def self.config
    yield self
  end

  def perform
    %w(git cucumber).each do |cmd|
      output=`#{cmd} --version 2>&1`; requirement_ok=$?.success?
      abort("#{cmd} command not found or not working.") unless requirement_ok
    end

    abort("Setup git URL for Gitnesse.") if Gitnesse.repository_url.nil?

    puts "Loading features into: #{Gitnesse.target_directory}"

    load_ok = false
    Dir.mktmpdir do |tmp_dir|
      # clone repository into tmp dir
      output=`git clone #{Gitnesse.repository_url} #{tmp_dir} 2>&1`; repo_cloned=$?.success?

      if repo_cloned
        FileUtils.mkdir(Gitnesse.target_directory) unless File.exists?(Gitnesse.target_directory)
        wiki_pages = wiki = Gollum::Wiki.new(tmp_dir).pages

        wiki_pages.each do |wiki_page|
          page_features = get_features(wiki_page.raw_data)

          page_features.each do |feature_name, feature_content|
            File.open("#{Gitnesse.target_directory}/#{feature_name}.feature","w") {|f| f.write(feature_content) }
            puts "============================== #{feature_name} =============================="
            puts feature_content
            load_ok = true
          end
        end
      else
        puts output
      end
    end

    if load_ok
      puts "Now going to run cucumber..."
      exec("cucumber #{Gitnesse.target_directory}/*.feature")
    end
  end
  module_function :perform

  def get_features(data)
    features = {}

    if match_result = data.match(/\u0060{3}(.+)\u0060{3}/m)
      captures = match_result.captures

      # create hash with feature name as key and feature text as value
      captures.each do |capture|
        feature_definition_at = capture.index('Feature:')
        feature_text = capture[feature_definition_at,capture.size-1]
        feature_lines = feature_text.split("\n")
        feature_definition = feature_lines.grep(/^Feature:/).first

        if feature_definition
          feature_name = feature_definition.split(":").last.strip.gsub(" ","-").downcase
          features[feature_name] = feature_text
        end
      end
    end

    features
  end
  module_function :get_features
end