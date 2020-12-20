if [ -z $RS ]; then
  echo "ERROR: environment var RS must be set"
  exit 1
fi

[ -z $HOST ] && HOST=127.0.0.1

cat << EOF > config.js
config = {
  _id : "$RS",
  members: [
    { _id: 0, host: "$HOST:27017" }
  ]
}

rs.initiate(config)
EOF

mongo --host $RS config.js
while [ $? != 0 ]
do
  echo "Server seems down retrying"
  sleep 1
  mongo --host $RS config.js
done

if [ ! -z $DB_HOST || ! -z $USER || ! -z $PASSWORD || ! -z $DB ]; then
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
