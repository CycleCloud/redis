#!/bin/bash

REDIS_PORTS=$(jetpack config redis.port_list || echo "7000")
if [ "${REDIS_PORTS}" == ""]; then
    REDIS_PORTS="7000"    
fi
REDIS_PORTS=${REDIS_PORTS#[}
REDIS_PORTS=${REDIS_PORTS%]}
REDIS_PORTS=${REDIS_PORTS/ /}
REDIS_HOME=$(jetpack config redis.home || echo "/mnt/scratch/redis")
if [ "${REDIS_HOME}" == ""]; then
    REDIS_HOME="/mnt/scratch/redis"
fi

CLUSTER_REPLICAS=

echo "Starting redis servers for ports: ${REDIS_PORTS}"
REDIS_PORTS_ARRAY=$(echo $REDIS_PORTS | tr ", " "\n")
for PORT in ${REDIS_PORTS_ARRAY}; do
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
        rm *.aof nodes.conf std_${PORT}.out std_${PORT}.err
        nohup redis-server ./redis_${PORT}.conf > ./std_${PORT}.out 2> ./std_${PORT}.err &
        popd
    else
        echo "WARNING: Skipping ${SERVER_DIR} - directory already exists.  Assuming redis already running..."
    fi

    CLUSTER_REPLICAS=${CLUSTER_REPLICAS} 127.0.0.1:${PORT}
done

pushd ${REDIS_HOME}
echo yes | ./redis-trib.rb create --replicas 1 ${CLUSTER_REPLICAS}
popd

