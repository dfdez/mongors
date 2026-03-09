#!/bin/sh

# Default variable values if not set
RS=${RS:-rs0}
MONGO_NODES=${MONGO_NODES:-"mongo1:${PORT:-27017},mongo2:${PORT2:-27018},mongo3:${PORT3:-27019}"}

echo "Initializing Replica Set: ${RS} with nodes: ${MONGO_NODES}"

# Generate members JSON array dynamically
MEMBERS=""
ID=0

# Use tr to replace commas with spaces instead of changing IFS
for NODE in $(echo "$MONGO_NODES" | tr ',' ' '); do
  MEMBERS="$MEMBERS,
    { _id: $ID, host: \"$NODE\" }"
  ID=$((ID + 1))
done

# Remove the leading comma and newline
MEMBERS=${MEMBERS#,}

# Prepare the config script to activate the replica set
cat << JS_EOF > config.js
var config = {
  _id: "$RS",
  members: [$MEMBERS]
};

var rs_status = db.adminCommand({ replSetGetStatus: 1 }).ok;

if (rs_status) {
  rs.reconfig(config, { force: true });
} else {
  rs.initiate(config);
}
JS_EOF

# Wait for all nodes to be ready
for NODE in $(echo "$MONGO_NODES" | tr ',' ' '); do
  HOST=$(echo "$NODE" | cut -d: -f1)
  NODE_PORT=$(echo "$NODE" | cut -d: -f2)
  echo "Waiting for MongoDB to be ready on $NODE..."
  while ! mongo --host "$HOST" --port "$NODE_PORT" --eval "db.adminCommand('ping')" > /dev/null 2>&1; do
    echo "Node $NODE seems down or initializing, retrying in 2 seconds..."
    sleep 2
  done
done

# Identify the first node to run the initialization script
FIRST_NODE=$(echo "$MONGO_NODES" | cut -d, -f1)
FIRST_HOST=$(echo "$FIRST_NODE" | cut -d: -f1)
FIRST_PORT=$(echo "$FIRST_NODE" | cut -d: -f2)

# Try to run the script in mongo on the first node and retry in case it fails
echo "Applying Replica Set configuration on $FIRST_NODE..."
while ! mongo --host "$FIRST_HOST" --port "$FIRST_PORT" config.js > /dev/null 2>&1; do
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
  mongorestore --host "$FIRST_HOST" --port "$FIRST_PORT" dump

  echo "Database restoration completed."
fi

echo "Configuration script finished!"
