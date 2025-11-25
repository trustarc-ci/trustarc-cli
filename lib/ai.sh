#!/bin/bash

# AI Assistant Module for TrustArc CLI
# Provides local AI assistance using llama.cpp + small language models

# Configuration
AI_DIR="$HOME/.trustarc-cli/ai"
MODEL_DIR="$AI_DIR/models"
BIN_DIR="$AI_DIR/bin"
DOCS_DIR="$AI_DIR/docs"
KNOWLEDGE_BASE="$AI_DIR/knowledge.txt"
PROJECT_CONTEXT="$AI_DIR/project-context.txt"
PROJECT_SCAN_ENABLED="$AI_DIR/.scan-enabled"
REPO_BASE_URL="https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main"

# Model configuration (Llama 3.2 1B Instruct Q4 quantized ~700MB)
MODEL_NAME="Llama-3.2-1B-Instruct-Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf"

# llama.cpp binary URLs
LLAMACPP_VERSION="b4216"
LLAMACPP_MACOS_URL="https://github.com/ggerganov/llama.cpp/releases/download/${LLAMACPP_VERSION}/llama-${LLAMACPP_VERSION}-bin-macos-arm64.zip"
LLAMACPP_LINUX_URL="https://github.com/ggerganov/llama.cpp/releases/download/${LLAMACPP_VERSION}/llama-${LLAMACPP_VERSION}-bin-ubuntu-x64.zip"

# Detect OS and architecture
detect_platform() {
    local os=$(uname -s)
    local arch=$(uname -m)

    case "$os" in
        Darwin*)
            if [[ "$arch" == "arm64" ]]; then
                echo "macos-arm64"
            else
                echo "macos-x64"
            fi
            ;;
        Linux*)
            echo "linux-x64"
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

# Initialize AI directory structure
init_ai_dirs() {
    mkdir -p "$MODEL_DIR" "$BIN_DIR" "$DOCS_DIR"
}

# Download with progress bar
download_with_progress() {
    local url=$1
    local output=$2
    local description=$3

    print_step "Downloading $description..."

    if command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget --show-progress -q "$url" -O "$output"
    else
        print_error "Neither curl nor wget is available"
        return 1
    fi

    return 0
}

# Download and setup llama.cpp
setup_llamacpp() {
    local platform=$(detect_platform)

    if [ "$platform" = "unsupported" ]; then
        print_error "Unsupported platform. AI assistant requires macOS or Linux."
        return 1
    fi

    # Check if already installed
    if [ -f "$BIN_DIR/llama-cli" ]; then
        print_success "llama.cpp already installed"
        return 0
    fi

    print_step "Setting up llama.cpp inference engine..."

    # Determine download URL
    local download_url
    if [[ "$platform" == macos* ]]; then
        download_url="$LLAMACPP_MACOS_URL"
    else
        download_url="$LLAMACPP_LINUX_URL"
    fi

    # Download
    local zip_file="$BIN_DIR/llama.zip"
    if ! download_with_progress "$download_url" "$zip_file" "llama.cpp (~10MB)"; then
        print_error "Failed to download llama.cpp"
        return 1
    fi

    # Extract
    print_substep "Extracting..."
    if ! unzip -q "$zip_file" -d "$BIN_DIR"; then
        print_error "Failed to extract llama.cpp. Is unzip installed?"
        rm -f "$zip_file"
        return 1
    fi

    # Find and move the binary
    find "$BIN_DIR" -name "llama-cli" -o -name "main" | head -1 | while read binary; do
        mv "$binary" "$BIN_DIR/llama-cli"
        chmod +x "$BIN_DIR/llama-cli"
    done

    # Cleanup
    rm -f "$zip_file"
    find "$BIN_DIR" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} \;

    if [ -f "$BIN_DIR/llama-cli" ]; then
        print_success "llama.cpp installed successfully"
        return 0
    else
        print_error "Failed to install llama.cpp binary"
        return 1
    fi
}

# Download AI model
setup_model() {
    local model_path="$MODEL_DIR/$MODEL_NAME"

    # Check if already downloaded
    if [ -f "$model_path" ]; then
        print_success "AI model already downloaded"
        return 0
    fi

    print_step "Downloading AI model (DeepSeek-Coder 1.3B, ~700MB)..."
    print_info "This is a one-time download. Future uses will be instant."
    echo ""

    # Download model
    if ! download_with_progress "$MODEL_URL" "$model_path" "AI model"; then
        print_error "Failed to download AI model"
        rm -f "$model_path"
        return 1
    fi

    print_success "AI model downloaded successfully"
    return 0
}

