
action=$1 # 'image-build'

if [ "$action" == "image-build" ]; then
    echo "Image build detected. Skipping OpenClaw agent setup."
    curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-prompt --install-method npm --no-onboard; \
else
    echo "Try running:"
    echo "openclaw onboard"

fi

