#!/bin/bash

action=$1

if [ "$action" == "image-build" ]; then
    echo "Image build detected. Skipping Hermes agent setup."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --skip-browser --no-skills --dir /hermes/hermes-agent --non-interactive 
else
    echo "Running Hermes agent setup."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --dir /hermes/hermes-agent --skip-setup --non-interactive 
fi