# Download knowledge base from GitHub (always downloads latest)
download_knowledge_base() {
    print_step "Syncing knowledge base from GitHub..."

    local kb_url="${REPO_BASE_URL}/lib/knowledge-base.txt"
    local temp_kb="$KNOWLEDGE_BASE.tmp"

    # Download knowledge base (always get latest version)
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$kb_url" -o "$temp_kb" 2>/dev/null; then
            mv "$temp_kb" "$KNOWLEDGE_BASE"
        else
            rm -f "$temp_kb"
            # If download fails but cached version exists, use it
            if [ -f "$KNOWLEDGE_BASE" ] && [ -s "$KNOWLEDGE_BASE" ]; then
                print_warning "Failed to download latest, using cached version"
                return 0
            else
                print_error "Failed to download from GitHub"
                return 1
            fi
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q "$kb_url" -O "$temp_kb" 2>/dev/null; then
            mv "$temp_kb" "$KNOWLEDGE_BASE"
        else
            rm -f "$temp_kb"
            # If download fails but cached version exists, use it
            if [ -f "$KNOWLEDGE_BASE" ] && [ -s "$KNOWLEDGE_BASE" ]; then
                print_warning "Failed to download latest, using cached version"
                return 0
            else
                print_error "Failed to download from GitHub"
                return 1
            fi
        fi
    else
        print_error "Neither curl nor wget is available"
        return 1
    fi

    if [ -f "$KNOWLEDGE_BASE" ] && [ -s "$KNOWLEDGE_BASE" ]; then
        local kb_size=$(du -h "$KNOWLEDGE_BASE" | cut -f1)
        print_success "Knowledge base synced ($kb_size)"
        return 0
    else
        print_error "Failed to setup knowledge base"
        return 1
    fi
}

# Update knowledge base (re-download from GitHub)
update_knowledge_base() {
    print_step "Updating knowledge base from GitHub..."

    # Remove existing knowledge base
    rm -f "$KNOWLEDGE_BASE"

    # Download fresh copy
    if download_knowledge_base; then
        print_success "Knowledge base updated successfully"
        return 0
    else
        print_error "Failed to update knowledge base"
        return 1
    fi
}

