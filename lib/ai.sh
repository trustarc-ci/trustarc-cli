#!/bin/bash

# AI Assistant Module for TrustArc CLI
# Provides local AI assistance using llama.cpp + small language models

# Configuration
AI_DIR="$HOME/.trustarc-cli/ai"
MODEL_DIR="$AI_DIR/models"
BIN_DIR="$AI_DIR/bin"
DOCS_DIR="$AI_DIR/docs"
KNOWLEDGE_BASE="$AI_DIR/knowledge.txt"
REPO_BASE_URL="https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main"

# Model configuration (DeepSeek-Coder 1.3B Q4 quantized ~700MB)
MODEL_NAME="deepseek-coder-1.3b-instruct.Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/TheBloke/deepseek-coder-1.3b-instruct-GGUF/resolve/main/deepseek-coder-1.3b-instruct.Q4_K_M.gguf"

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

# Download knowledge base from GitHub
download_knowledge_base() {
    # Check if knowledge base already exists
    if [ -f "$KNOWLEDGE_BASE" ] && [ -s "$KNOWLEDGE_BASE" ]; then
        print_success "Knowledge base already exists (cached)"
        return 0
    fi

    print_step "Downloading knowledge base from GitHub..."

    local kb_url="${REPO_BASE_URL}/lib/knowledge-base.txt"
    local temp_kb="$KNOWLEDGE_BASE.tmp"

    # Download knowledge base
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$kb_url" -o "$temp_kb" 2>/dev/null; then
            mv "$temp_kb" "$KNOWLEDGE_BASE"
        else
            rm -f "$temp_kb"
            print_error "Failed to download from GitHub"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q "$kb_url" -O "$temp_kb" 2>/dev/null; then
            mv "$temp_kb" "$KNOWLEDGE_BASE"
        else
            rm -f "$temp_kb"
            print_error "Failed to download from GitHub"
            return 1
        fi
    else
        print_error "Neither curl nor wget is available"
        return 1
    fi

    if [ -f "$KNOWLEDGE_BASE" ] && [ -s "$KNOWLEDGE_BASE" ]; then
        local kb_size=$(du -h "$KNOWLEDGE_BASE" | cut -f1)
        print_success "Knowledge base downloaded and cached ($kb_size)"
        print_substep "Saved to: $KNOWLEDGE_BASE"
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


# Run AI inference
run_inference() {
    local prompt=$1
    local context=$2
    local model_path="$MODEL_DIR/$MODEL_NAME"
    local llamacpp="$BIN_DIR/llama-cli"

    # Build system prompt
    local system_prompt="You are an AI assistant specialized in TrustArc Mobile Consent SDK integration. You help developers integrate the SDK into iOS, Android, React Native, and Flutter applications. Be concise and provide code examples when relevant."

    # Add context if available
    if [ -n "$context" ]; then
        system_prompt="$system_prompt\n\nContext from documentation:\n$context"
    fi

    # Run inference
    local full_prompt="<|system|>
${system_prompt}
<|user|>
${prompt}
<|assistant|>"

    # Run llama.cpp with parameters optimized for speed
    "$llamacpp" \
        -m "$model_path" \
        -p "$full_prompt" \
        -n 512 \
        -c 2048 \
        --temp 0.7 \
        --top-p 0.9 \
        --repeat-penalty 1.1 \
        -t 4 \
        --no-display-prompt \
        2>/dev/null
}

# Search knowledge base for relevant context
search_knowledge_base() {
    local query=$1
    local max_lines=100

    if [ ! -f "$KNOWLEDGE_BASE" ]; then
        echo ""
        return
    fi

    # Simple keyword-based search (grep for query terms)
    local results=$(grep -i -C 5 "$query" "$KNOWLEDGE_BASE" 2>/dev/null | head -n $max_lines)

    echo "$results"
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
    fi

    # AI submenu
    while true; do
        clear
        print_header "AI Assistant"
        echo ""
        print_info "Ask questions about TrustArc SDK integration"
        print_substep "Trained on iOS, Android, React Native, and Flutter examples"
        echo ""
        print_menu_option "1" "Chat with AI Assistant"
        print_menu_option "2" "Update knowledge base"
        print_menu_option "3" "View AI status"
        print_menu_option "4" "Back to main menu"
        echo ""
        read -p $'\033[0;34mEnter your choice (1-4): \033[0m' ai_choice

        case "$ai_choice" in
            1)
                ai_chat
                ;;
            2)
                echo ""
                update_knowledge_base
                echo ""
                read -p "Press enter to continue..."
                ;;
            3)
                show_ai_status
                echo ""
                read -p "Press enter to continue..."
                ;;
            4)
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
