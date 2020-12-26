[ -z $RS ] && RS=rs0
[ -z $HOST ] && HOST=127.0.0.1
[ -z $PORT ] && PORT=27017

cat << EOF > config.js
config = {
  _id : "$RS",
  members: [
    { _id: 0, host: "$HOST:$PORT" }
  ]
}

rs_status = db.adminCommand({ replSetGetStatus : 1 }).ok

if (rs_status) rs.reconfig(config, { force: true })
else rs.initiate(config)
EOF

mongo --host $RS --port $PORT config.js
while [ $? != 0 ]
do
  echo "Server seems down retrying"
  sleep 1
  mongo --host $RS --port $PORT config.js
done

if [ ! -z $DB_HOST ] || [ ! -z $USER ] || [ ! -z $PASSWORD ] || [ ! -z $DB ]; then
  mongodump \
  --host $DB_HOST \
  --ssl \
  --username $USER \
  --password $PASSWORD \
  --authenticationDatabase admin \
  --db $DB

  [ ! -z $DBNAME ] && mv dump/$DB dump/$DBNAME
  mongorestore --host $RS dump
fi
