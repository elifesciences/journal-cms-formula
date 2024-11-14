#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1
FIRST_PROVISIONED=$2

is_first_provision() {
    [[ ! -f $FIRST_PROVISIONED ]]
}

if [[ $ENVIRONMENT == "ci" || $ENVIRONMENT == "dev" ]]; then
    echo "Environment is ci or dev. Running site-install."
    ../vendor/bin/drush site-install minimal --existing-config -y
    redis-cli flushall
    exit 0
fi
if [[ $ENVIRONMENT == demo* ]] && is_first_provision; then
    echo "Environment is demo* and hasn't been provisioned. Running site-install."
    ../vendor/bin/drush site-install minimal --existing-config -y
    redis-cli flushall
    date > "$FIRST_PROVISIONED"
    exit 0
fi
echo "Skipping site-install (env: $ENVIRONMENT)"
exit 0
