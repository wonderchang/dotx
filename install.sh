#!/usr/bin/env bash
# install.sh - One-line installer for dotx dotfiles
# Usage: curl -fsSL https://raw.githubusercontent.com/USER/dotx/main/install.sh | bash
# Or with options: curl -fsSL ... | bash -s -- --dry-run vim git

set -e

# Configuration
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/wonderchang/dotx.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotx}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Main installation function
main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  dotx - Dotfiles Installation Script  ║"
    echo "╔════════════════════════════════════════╝"
    echo ""

    # Check prerequisites
    print_info "Checking prerequisites..."

    if ! command_exists git; then
        print_error "git is not installed. Please install git first."
        echo ""
        echo "  macOS:   brew install git  (or install Xcode Command Line Tools)"
        echo "  Ubuntu:  sudo apt-get install git"
        echo ""
        exit 1
    fi
    print_success "git is installed"

    # Clone or update repository
    if [ -d "$DOTFILES_DIR/.git" ]; then
        print_info "Dotfiles directory already exists at: $DOTFILES_DIR"
        print_info "Updating repository..."

        cd "$DOTFILES_DIR"
        git fetch origin "$DOTFILES_BRANCH" > /dev/null 2>&1

        # Check if there are local changes
        if ! git diff-index --quiet HEAD --; then
            print_warning "Local changes detected. Skipping update."
            print_warning "Run 'git pull' manually in $DOTFILES_DIR to update."
        else
            git pull origin "$DOTFILES_BRANCH" > /dev/null 2>&1
            print_success "Repository updated"
        fi
    else
        print_info "Cloning dotfiles repository..."
        print_info "Repository: $DOTFILES_REPO"
        print_info "Directory:  $DOTFILES_DIR"
        print_info "Branch:     $DOTFILES_BRANCH"
        echo ""

        git clone --quiet --branch "$DOTFILES_BRANCH" "$DOTFILES_REPO" "$DOTFILES_DIR"
        print_success "Repository cloned"
    fi

    echo ""
    print_info "Running bootstrap script..."
    echo ""

    # Run bootstrap.sh with any arguments passed to this script
    cd "$DOTFILES_DIR"
    bash bootstrap.sh "$@"

    echo ""
    print_success "Installation complete!"
    echo ""
    print_info "Dotfiles location: $DOTFILES_DIR"

    # Show next steps if bash was installed
    if [[ " $* " =~ " bash " ]] || [[ $# -eq 0 ]]; then
        echo ""
        print_warning "IMPORTANT: If bash shell was installed, restart your terminal for changes to take effect."
    fi

    echo ""
}

# Run main function with all arguments
main "$@"
