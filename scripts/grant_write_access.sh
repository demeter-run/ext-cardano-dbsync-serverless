#!/bin/bash
export PGSSLMODE=disable
export PG_SUPERUSER=postgres
export PGPASSWORD=""
export PG_NEW_USER=""
export PG_NEW_USER_PASSWORD=""
export PGHOST=localhost
export PGPORT=5432

# Check if all required environment variables are set
if [ -z "$PG_SUPERUSER" ] || [ -z "$PGPASSWORD" ] || [ -z "$PG_NEW_USER" ] || [ -z "$PG_NEW_USER_PASSWORD" ] || [ -z "$PGHOST" ] || [ -z "$PGPORT" ]; then
    echo "One or more required environment variables are not set."
    echo "Make sure PG_SUPERUSER, PGPASSWORD, PG_NEW_USER, PG_NEW_USER_PASSWORD, PGHOST, and PGPORT are set before running this script."
    exit 1
fi

# Target databases
databases=("dbsync-mainnet" "dbsync-preview" "dbsync-preprod")

# Create the new user
echo "Creating user: $PG_NEW_USER"
psql -h "$PGHOST" -p "$PGPORT" -U "$PG_SUPERUSER" -c "CREATE USER \"$PG_NEW_USER\" WITH LOGIN PASSWORD '$PG_NEW_USER_PASSWORD';"

# Loop through each database to grant permissions
for db in "${databases[@]}"; do
    echo "Granting permissions on database: $db"
    
    # Grant CONNECT on database and CREATE on the database to allow schema creation
    psql -h "$PGHOST" -p "$PGPORT" -U "$PG_SUPERUSER" -d "$db" -c "GRANT CONNECT, CREATE ON DATABASE \"$db\" TO \"$PG_NEW_USER\";"
    
    # Grant USAGE and CREATE on the 'public' schema to allow view creation and using the schema
    psql -h "$PGHOST" -p "$PGPORT" -U "$PG_SUPERUSER" -d "$db" -c "GRANT USAGE, CREATE ON SCHEMA public TO \"$PG_NEW_USER\";"
    
    # Grant SELECT on all tables in the 'public' schema
    psql -h "$PGHOST" -p "$PGPORT" -U "$PG_SUPERUSER" -d "$db" -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"$PG_NEW_USER\";"
    
    # Ensure future tables and views in the 'public' schema also grant SELECT to the user
    psql -h "$PGHOST" -p "$PGPORT" -U "$PG_SUPERUSER" -d "$db" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO \"$PG_NEW_USER\";"
done

echo "Permissions granted and user created successfully."