# Scan project for context
scan_project() {
    local scan_dir=${1:-.}

    print_step "Scanning project for context..."

    # Clear existing project context
    > "$PROJECT_CONTEXT"

    echo "=== Project Context ===" >> "$PROJECT_CONTEXT"
    echo "Scanned from: $scan_dir" >> "$PROJECT_CONTEXT"
    echo "Scanned at: $(date)" >> "$PROJECT_CONTEXT"
    echo "" >> "$PROJECT_CONTEXT"

    local file_count=0

    # Find and scan Swift files (iOS)
    if find "$scan_dir" -name "*.swift" -type f 2>/dev/null | head -1 | grep -q .; then
        echo "=== Swift Files (iOS) ===" >> "$PROJECT_CONTEXT"
        while IFS= read -r file; do
            # Skip Pods and build directories
            if ! echo "$file" | grep -q -E "Pods/|Build/|DerivedData/"; then
                echo "File: $file" >> "$PROJECT_CONTEXT"
                head -100 "$file" >> "$PROJECT_CONTEXT" 2>/dev/null
                echo "" >> "$PROJECT_CONTEXT"
                file_count=$((file_count + 1))
            fi
        done <<EOF
$(find "$scan_dir" -name "*.swift" -type f 2>/dev/null)
EOF
        print_substep "Found Swift files ($file_count)"
    fi

    # Find and scan Kotlin files (Android)
    if find "$scan_dir" -name "*.kt" -type f 2>/dev/null | head -1 | grep -q .; then
        echo "=== Kotlin Files (Android) ===" >> "$PROJECT_CONTEXT"
        local kt_count=0
        while IFS= read -r file; do
            # Skip build directories
            if ! echo "$file" | grep -q -E "build/|.gradle/"; then
                echo "File: $file" >> "$PROJECT_CONTEXT"
                head -100 "$file" >> "$PROJECT_CONTEXT" 2>/dev/null
                echo "" >> "$PROJECT_CONTEXT"
                kt_count=$((kt_count + 1))
            fi
        done <<EOF
$(find "$scan_dir" -name "*.kt" -type f 2>/dev/null)
EOF
        print_substep "Found Kotlin files ($kt_count)"
    fi

    # Find and scan TypeScript/JavaScript files (React Native)
    if find "$scan_dir" \( -name "*.tsx" -o -name "*.ts" -o -name "*.jsx" -o -name "*.js" \) -type f 2>/dev/null | head -1 | grep -q .; then
        echo "=== TypeScript/JavaScript Files (React Native) ===" >> "$PROJECT_CONTEXT"
        local js_count=0
        while IFS= read -r file; do
            # Skip node_modules and build directories
            if ! echo "$file" | grep -q -E "node_modules/|build/|dist/|.expo/"; then
                echo "File: $file" >> "$PROJECT_CONTEXT"
                head -100 "$file" >> "$PROJECT_CONTEXT" 2>/dev/null
                echo "" >> "$PROJECT_CONTEXT"
                js_count=$((js_count + 1))
            fi
        done <<EOF
$(find "$scan_dir" \( -name "*.tsx" -o -name "*.ts" -o -name "*.jsx" -o -name "*.js" \) -type f 2>/dev/null)
EOF
        print_substep "Found TypeScript/JavaScript files ($js_count)"
    fi

    # Find and scan Dart files (Flutter)
    if find "$scan_dir" -name "*.dart" -type f 2>/dev/null | head -1 | grep -q .; then
        echo "=== Dart Files (Flutter) ===" >> "$PROJECT_CONTEXT"
        local dart_count=0
        while IFS= read -r file; do
            # Skip build and generated directories
            if ! echo "$file" | grep -q -E "build/|.dart_tool/|generated/"; then
                echo "File: $file" >> "$PROJECT_CONTEXT"
                head -100 "$file" >> "$PROJECT_CONTEXT" 2>/dev/null
                echo "" >> "$PROJECT_CONTEXT"
                dart_count=$((dart_count + 1))
            fi
        done <<EOF
$(find "$scan_dir" -name "*.dart" -type f 2>/dev/null)
EOF
        print_substep "Found Dart files ($dart_count)"
    fi

    echo "=== End of Project Context ===" >> "$PROJECT_CONTEXT"

    if [ -s "$PROJECT_CONTEXT" ]; then
        local context_size=$(du -h "$PROJECT_CONTEXT" | cut -f1)
        print_success "Project scanned successfully ($context_size)"
        print_substep "Context saved to: $PROJECT_CONTEXT"
        # Enable project scanning
        touch "$PROJECT_SCAN_ENABLED"
        return 0
    else
        print_warning "No relevant project files found"
        return 1
    fi
}

# Check if project scanning is enabled
is_project_scan_enabled() {
    [ -f "$PROJECT_SCAN_ENABLED" ] && [ -f "$PROJECT_CONTEXT" ]
}

# Enable project scanning
enable_project_scan() {
    local scan_dir
    echo ""
    read -p "Enter project directory to scan (default: current directory): " scan_dir
    scan_dir=${scan_dir:-.}

    # Expand ~ to home directory
    scan_dir="${scan_dir/#\~/$HOME}"

    if [ ! -d "$scan_dir" ]; then
        print_error "Directory not found: $scan_dir"
        return 1
    fi

    echo ""
    scan_project "$scan_dir"
}

# Disable project scanning
disable_project_scan() {
    rm -f "$PROJECT_SCAN_ENABLED"
    rm -f "$PROJECT_CONTEXT"
    print_success "Project scanning disabled"
}


