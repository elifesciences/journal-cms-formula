#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1
FIRST_PROVISIONED=$2

is_first_provision() {
    [[ ! -f $FIRST_PROVISIONED ]]
}

if [[ $ENVIRONMENT == "ci" || $ENVIRONMENT == "dev" ]]; then
    echo "Always site-install"
    exit 0
fi
if [[ $ENVIRONMENT == demo* ]] && is_first_provision; then
    echo "always site-install on first provision"
    touch $FIRST_PROVISIONED
    exit 0
fi
exit 0
