# Bash profile for login shells
# Sources .bashrc to ensure consistent environment in both login and non-login shells

if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi
