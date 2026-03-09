#!/bin/sh

# Default variable values if not set
RS=${RS:-rs0}
HOST=${HOST:-127.0.0.1}
PORT=${PORT:-27017}
PORT2=${PORT2:-27018}
PORT3=${PORT3:-27019}

echo "Initializing 3-Node Replica Set: ${RS}"

# Prepare the config script to activate the 3-node replica set
cat << JS_EOF > config.js
var config = {
  _id: "$RS",
  members: [
    { _id: 0, host: "mongo1:$PORT" },
    { _id: 1, host: "mongo2:$PORT2" },
    { _id: 2, host: "mongo3:$PORT3" }
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
echo "Waiting for MongoDB to be ready on mongo1:$PORT..."
while ! mongo --host "mongo1" --port "$PORT" --eval "db.adminCommand('ping')" > /dev/null 2>&1; do
  echo "Node mongo1:$PORT seems down or initializing, retrying in 2 seconds..."
  sleep 2
done

echo "Waiting for MongoDB to be ready on mongo2:$PORT2..."
while ! mongo --host "mongo2" --port "$PORT2" --eval "db.adminCommand('ping')" > /dev/null 2>&1; do
  echo "Node mongo2:$PORT2 seems down or initializing, retrying in 2 seconds..."
  sleep 2
done

echo "Waiting for MongoDB to be ready on mongo3:$PORT3..."
while ! mongo --host "mongo3" --port "$PORT3" --eval "db.adminCommand('ping')" > /dev/null 2>&1; do
  echo "Node mongo3:$PORT3 seems down or initializing, retrying in 2 seconds..."
  sleep 2
done

# Try to run the script in mongo on mongo1 and retry in case it fails
echo "Applying Replica Set configuration on mongo1:$PORT..."
while ! mongo --host "mongo1" --port "$PORT" config.js > /dev/null 2>&1; do
  echo "Failed to apply config, retrying in 2 seconds..."
  sleep 2
done

echo "Replica Set initialized successfully."

# If DB_HOST, USER, PASSWORD, and DB variables are set, try to restore this database
if [ -n "$DB_HOST" ] && [ -n "$USER" ] && [ -n "$PASSWORD" ] && [ -n "$DB" ]; then
  echo "Downloading database '$DB' from remote host '$DB_HOST'..."
  mongodump \
    --host "$DB_HOST" \
    --ssl \
    --username "$USER" \
    --password "$PASSWORD" \
    --authenticationDatabase admin \
    --db "$DB"

  # If DBNAME variable exists, change the name of the database to restore
  if [ -n "$DBNAME" ] && [ "$DBNAME" != "$DB" ]; then
    echo "Renaming database dump from '$DB' to '$DBNAME'..."
    mv "dump/$DB" "dump/$DBNAME"
  fi

  echo "Restoring database to local Replica Set..."
  mongorestore --host "mongo1" --port "$PORT" dump

  echo "Database restoration completed."
fi

echo "Configuration script finished!"
