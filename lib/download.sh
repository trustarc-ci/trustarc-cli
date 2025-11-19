#!/bin/bash

# Demo application download helpers

DEMO_REPO_OWNER="trustarc"
DEMO_REPO_NAME="ccm-mobile-consent-test-apps"
DEMO_REPO_URL="https://github.com/${DEMO_REPO_OWNER}/${DEMO_REPO_NAME}.git"

# Clone the demo apps repository into the provided target directory
clone_demo_apps_repo() {
    local target_dir="$1"
    local token="$TRUSTARC_TOKEN"

    if [ -z "$token" ]; then
        print_error "GitHub token missing. Restart the installer and enter your token."
        return 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        print_error "Git is required to download the demo applications."
        return 1
    fi

    echo ""
    print_info "Repository: ${DEMO_REPO_OWNER}/${DEMO_REPO_NAME}"
    print_info "Destination: $target_dir"

    if [ -d "$target_dir" ]; then
        echo ""
        print_warning "Directory already exists: $target_dir"
        read -p "Remove the existing directory and download a fresh copy? (y/n): " replace_choice
        if [ "$replace_choice" != "y" ] && [ "$replace_choice" != "Y" ]; then
            print_info "Keeping existing files."
            return 1
        fi

        print_step "Removing existing directory..."
        rm -rf "$target_dir"
    fi

    local auth_repo="https://${token}@github.com/${DEMO_REPO_OWNER}/${DEMO_REPO_NAME}.git"
    print_step "Cloning demo applications..."
    if git clone "$auth_repo" "$target_dir" >/dev/null 2>&1; then
        print_success "Demo apps repository cloned."
        print_substep "Branch: main"
        return 0
    else
        print_error "Failed to clone ${DEMO_REPO_OWNER}/${DEMO_REPO_NAME}."
        print_info "Ensure your token has repo access and is still valid."
        return 1
    fi
}
