# The basic Redis Client recipe simply makes the server hostlist available
# to client applications via jetpack or via a conf file.

servers = cluster.search.select {|n| not n['redis'].nil? and n['redis']['ready'] == true}.map  do |n|
  "#{n['cyclecloud']['instance']['ipv4']}:#{n['redis']['base_port']}"
end
servers.sort!
Chef::Log.info "Redis cluster: #{servers.inspect}"


# Clients should use the node['redis']['hostlist'] to connect
node.set['redis']['hostlist'] = servers

# create a redis cluster host list that can be used by client applications
file node['redis']['hostfile'] do
  content servers.join("\n")
end

