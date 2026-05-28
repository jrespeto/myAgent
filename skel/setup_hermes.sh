# If image setup 

action=$1

if [ "$action" == "image-build" ]; then
    echo "Image build detected. Skipping Hermes agent setup."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --no-venv --dir /hermes/hermes-agent
else
    echo "Running Hermes agent setup."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --dir /hermes/hermes-agent
fi





