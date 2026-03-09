# MongoDB Replica Set (mongors)

A simple, containerized setup to run a 3-Node MongoDB Replica Set locally using Docker Compose. It also includes an initialization script to automatically clone and restore a remote database on startup.

## Features

- **3-Node Cluster**: Instantly spin up a functional 3-node MongoDB replica set (`rs0` by default).
- **Auto-Restore**: Automatically pull and restore a database from a remote host on startup using `mongodump` and `mongorestore`.
- **Fully Configurable**: Easily override the replica set name, ports, and database credentials using environment variables.

## Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/dfdez/mongors.git
   cd mongors
   ```

2. **Configure Environment Variables (Optional):**
   You can customize your MongoDB setup by creating an `.env` file in the root directory. If no `.env` file is provided, default values are used.

   **Replica Set Configuration:**
   - `RS`: The replica set name (Default: `rs0`)
   - `PORT`: The port for the primary node `mongo1` (Default: `27017`)
   - `PORT2`: The port for secondary node `mongo2` (Default: `27018`)
   - `PORT3`: The port for secondary node `mongo3` (Default: `27019`)

   *(See below for database clone configuration)*

3. **Start the cluster:**
   ```bash
   docker compose up -d
   ```
   
   You can monitor the initialization script to see when the setup is complete:
   ```bash
   docker compose logs -f mongo_config
   ```

## Networking

Because the MongoDB driver will discover the replica set topology using the Docker container names (`mongo1`, `mongo2`, `mongo3`), your host machine must be able to resolve these names to connect to the full replica set properly from outside Docker.

You must add the following line to your host machine's `/etc/hosts` file (or `C:\Windows\System32\drivers\etc\hosts` on Windows):
```text
127.0.0.1 mongo1 mongo2 mongo3
```
After doing this, you can connect from your local machine using:
`mongodb://mongo1:27017,mongo2:27018,mongo3:27019/?replicaSet=rs0`

*(Alternatively, if you skip the hosts file edit, you can connect to the primary directly using `mongodb://127.0.0.1:27017/?directConnection=true`)*

## Automatic Database Clone Configuration

If you want to clone an existing remote database during startup, provide the following variables in your `.env` file:
- `DB_HOST`: The remote host from which to download the database.
- `USER`: The username with access to the remote database.
- `PASSWORD`: The password for the specified user.
- `DB`: The name of the remote database to clone.
- `DBNAME`: *(Optional)* The name to use when restoring the database locally. If not set, it defaults to `$DB`.

## Resetting the Database

If you want to completely wipe your local database data and start fresh:

```bash
# 1. Stop and remove the containers
docker compose down

# 2. Delete the local data folders
sudo rm -rf data/

# 3. Restart the containers
docker compose up -d
```

## Contributing

Feel free to submit an issue or open a pull request if you want to improve this tool or find any bugs.
