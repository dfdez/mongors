#!/bin/sh

# Default variable values if not set
RS=${RS:-rs0}
HOST=${HOST:-127.0.0.1}
PORT=${PORT:-27017}

echo "Initializing Replica Set: ${RS} on ${HOST}:${PORT}"

# Prepare the config script to activate replica set
cat << JS_EOF > config.js
var config = {
  _id: "$RS",
  members: [
    { _id: 0, host: "$HOST:$PORT" }
  ]
};

var rs_status = db.adminCommand({ replSetGetStatus: 1 }).ok;

if (rs_status) {
  rs.reconfig(config, { force: true });
} else {
  rs.initiate(config);
}
JS_EOF

# Try to run the script in mongo and retry in case mongo still isn't running
echo "Waiting for MongoDB to be ready on host $RS:$PORT..."
while ! mongo --host "$RS" --port "$PORT" config.js > /dev/null 2>&1; do
  echo "Server seems down or initializing, retrying in 2 seconds..."
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
  mongorestore --host "$RS" dump

  echo "Database restoration completed."
fi

echo "Configuration script finished!"
