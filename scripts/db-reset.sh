#!/bin/bash

#
#  RedwoodJS
#
#  @description
#
#   This is a companion bash script to RedwoodJS that will;
#
#   - Check if 'psql' is installed locally
#   - Check that we are in the root of a RedwoodJS project
#   - Check if .env is present and load in it's environment variables
#   - Load in the environment variables from .env
#   - Delete directory api/prisma/migrations
#   - Parse database credentials based of DATABASE_URL and display the output
#   - <Press a key to continue>
#   - Delete all tables in database
#   - Save database schema (yarn rw db save)
#   - Bring up the database schema (yarn rw db up)
#   - Seed the database (yarn rw db seed)
#
#  @requirements
#
#   - Running a linux shell one way or another
#   - Postgres client (psql) is installed locally
#   - .env is present in the root directory with DATABASE_URL defined
#
#  @notes
#
#   - Most commands redirect stdout to /dev/null and display stderr's (errors)
#   - Parsing of database credentials is hacky. Only run this on local development.
#   - Finally, don't specify a port in the DATABASE_URL
#
#  @usage
#
#   1. Create script in root directory
#   2. Invoke it with e.g.
#      $ /bin/bash ./db-reset.sh
#
#

# Check if psql is installed locally
if [ ! command -v psql &> /dev/null ]; then
    echo "Postgres client 'psql' was not installed on your machine. "
    exit
fi

# Check if we are in the root directory by looking for the api/prisma directory
# A better way would be to check if @redwoodjs/core exist in package.json?
echo -n "- Checking that we are in the root directory..."
if [ ! -d "./api/prisma" ]; then
    echo -e "fail\n"
    echo "Invalid run. Are you sure you are running this from the root directory?"
    echo "Current path: $(pwd)"

    exit
fi
echo "done"

# Check if .env present
echo -n "- Checking that .env file is present..."
if ! test -f "./.env"; then
    echo "fail"
    exit
fi
echo "done"

# Load the env
. ./.env > /dev/null

# Recursively remove prisma migrations
echo -n "- Deleting api/prisma/migrations..."
rm -rf ./api/prisma/migrations && echo "done" || (echo "fail" && exit)

# Parse database credentials
echo "- Parsing database credentials from DATABASE_URL..."
DB_HOSTNAME=$(echo $DATABASE_URL | cut -d '@' -f2 | cut -d '/' -f1)
DB_NAME=$(echo $DATABASE_URL | cut -d '/' -f4)
DB_USERNAME=$(echo $DATABASE_URL | cut -d '/' -f3 | cut -d ':' -f1)
DB_PASSWORD=$(echo $DATABASE_URL | cut -d '/' -f3 | cut -d ':' -f2 | cut -d '@' -f1)

echo
echo "DB_HOSTNAME   $DB_HOSTNAME"
echo "DB_NAME       $DB_NAME"
echo "DB_USERNAME   $DB_USERNAME"
echo "DB_PASSWORD   $DB_PASSWORD"
echo

# Drop all tables
# @todo: Do something cool here
read -p "- !! Verify that these database credentials are correct and then press any key..."
echo

echo -n "- Setting database password to environment variable (PGPASSWORD)..."
export PGPASSWORD=$DB_PASSWORD && echo "done" || (echo "fail" && exit)

echo -n "- Deleting all tables in schema '${DB_NAME}'..."
# https://stackoverflow.com/a/13033467
(psql --host $DB_HOSTNAME -U $DB_USERNAME $DB_NAME -t -c "select 'drop table \"' || tablename || '\" cascade;' from pg_tables where schemaname = 'public'"  | psql --host $DB_HOSTNAME -U $DB_USERNAME $DB_NAME)  2>&1 > /dev/null && echo "done" || (echo "fail" && exit)

# Save database schema
echo -n "- Saving database schema (yarn rw db save)..."
yarn rw db save 2>&1 > /dev/null && echo "done" || (echo "fail" && exit)

# Bring up new database schema
echo -n "- Bringing up database schema (yarn rw db up)..."
yarn rw db up 2>&1 > /dev/null && echo "done" || (echo "fail" && exit)

# Seed the database
echo -n "- Seeding the database (yarn rw db seed)..."
yarn rw db seed 2>&1 > /dev/null && echo "done" || (echo "fail" && exit)