# Run AI inference
run_inference() {
    local prompt=$1
    local context=$2
    local model_path="$MODEL_DIR/$MODEL_NAME"
    local llamacpp="$BIN_DIR/llama-cli"

    # Build prompt using Llama 3 chat format
    local system_msg="You are a helpful TrustArc SDK assistant. Answer questions concisely (2-3 sentences max).

The TrustArc SDK has 3 main functions:
- initialize() - Setup the SDK
- openCm() - Show consent dialog
- getConsentData() - Get consent data"

    # Add documentation context
    if [ -n "$context" ]; then
        local limited_context=$(echo "$context" | head -20)
        system_msg="${system_msg}

Reference Documentation:
${limited_context}"
    fi

    # Add project context if enabled
    if is_project_scan_enabled; then
        local project_ctx=$(head -30 "$PROJECT_CONTEXT" 2>/dev/null)
        if [ -n "$project_ctx" ]; then
            system_msg="${system_msg}

User's Project Code:
${project_ctx}"
        fi
    fi

    # Build Llama 3 format prompt
    local full_prompt="<|begin_of_text|><|start_header_id|>system<|end_header_id|>

${system_msg}<|eot_id|><|start_header_id|>user<|end_header_id|>

${prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>

"

    # Run llama.cpp directly (output goes straight to terminal)
    # Redirect stderr to /dev/null to hide all debug output
    "$llamacpp" \
        -m "$model_path" \
        -p "$full_prompt" \
        -n 512 \
        -c 1024 \
        --temp 0.6 \
        --top-p 0.9 \
        --top-k 40 \
        --repeat-penalty 1.1 \
        -t 4 \
        --no-display-prompt \
        2>/dev/null
}

# Search knowledge base for relevant context
search_knowledge_base() {
    local query=$1
    local max_lines=50

    if [ ! -f "$KNOWLEDGE_BASE" ]; then
        echo ""
        return
    fi

    # Convert query to lowercase and search for platform-specific sections
    local query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')
    local context=""

    # Search for platform-specific sections
    if echo "$query_lower" | grep -q -E "ios|swift|xcode|cocoapods|spm"; then
        context=$(sed -n '/=== iOS Integration/,/^===/p' "$KNOWLEDGE_BASE" 2>/dev/null)
    elif echo "$query_lower" | grep -q -E "android|kotlin|gradle"; then
        context=$(sed -n '/=== Android Integration/,/^===/p' "$KNOWLEDGE_BASE" 2>/dev/null)
    elif echo "$query_lower" | grep -q -E "react|native|typescript|javascript|expo"; then
        context=$(sed -n '/=== React Native Integration/,/^===/p' "$KNOWLEDGE_BASE" 2>/dev/null)
    elif echo "$query_lower" | grep -q -E "flutter|dart"; then
        context=$(sed -n '/=== Flutter Integration/,/^===/p' "$KNOWLEDGE_BASE" 2>/dev/null)
    fi

    # If no platform-specific match, search for keywords
    if [ -z "$context" ]; then
        context=$(grep -i -B 2 -A 10 "$query" "$KNOWLEDGE_BASE" 2>/dev/null | head -n $max_lines)
    fi

    # If still no match, return common methods section
    if [ -z "$context" ]; then
        context=$(sed -n '/=== Common SDK Methods/,/^===/p' "$KNOWLEDGE_BASE" 2>/dev/null)
    fi

    echo "$context"
}

# Main AI chat interface
ai_chat() {
    print_header "TrustArc AI Assistant"

    print_info "Ask questions about TrustArc SDK integration"
    print_info "Type 'exit' or 'quit' to return to main menu"
    echo ""

    while true; do
        printf "${CYAN}You:${NC} "
        read -r user_input

        # Check for exit
        if [ "$user_input" = "exit" ] || [ "$user_input" = "quit" ]; then
            print_info "Exiting AI assistant..."
            break
        fi

        # Skip empty input
        if [ -z "$user_input" ]; then
            continue
        fi

        # Search knowledge base for context
        local context=$(search_knowledge_base "$user_input")

        # Run inference
        printf "\n${GREEN}AI:${NC} "
        run_inference "$user_input" "$context"
        echo -e "\n"
    done
}

# Setup AI (download everything if needed)
setup_ai() {
    print_header "AI Assistant Setup"

    # Initialize directories
    init_ai_dirs

    # Check and setup llama.cpp
    if ! setup_llamacpp; then
        return 1
    fi

    # Check and setup model
    if ! setup_model; then
        return 1
    fi

    # Download pre-built knowledge base
    if ! download_knowledge_base; then
        print_warning "Failed to download knowledge base. AI may have limited context."
    fi

    echo ""
    print_success "AI Assistant is ready!"
    echo ""

    return 0
}

# Check if AI is ready
is_ai_ready() {
    [ -f "$BIN_DIR/llama-cli" ] && [ -f "$MODEL_DIR/$MODEL_NAME" ]
}

# Show AI assistant menu
show_ai_menu() {
    if ! is_ai_ready; then
        print_warning "AI Assistant not yet configured"
        echo ""
        read -p "Download and setup AI assistant? (~700MB, one-time) (y/n): " setup_choice

        if [ "$setup_choice" = "y" ] || [ "$setup_choice" = "Y" ]; then
            if ! setup_ai; then
                print_error "AI setup failed"
                return 1
            fi
        else
            print_info "Returning to main menu..."
            return 0
        fi
    else
        # AI is already installed, sync knowledge base
        echo ""
        if ! download_knowledge_base; then
            print_warning "Could not sync knowledge base. AI may have limited context."
        fi
        echo ""
    fi

    # AI submenu
    while true; do
        clear
        print_header "AI Assistant"
        echo ""
        print_info "Ask questions about TrustArc SDK integration"
        print_substep "Knowledge base auto-syncs from GitHub on each load"

        # Show project scan status
        if is_project_scan_enabled; then
            local proj_size=$(du -h "$PROJECT_CONTEXT" | cut -f1)
            print_substep "Project scanning: ENABLED ($proj_size)"
        else
            print_substep "Project scanning: DISABLED"
        fi

        echo ""
        print_menu_option "1" "Chat with AI Assistant"
        print_menu_option "2" "Scan project (enables context-aware answers)"
        print_menu_option "3" "Clear project scan"
        print_menu_option "4" "View AI status"
        print_menu_option "5" "Back to main menu"
        echo ""
        read -p $'\033[0;34mEnter your choice (1-5): \033[0m' ai_choice

        case "$ai_choice" in
            1)
                ai_chat
                ;;
            2)
                enable_project_scan
                echo ""
                read -p "Press enter to continue..."
                ;;
            3)
                echo ""
                disable_project_scan
                echo ""
                read -p "Press enter to continue..."
                ;;
            4)
                show_ai_status
                echo ""
                read -p "Press enter to continue..."
                ;;
            5)
                return 0
                ;;
            *)
                print_error "Invalid choice"
                sleep 1
                ;;
        esac
    done
}

