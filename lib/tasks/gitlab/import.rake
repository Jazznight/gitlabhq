namespace :gitlab do
  namespace :import do
    # How to use:
    #
    #  1. copy your bare repos under git base_path
    #  2. run bundle exec rake gitlab:import:repos RAILS_ENV=production
    #
    # Notes:
    #  * project owner will be a first admin
    #  * existing projects will be skipped
    #
    desc "GITLAB | Import bare repositories from git_host -> base_path into GitLab project instance"
    task repos: :environment do

      git_base_path = Gitlab.config.gitlab_shell.repos_path
      repos_to_import = Dir.glob(git_base_path + '/*')

      namespaces = Namespace.pluck(:path)

      repos_to_import.each do |repo_path|
        repo_name = File.basename repo_path

        # Skip if group or user
        next if namespaces.include?(repo_name)

        # skip if not git repo
        next unless repo_name =~ /.git$/

        next if repo_name == 'gitolite-admin.git'

        path = repo_name.sub(/\.git$/, '')

        project = Project.find_with_namespace(path)

        puts "Processing #{repo_name}".yellow

        if project
          puts " * #{project.name} (#{repo_name}) exists"
        else
          user = User.admins.first

          project_params = {
            name: path,
          }

          project = Projects::CreateContext.new(user, project_params).execute

          if project.valid?
            puts " * Created #{project.name} (#{repo_name})".green
          else
            puts " * Failed trying to create #{project.name} (#{repo_name})".red
          end

          public_key_file=File.new("#{ENV['HOME']}/.ssh/id_rsa.pub","r")
          key_string = public_key_file.gets
          key_title = key_string.split(/= /,2)[1]

          admin = User.all.first
          key = Key.create(
            :key => key_string,
            :title => key_title
          )
          admin.keys << key;
        end
      end

      puts "Done!".green
    end
  end
end
