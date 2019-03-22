#!/usr/bin/env bash

#
# This file serves as the finishing install script for the test environment.
# The script will be executed in the neos instance root directory.
#

set -e

# Add the oAuth token to git to avoid errors with composer because of https://github.com/composer/composer/issues/1314
if [ -n "$GITHUB_OAUTH_TOKEN" ]; then composer config github-oauth.github.com ${GITHUB_OAUTH_TOKEN}; fi;

# Handle hidden files with the `mv` command.
shopt -s dotglob

cd /data
cp /data/Neos/Build/TravisCi/composer* /data/www/
cd /data/www/
composer install --no-interaction

rm -rf Packages/Application/Neos.Neos.Ui
mv /data/Neos Packages/Application/Neos.Neos.Ui

# Setup the database and import the demo site package.
mysql -e 'create database neos collate utf8mb4_unicode_ci;'
FLOW_CONTEXT=Production ./flow cache:warmup
FLOW_CONTEXT=Production ./flow doctrine:migrate
FLOW_CONTEXT=Production ./flow site:import --package-key=Neos.Demo
FLOW_CONTEXT=Production ./flow resource:publish

# Create the demo backend user.
FLOW_CONTEXT=Production ./flow user:create --username=admin --password=password --first-name=John --last-name=Doe --roles=Administrator &

# Start the development server on which the integration tests will act on.
FLOW_CONTEXT=Production ./flow server:run --port 8081 > /dev/null 2> /dev/null &

# Change into the repository directory where the environment based shell script will be executed.
cd Packages/Application/Neos.Neos.Ui

# Since all environments depend on the node dependencies, install and
# afterwards prune them to remove extranous packages from previous/cached runs.
make install
make build-production

# Deactivate the previous enabled handling of hidden files with the `mv` command.
shopt -u dotglob