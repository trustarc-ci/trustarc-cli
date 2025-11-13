#!/bin/bash

# TrustArc SDK Diagnostic Functions
# This file contains project diagnostic and Q&A functions

# Download diagnostic Python scripts if needed
download_diagnostic_scripts() {
    local repo_base="https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main"

    # Create temp directory if it doesn't exist
    if [ -z "$TMP_LIB_DIR" ]; then
        TMP_LIB_DIR="/tmp/trustarc-cli-lib-$$"
    fi
    mkdir -p "$TMP_LIB_DIR"

    # Download diagnose.py
    if [ ! -f "$TMP_LIB_DIR/diagnose.py" ]; then
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$repo_base/lib/diagnose.py" -o "$TMP_LIB_DIR/diagnose.py" 2>/dev/null
        elif command -v wget >/dev/null 2>&1; then
            wget -q "$repo_base/lib/diagnose.py" -O "$TMP_LIB_DIR/diagnose.py" 2>/dev/null
        fi
        chmod +x "$TMP_LIB_DIR/diagnose.py"
    fi

    # Download diagnose_qa.py
    if [ ! -f "$TMP_LIB_DIR/diagnose_qa.py" ]; then
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$repo_base/lib/diagnose_qa.py" -o "$TMP_LIB_DIR/diagnose_qa.py" 2>/dev/null
        elif command -v wget >/dev/null 2>&1; then
            wget -q "$repo_base/lib/diagnose_qa.py" -O "$TMP_LIB_DIR/diagnose_qa.py" 2>/dev/null
        fi
        chmod +x "$TMP_LIB_DIR/diagnose_qa.py"
    fi
}

# Run diagnostic on project
run_diagnostic() {
    local project_path=$1

    print_header "TrustArc SDK Diagnostic"

    # Check if Python 3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        print_error "Python 3 is required for diagnostic feature"
        print_info "Please install Python 3 and try again"
        return 1
    fi

    # Get the directory of the script
    local script_dir=""
    if [ -f "$(dirname "$0")/lib/diagnose.py" ]; then
        script_dir="$(dirname "$0")/lib"
    elif [ -f "$TMP_LIB_DIR/diagnose.py" ]; then
        script_dir="$TMP_LIB_DIR"
    else
        # Download scripts if not found
        print_info "Downloading diagnostic scripts..."
        download_diagnostic_scripts
        if [ -f "$TMP_LIB_DIR/diagnose.py" ]; then
            script_dir="$TMP_LIB_DIR"
        else
            print_error "Failed to download diagnostic scripts"
            return 1
        fi
    fi

    print_info "Analyzing project at: $project_path"
    echo ""

    # Run diagnostic
    local report_file="/tmp/trustarc-diagnostic-$$.json"

    if python3 "$script_dir/diagnose.py" "$project_path" --json > "$report_file" 2>&1; then
        # Show text report
        python3 "$script_dir/diagnose.py" "$project_path"

        echo ""
        echo ""
        read -p "Would you like to ask questions about the results? (y/n): " ask_questions

        if [ "$ask_questions" = "y" ] || [ "$ask_questions" = "Y" ]; then
            echo ""
            python3 "$script_dir/diagnose_qa.py" "$report_file"
        fi
    else
        # Show text report even on error
        python3 "$script_dir/diagnose.py" "$project_path"

        echo ""
        echo ""
        read -p "Would you like to ask questions about SDK integration? (y/n): " ask_questions

        if [ "$ask_questions" = "y" ] || [ "$ask_questions" = "Y" ]; then
            echo ""
            python3 "$script_dir/diagnose_qa.py"
        fi
    fi

    # Cleanup
    rm -f "$report_file"
}

# Diagnose project menu
diagnose_project_menu() {
    print_header "Diagnose Project"

    echo "This tool will analyze your project and check for:"
    echo ""
    print_substep "TrustArc SDK installation"
    print_substep "Proper initialization patterns"
    print_substep "Required permissions and configurations"
    print_substep "Common integration issues"
    echo ""

    # Ask for project location
    read -p "Enter project path (Press Enter for current directory): " project_path
    project_path=${project_path:-.}

    # Expand ~ to home directory if present
    project_path="${project_path/#\~/$HOME}"

    # Check if directory exists
    if [ ! -d "$project_path" ]; then
        print_error "Directory does not exist: $project_path"
        echo ""
        read -p "Press enter to return to main menu..."
        show_main_menu
        return
    fi

    echo ""
    run_diagnostic "$project_path"

    echo ""
    read -p "Press enter to return to main menu..."
    show_main_menu
}
