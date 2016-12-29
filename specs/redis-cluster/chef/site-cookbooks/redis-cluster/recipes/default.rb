

redis_home=node['redis']['home']
redis_srcpath="#{redis_home}/redis-#{node['redis']['version']}"
installation_marker_file = "#{redis_srcpath}/src/redis-server"

directory node['redis']['home'] do
  mode "0755"
  recursive true
end

if ::File.exists?(installation_marker_file)
    Chef::Log.info "Redis already installed at: #{redis_srcpath}"
else
    Chef::Log.info "Installing Redis to: #{redis_srcpath}"

    include_recipe 'build-essential'

    log "Building Redis package." do level :info end
    
    thunderball 'redis' do
      url "cycle/#{node['redis']['source']}"
    end

    execute "untar redis" do
      command "tar -xf #{node['thunderball']['storedir']}/cycle/#{node['redis']['source']} -C #{redis_home}"
      creates "#{redis_srcpath}/src/redis-trib.rb"
      action :run
    end

    execute "build redis" do
      command "make && make install"
      creates installation_marker_file
      cwd redis_srcpath
      action :run
    end

end

execute "set redis ownership" do
  command "chmod a+rwX -R #{redis_home}"
  cwd redis_srcpath
  action :run
end

# Redis Gem is required for redis-trib
log "Copying Redis Gem..." do level :info end
cookbook_file "/tmp/redis-3.3.1.gem" do
  source "redis-3.3.1.gem"
end

# Need to use the `--local` option to avoid network timeouts talking to rubygems.org
log "Installing Redis Gem..." do level :info end
chef_gem "redis" do
  clear_sources true
  compile_time false
  source "/tmp/redis-3.3.1.gem"
  options "--no-ri --no-rdoc --local"
end
gem_package "redis" do
  clear_sources true
  source "/tmp/redis-3.3.1.gem"
  options "--no-ri --no-rdoc --local"
end

%w{redis-benchmark redis-check-aof redis-cli redis-sentinel redis-server redis-trib.rb}.each do |exe|
  execute "chmod a+rx #{redis_srcpath}/src/#{exe}"
  link "/usr/local/bin/#{exe}" do
    to "#{redis_srcpath}/src/#{exe}"
  end  
end

link "#{redis_home}/redis-trib.rb" do
  to "#{redis_srcpath}/src/redis-trib.rb"
end

