#!/bin/bash
ENVIRONMENT=$1
if [[ $ENVIRONMENT == "ci" || $ENVIRONMENT == "dev" ]]; then
    echo "Always site-install" 
    exit 0
fi
# if starts with demo and first previsioned
#     echo "always site-install"
#     exit 0
# fi
exit 0 
