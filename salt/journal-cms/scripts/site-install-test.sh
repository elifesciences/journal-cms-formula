#!/bin/bash
ENVIRONMENT=$1

is_first_provision() {
    return 1
}

if [[ $ENVIRONMENT == "ci" || $ENVIRONMENT == "dev" ]]; then
    echo "Always site-install"
    exit 0
fi
if [[ $ENVIRONMENT == demo* ]] && is_first_provision; then
    echo "always site-install on first provision"
    exit 0
fi
exit 0
