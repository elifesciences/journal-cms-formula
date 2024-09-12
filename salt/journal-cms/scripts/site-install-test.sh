#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1
FIRST_PROVISIONED=$2

is_first_provision() {
    [[ ! -f $FIRST_PROVISIONED ]]
}

if [[ $ENVIRONMENT == "ci" || $ENVIRONMENT == "dev" ]]; then
    ../vendor/bin/drush site-install minimal --existing-config -y
    exit 0
fi
if [[ $ENVIRONMENT == demo* ]] && is_first_provision; then
    ../vendor/bin/drush site-install minimal --existing-config -y
    date > "$FIRST_PROVISIONED"
    exit 0
fi
exit 0
