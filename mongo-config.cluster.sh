#!/bin/sh

RS=${RS:-rs0}

echo "Initializing 3-Node Replica Set: ${RS}"

# Prepare the config script to activate the 3-node replica set
cat << JS_EOF > config.js
var config = {
  _id: "$RS",
  members: [
    { _id: 0, host: "mongo1:27017" },
    { _id: 1, host: "mongo2:27018" },
    { _id: 2, host: "mongo3:27019" }
  ]
};

var rs_status = db.adminCommand({ replSetGetStatus: 1 }).ok;

if (rs_status) {
  rs.reconfig(config, { force: true });
} else {
  rs.initiate(config);
}
JS_EOF

# Wait for all nodes to be ready
for host in mongo1:27017 mongo2:27018 mongo3:27019; do
  echo "Waiting for MongoDB to be ready on $host..."
  while ! mongo --host "$host" --eval "db.adminCommand('ping')" > /dev/null 2>&1; do
    echo "Node $host seems down or initializing, retrying in 2 seconds..."
    sleep 2
  done
done

# Initiate on the first node
echo "Applying Replica Set configuration on mongo1..."
mongo --host "mongo1:27017" config.js

echo "Replica Set initialized successfully."
echo "Configuration script finished!"
