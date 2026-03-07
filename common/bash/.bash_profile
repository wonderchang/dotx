# Bash profile for login shells
# Sources .bashrc to ensure consistent environment in both login and non-login shells

if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi

# Start in Workspace directory for new login shells
if [ "$PWD" = "$HOME" ]; then
    cd "$HOME/Workspace"
fi
