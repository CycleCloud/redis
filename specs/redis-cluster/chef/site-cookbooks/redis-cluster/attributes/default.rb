
default['redis']['home'] = "/mnt/scratch/redis"
default['redis']['version'] = '3.2.6'
default['redis']['source'] = "redis-3.2.6.tar.gz"

default['redis']['base_port'] = 7000
default['redis']['server_slots'] = 4
default['redis']['replicas'] = 0
default['redis']['cluster-node-timeout'] = 5000

include_attribute 'sysctl'

default['redis']['sysctl']['vm']['overcommit_memory'] = 1
default['redis']['sysctl']['net']['core']['somaxconn'] = 512
