#! /bin/bash

yum install -y ruby

sudo -u cyclecloud -i gem install redis
gem install redis 

REDIS_HOME=$(jetpack config redis.home || echo "/mnt/scratch/redis")
if [ "${REDIS_HOME}" == ""]; then
    REDIS_HOME="/mnt/scratch/redis"
fi
mkdir -p ${REDIS_HOME}

pushd /mnt/cluster-init/scratch

if ! ls ./redis-*.tar.gz 1> /dev/null 2>&1; then
    wget http://download.redis.io/releases/redis-3.0.6.tar.gz
fi
tar xzf redis-*.tar.gz
pushd redis-*
make
make install
cp src/redis-trib.rb ${REDIS_HOME}
chmod a+rx ${REDIS_HOME}/redis-trib.rb
popd
popd

chmod a+rw -R ${REDIS_HOME}
