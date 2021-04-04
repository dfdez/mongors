## Documentation
A simple docker-compose file to run a mongodb database in docker with replica set on.

You can add a `.env` file to custom the replica set configuration:
- `$RS` -> The replicas set name (Default: rs0)
- `$HOST` -> The replica set host (Default: 127.0.0.1)
- `$PORT` -> Teh replica set port (Default: 27017)

Also you can `download` and `restore` any database by adding this variables:
- `$DB_HOST` -> Host where download the database
- `$USER` -> A username who has access to the database
- `$PASSWORD` -> The password of the given $USER
- `$DB` -> The name of the database that we want to clone
- `$DBNAME` -> To change the name of the database to restore
