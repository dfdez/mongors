# In case any of this variables does not exist set a default value
[ -z $RS ] && RS=rs0
[ -z $HOST ] && HOST=127.0.0.1
[ -z $PORT ] && PORT=27017

echo "Starting replica set initialization"
until mongo --host $RS --port $PORT --eval "print(\"Waited for connection\")"
do
  echo "Server seems down retrying"
  sleep 2
done
echo "Connection finished"

echo "Creating replica set"
# Prepare the config script to active replica set
cat << EOF > config.js
config = {
  _id : "rs0",
  members: [
    { _id: 0, host: "rs0:27017" },
    { _id: 1, host: "rs1:27018" },
    { _id: 2, host: "rs2:27019" }
  ]
}

rs_status = db.adminCommand({ replSetGetStatus : 1 }).ok

if (rs_status) rs.reconfig(config, { force: true })
else rs.initiate(config)
EOF

# Try to run the script in mongo and retry In case mongo still isn't running
mongo --host $RS --port $PORT config.js
echo "Replica set created"

# If $DB_HOST, $USER, $PASSWORD and $DB variables are setted, try to restore this database
if [ ! -z $DB_HOST ] || [ ! -z $USER ] || [ ! -z $PASSWORD ] || [ ! -z $DB ]; then
  mongodump \
  --host $DB_HOST \
  --ssl \
  --username $USER \
  --password $PASSWORD \
  --authenticationDatabase admin \
  --db $DB

  # If $DBNAME variable exist change the name of the database to restore
  [ ! -z $DBNAME ] && mv dump/$DB dump/$DBNAME
  mongorestore --host $RS dump
fi
