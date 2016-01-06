name "redis_server"
description "Redis Server role"
run_list("recipe[redis_server]")

default_attributes(
  "cyclecloud" => { "discoverable" => true }
)
