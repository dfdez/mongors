#!/bin/bash
set -e

COMPOSE="docker compose"

if ! command -v $COMPOSE &> /dev/null; then
    COMPOSE="docker-compose"
fi

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi
PORT=${PORT:-27017}

cleanup() {
    echo "Cleaning up environment..."
    $COMPOSE down -v 2>/dev/null || true
    $COMPOSE -f docker-compose.cluster.yml down -v 2>/dev/null || true
    docker run --rm -v "$(pwd):/app" -w /app alpine sh -c "rm -rf data db1 db2 db3"
}
trap cleanup EXIT
cleanup

wait_for_rsc() {
    local file=$1
    echo "Waiting for replica set to initialize (monitoring rsc container)..."
    for i in {1..60}; do
        if $COMPOSE -f "$file" logs mongo_config | grep -q "Configuration script finished!"; then
            echo "Replica set initialized."
            sleep 5
            return 0
        fi
        sleep 2
    done
    echo "❌ Timeout waiting for initialization."
    $COMPOSE -f "$file" logs
    exit 1
}

echo -e "\n--- Test 1: Single Node Replica Set ---"
$COMPOSE up -d
wait_for_rsc "docker-compose.yml"

echo "Waiting for rs0 to become Primary..."
for i in {1..30}; do
    IS_MASTER=$(docker exec rs0 mongo --port $PORT --quiet --eval 'db.isMaster().ismaster')
    if [ "$IS_MASTER" = "true" ]; then break; fi
    sleep 2
done

echo "Testing write/read on single node..."
docker exec rs0 mongo --port $PORT --quiet --eval 'db.test.insert({msg: "hello single"})' >/dev/null 2>&1

RESULT=$(docker exec rs0 mongo --port $PORT --quiet --eval 'var doc = db.test.findOne(); if(doc) print(doc.msg); else print("null");')

if [[ "$RESULT" == *"hello single"* ]]; then
    echo "✅ Single node write/read successful."
else
    echo "❌ Single node write/read failed. Got: $RESULT"
    exit 1
fi

echo "Cleaning up single node test..."
cleanup

echo -e "\n--- Test 2: 3-Node Cluster Replica Set ---"
$COMPOSE -f docker-compose.cluster.yml up -d
wait_for_rsc "docker-compose.cluster.yml"

echo "Waiting for mongo1 to become Primary..."
for i in {1..30}; do
    IS_MASTER=$(docker exec mongo1 mongo --port 27017 --quiet --eval 'db.isMaster().ismaster')
    if [ "$IS_MASTER" = "true" ]; then break; fi
    sleep 2
done

echo "Testing write to primary and read from secondary (Replication)..."
docker exec mongo1 mongo --port 27017 --quiet --eval 'db.test.insert({msg: "hello cluster"})' >/dev/null 2>&1

# Wait for replication
sleep 3

RESULT=$(docker exec mongo2 mongo --port 27018 --quiet --eval 'rs.secondaryOk(); var doc = db.test.findOne(); if(doc) print(doc.msg); else print("null");')

if [[ "$RESULT" == *"hello cluster"* ]]; then
    echo "✅ Cluster replication successful (Primary -> Secondary)."
else
    echo "❌ Cluster replication failed. Got: $RESULT"
    exit 1
fi

echo -e "\n🎉 All tests passed successfully!"
