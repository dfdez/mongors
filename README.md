# Documentation
A simple docker-compose file to run a mongodb database in docker with replica set on.
## How to run mongodb with replicaset in docker:
You will need to install [docker]('https://www.docker.com/products/docker-desktop') and [docker-compose]('https://docs.docker.com/compose/install/')

```zsh
git clone https://github.com/dfdez/mongors.git

cd mongors
```
Before running the containers you can add the `.env` file where you can:
- Change de default configuration with this variables:
  - `$RS` -> The replicas set name (Default: rs0)
  - `$HOST` -> The replica set host (Default: 127.0.0.1)
  - `$PORT` -> Teh replica set port (Default: 27017)
- Add configuration to automatic clone a database with this variables:
  - `$DB_HOST` -> Host where download the database
  - `$USER` -> A username who has access to the database
  - `$PASSWORD` -> The password of the given $USER
  - `$DB` -> The name of the database that we want to clone
  - `$DBNAME` -> To change the name of the database to restore

Once you have all the env variables configured you can run the containers with:
```zsh
docker-compose up -d

# You can see what the script is doing by running:
docker-compose logs -f
```
Just wait until the script finish the configuration and you are ready to go!

## If you want to reset your database:
```zsh
# Stop the container
docker-compose stop

# Delete the folder with the database information
rm -r data

# Rerun the container
docker-compose restart
```