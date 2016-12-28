include_recipe 'redis-cluster::default'
include_recipe 'redis-cluster::server_install'

# IMPORTANT:
# If running through STunnel - set NODE_IP to loopback (127.0.0.1)
# redis-cluster will report back the ips of the cluster members
# See: https://github.com/xetorthio/jedis/issues/943

# TODO: get list from search
cluster_replica_list=""
for i in 0..(node['redis']['server_slots'] - 1)
    server_slot_port = node['redis']['base_port'] + i
    server_slot_home = "#{node['redis']['home']}/#{server_slot_port}"
    server_conf_file = "redis_#{server_slot_port}.conf"
    server_address = "#{node[:cyclecloud][:instance][:ipv4]}:#{server_slot_port}"
    cluster_replica_list = cluster_replica_list + "#{server_address} "

    directory server_slot_home do
      owner 'root'
      group 'root'
      mode '0755'
      action :create
    end

    template "#{server_slot_home}/#{server_conf_file}" do
        source "redis.conf.erb"
        mode "0644"
        owner 'root'
        group 'root'
        variables(:port => server_slot_port)
    end


    log "Checking Redis server: #{server_address} in #{server_slot_home}" do level :info end

    log "Redis server: #{server_address} already running" do
        level :info
        only_if "ps aux | grep 'redis.*:#{server_slot_port}' | grep -q -v grep"
    end

    if node["redis"]["version"] < "3.2"
      protected_mode_arg = ""
    else
      protected_mode_arg = "--protected-mode no"
    end


    execute "start_redis_#{server_slot_port}" do
        command "/usr/local/bin/redis-server #{server_conf_file} #{protected_mode_arg} --loglevel verbose > ./redis_#{server_slot_port}.log 2>&1 &"
        cwd server_slot_home
        action :nothing
    end

    execute "clean_redis_#{server_slot_port}" do
        command "rm -f *.aof nodes.#{server_slot_port}.conf redis_#{server_slot_port}.out redis_#{server_slot_port}.err"
        cwd server_slot_home
        notifies :run, "execute[start_redis_#{server_slot_port}]", :immediately

        not_if "ps aux | grep 'redis.*:#{server_slot_port}' | grep -q -v grep"
    end

    # It appears that sometimes redis comes up without the correct config for protected mode...
    # TBD: does this mean the other configs aren't loaded?
    if node["redis"]["version"] > "3.2"
	    execute "disable_protected_mode_#{server_slot_port}" do
	        command "/usr/local/bin/redis-cli -c -h 127.0.0.1 -p #{server_slot_port} config set protected-mode no >> ./redis_#{server_slot_port}.log 2>&1 &"
	        cwd server_slot_home
	        action :run
	        not_if 
	    end
	end

end
node.set['redis']['ready'] = true
node.set['cyclecloud']['discoverable'] = true

if node["redis"]["members"].nil?
  members = nil
  timeout = 60 * 5
  omega = Time.now.to_i + timeout
  while Time.now.to_i < omega do
    members = cluster.search.select {|n| not n['redis'].nil? and n['redis']['ready'] == true}.map  do |n|
      n[:cyclecloud][:instance][:ipv4]
    end
    if members.length == node["redis"]["cluster_size"]
      break
    end
    Chef::Log.info "Waiting on Redis cluster: so far - #{members.inspect}"
    sleep 10
  end
end

if members.length != node["redis"]["cluster_size"]
  raise Exception, "Redis cluster timed out!"
end
members.sort!
Chef::Log.info "Redis cluster: [ #{members.inspect} ]"
node.set['redis']['members'] = members

# first ip will initialize
if node[:cyclecloud][:instance][:ipv4] == members[0]
  cluster_replica_list = ""
  for member in members
    for i in 0..(node['redis']['server_slots'] - 1)
      server_slot_port = node['redis']['base_port'] + i
      server_address = "#{member}:#{server_slot_port}"
      cluster_replica_list = cluster_replica_list + "#{server_address} "
    end
  end
  Chef::Log.info cluster_replica_list
  execute "Create Redis cluster" do
      command "yes yes | ./redis-trib.rb create --replicas #{node['redis']['replicas']} #{cluster_replica_list} | tee /dev/stderr | ( ! grep -q 'error\|CLUSTERDOWN' )"
      cwd node['redis']['home']
      # Verify that the "myself" line is not the only line
      not_if "redis-cli -h #{node[:cyclecloud][:instance][:ipv4]} -p #{node['redis']['base_port']} cluster nodes | grep -q -v 'myself'"
  end

  # Sadly, redis-cli isn't reliable about setting the error code
  execute "Test redis status or fail" do
    command "redis-cli -c -h #{node[:cyclecloud][:instance][:ipv4]}  -p #{server_slot_port} set status_test up | tee /dev/stderr | ( ! grep -q 'error\|CLUSTERDOWN' )"
  end

end
