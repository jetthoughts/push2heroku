module Push2heroku
  class Base

    attr_accessor :branch_name, :commands, :current_user, :subdomain, :settings

    def initialize
      git = Git.new
      @branch_name = git.current_branch
      @current_user = git.current_user
      @settings = ConfigLoader.new('push2heroku.yml').load(branch_name)
      @commands = []
      @subdomain = "#{url_prefix}-#{url_suffix}".downcase.chomp('-')
    end

    def self.process
      new.push
    end

    def push
      build_commands
      commands.each { |cmd| puts ">"*20 + cmd }
      commands.each do |cmd|
        begin
          sh cmd
        rescue Exception => e
          puts e
        end
      end
    end

    private

    def url_suffix
      return branch_name if %w(staging production).include?(branch_name)

      [branch_name[0..10], current_user[0..5]].join('-').gsub(/[^0-9a-zA-Z]+/,'-').downcase
    end

    def url_prefix
      settings.app_name.gsub(/[^0-9a-zA-Z]+/,'-').downcase
    end

    def build_commands
      commands << "heroku create #{subdomain} --stack cedar --remote h#{branch_name}"
      commands << "git push h#{branch_name} #{branch_name}:master -f "

      build_config_commands

      commands << "heroku pg:reset  SHARED_DATABASE_URL --app #{subdomain} --confirm #{subdomain} --trace"
      commands << "heroku run rake db:migrate --app #{subdomain} --trace"
      commands << "heroku run rake setup --app #{subdomain} --trace"
      commands << "heroku open --app #{subdomain}"
      puts "*"*20 + 'DONE' + '*'*20
    end

    def build_config_commands
      cmd = []
      settings.config.each do |key, value|
        cmd << "#{key.upcase}=#{value}"
      end
     commands << "heroku config:add #{cmd.join(' ')} --app #{subdomain}"
    end

  end
end