# Show AI status
show_ai_status() {
    clear
    print_header "AI Assistant Status"
    echo ""

    # Check binary
    if [ -f "$BIN_DIR/llama-cli" ]; then
        print_success "Inference engine: Installed"
    else
        print_error "Inference engine: Not installed"
    fi

    # Check model
    if [ -f "$MODEL_DIR/$MODEL_NAME" ]; then
        print_success "AI Model: Downloaded"
        local model_size=$(du -h "$MODEL_DIR/$MODEL_NAME" | cut -f1)
        print_substep "Size: $model_size"
    else
        print_error "AI Model: Not downloaded"
    fi

    # Check knowledge base
    if [ -f "$KNOWLEDGE_BASE" ]; then
        print_success "Knowledge base: Built"
        local kb_size=$(du -h "$KNOWLEDGE_BASE" | cut -f1)
        local kb_lines=$(wc -l < "$KNOWLEDGE_BASE")
        print_substep "Size: $kb_size ($kb_lines lines)"
    else
        print_warning "Knowledge base: Empty"
    fi

    # Check project scan status
    echo ""
    if is_project_scan_enabled; then
        print_success "Project scanning: ENABLED"
        local proj_size=$(du -h "$PROJECT_CONTEXT" | cut -f1)
        local scan_date=$(head -3 "$PROJECT_CONTEXT" | tail -1 | cut -d: -f2-)
        print_substep "Size: $proj_size"
        print_substep "Scanned:$scan_date"
    else
        print_warning "Project scanning: DISABLED"
        print_substep "Enable to get context-aware answers about your code"
    fi

    # Check disk usage
    if [ -d "$AI_DIR" ]; then
        echo ""
        print_info "Total AI directory size: $(du -sh "$AI_DIR" | cut -f1)"
        print_substep "Location: $AI_DIR"
    fi
}

# Quick ask (non-interactive)
ai_ask() {
    local question=$1

    if ! is_ai_ready; then
        print_error "AI Assistant not configured. Run setup first."
        return 1
    fi

    local context=$(search_knowledge_base "$question")
    run_inference "$question" "$context"
}
