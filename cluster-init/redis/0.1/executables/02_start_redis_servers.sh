#!/bin/bash

REDIS_PORTS=$(jetpack config redis.port_list || echo "7000")
if [ "${REDIS_PORTS}" == "" ]; then
    REDIS_PORTS="7000"    
fi
REDIS_PORTS=${REDIS_PORTS#[}
REDIS_PORTS=${REDIS_PORTS%]}
REDIS_PORTS=${REDIS_PORTS/ /}
REDIS_HOME=$(jetpack config redis.home || echo "/mnt/scratch/redis")
if [ "${REDIS_HOME}" == "" ]; then
    REDIS_HOME="/mnt/scratch/redis"
fi
REDIS_REPLICA_COUNT=$(jetpack config redis.replicas || echo "1")

NODE_IP=$( hostname -i )
CLUSTER_REPLICAS=

echo "Starting redis servers for ports: ${REDIS_PORTS}"
REDIS_PORTS_ARRAY=$(echo $REDIS_PORTS | tr ", " "\n")
for PORT in ${REDIS_PORTS_ARRAY}; do
    echo "Port: ${PORT}"   
    SERVER_DIR="${REDIS_HOME}/${PORT}"
    if [ ! -d "$DIRECTORY" ]; then    
        mkdir -p ${SERVER_DIR}
        chmod a+rwx ${SERVER_DIR}

        cat <<EOF > ${SERVER_DIR}/redis_${PORT}.conf
port ${PORT}
cluster-enabled yes
cluster-config-file nodes.${PORT}.conf
cluster-node-timeout 5000
appendonly no
save ""
EOF
        chmod a+r -R ${SERVER_DIR}
        pushd ${SERVER_DIR}
        echo "Starting host: ${NODE_IP}:${PORT} in ${SERVER_DIR}"
        rm -f *.aof nodes.conf redis_${PORT}.out redis_${PORT}.err
        redis-server ./redis_${PORT}.conf --loglevel verbose > ./redis_${PORT}.log 2>&1 &
        popd
    else
        echo "WARNING: Skipping ${SERVER_DIR} - directory already exists.  Assuming redis already running..."
    fi

    CLUSTER_REPLICAS="${CLUSTER_REPLICAS} ${NODE_IP}:${PORT}"
done

pushd ${REDIS_HOME}
yes yes | ./redis-trib.rb create --replicas ${REDIS_REPLICA_COUNT} ${CLUSTER_REPLICAS}
popd

