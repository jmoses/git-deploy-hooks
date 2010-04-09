set :deploy_via, :remote_cache
set :branch, "master" unless exists?(:branch)

namespace :remote_cache do
  desc "Reset the remote cache to master"
  task :reset do    
    git "reset --hard", "checkout master"
  end
  
  desc "Fetch any new changesets"
  task :update do
    git "pull"
  end
  
  desc "Set the remote cache to a particular branch"
  task :set_branch do
    branch = fetch(:branch, 'master')
    if branch == 'master'
      logger.trace "Skipping branch changing, master is the default"
    else
      # if the branch exists, branch then checkout
      branches = capture(join_git_commands("branch"))
      if branches.any? {|b| b =~ /#{branch}/ }
        git "checkout #{branch}", "merge origin/#{branch}"
      else
        git "checkout --track -b #{branch} origin/#{branch}"
      end
    end
  end
  
  desc "What branch are we on?"
  task :what_branch do
    git "status"
  end
  
  def git( *commands )
    run join_git_commands(*commands)
  end
  
  def join_git_commands( *commands )
    command_array = ["cd #{shared_path}/cached-copy"]
    commands.flatten.each {|c| command_array << "git #{c}" }
    command_array.join(" && ")    
  end
  
  before "remote_cache:set_branch", "remote_cache:update"
  before "remote_cache:update", "remote_cache:reset"
end

require 'capistrano/recipes/deploy/strategy/remote_cache'
module ::Capistrano
  module Deploy
    module Strategy
      class RemoteCache < Remote
        private
          def update_repository_cache
            logger.trace "updating the cached checkout on all servers"
            scm_run("if [ ! -d #{repository_cache} ]; then " +
              "#{source.checkout(revision, repository_cache)}; fi")
            
            # task = find_task("remote_cache:set_branch")
            # task.run
            top.remote_cache.set_branch
          end
          
      end
    end
  end
end

desc "Reset the remote caches to nothing, for use when we change tags"
task :remote_cache_reset do
  run "rm -rf #{File.join(shared_path, 'cached-copy')}"
end

