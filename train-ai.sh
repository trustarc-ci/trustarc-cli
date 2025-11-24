#!/bin/bash

# TrustArc AI Training Script
# FOR MAINTAINERS ONLY - NOT FOR END USERS
# This script builds the knowledge base that will be distributed to users

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

# Configuration
TRAINING_DIR="$SCRIPT_DIR/training"
DOCS_DIR="$TRAINING_DIR/docs"
PDFS_DIR="$TRAINING_DIR/pdfs"
OUTPUT_KB="$TRAINING_DIR/knowledge.txt"
DIST_KB="$SCRIPT_DIR/lib/knowledge-base.txt"

print_header "TrustArc AI Training (Maintainer Only)"

echo ""
print_warning "This script is for maintainers only!"
print_info "It builds the knowledge base that will be distributed to users."
echo ""

# Create training directories if they don't exist
mkdir -p "$TRAINING_DIR" "$DOCS_DIR" "$PDFS_DIR"

# Initialize knowledge base
print_step "Building knowledge base..."
echo ""

# Clear existing knowledge base
> "$OUTPUT_KB"

# Add TrustArc implementation examples
print_substep "Adding implementation examples..."

if [ -f "$SCRIPT_DIR/TrustArcConsentImpl.swift" ]; then
    echo "=== iOS Swift Implementation ===" >> "$OUTPUT_KB"
    cat "$SCRIPT_DIR/TrustArcConsentImpl.swift" >> "$OUTPUT_KB"
    echo -e "\n" >> "$OUTPUT_KB"
    print_success "Added Swift implementation"
fi

if [ -f "$SCRIPT_DIR/TrustArcConsentImpl.kt" ]; then
    echo "=== Android Kotlin Implementation ===" >> "$OUTPUT_KB"
    cat "$SCRIPT_DIR/TrustArcConsentImpl.kt" >> "$OUTPUT_KB"
    echo -e "\n" >> "$OUTPUT_KB"
    print_success "Added Kotlin implementation"
fi

if [ -f "$SCRIPT_DIR/TrustArcConsentImpl.ts" ]; then
    echo "=== React Native TypeScript Implementation ===" >> "$OUTPUT_KB"
    cat "$SCRIPT_DIR/TrustArcConsentImpl.ts" >> "$OUTPUT_KB"
    echo -e "\n" >> "$OUTPUT_KB"
    print_success "Added TypeScript implementation"
fi

if [ -f "$SCRIPT_DIR/TrustArcConsentImpl.js" ]; then
    echo "=== React Native JavaScript Implementation ===" >> "$OUTPUT_KB"
    cat "$SCRIPT_DIR/TrustArcConsentImpl.js" >> "$OUTPUT_KB"
    echo -e "\n" >> "$OUTPUT_KB"
    print_success "Added JavaScript implementation"
fi

if [ -f "$SCRIPT_DIR/TrustArcConsentImpl.dart" ]; then
    echo "=== Flutter Dart Implementation ===" >> "$OUTPUT_KB"
    cat "$SCRIPT_DIR/TrustArcConsentImpl.dart" >> "$OUTPUT_KB"
    echo -e "\n" >> "$OUTPUT_KB"
    print_success "Added Dart implementation"
fi

# Add README
if [ -f "$SCRIPT_DIR/README.md" ]; then
    echo "=== TrustArc CLI Documentation ===" >> "$OUTPUT_KB"
    cat "$SCRIPT_DIR/README.md" >> "$OUTPUT_KB"
    echo -e "\n" >> "$OUTPUT_KB"
    print_success "Added README documentation"
fi

# Add any markdown files from docs directory
echo ""
print_substep "Checking for additional documentation..."
if [ -d "$DOCS_DIR" ]; then
    doc_count=0
    for doc_file in "$DOCS_DIR"/*.md "$DOCS_DIR"/*.txt; do
        if [ -f "$doc_file" ]; then
            echo "=== Documentation: $(basename "$doc_file") ===" >> "$OUTPUT_KB"
            cat "$doc_file" >> "$OUTPUT_KB"
            echo -e "\n" >> "$OUTPUT_KB"
            print_success "Added $(basename "$doc_file")"
            ((doc_count++))
        fi
    done

    if [ $doc_count -eq 0 ]; then
        print_info "No additional docs found in $DOCS_DIR"
        print_substep "Add .md or .txt files to $DOCS_DIR to include them"
    fi
else
    print_info "No docs directory found. Creating $DOCS_DIR"
    print_substep "Add documentation files here for future training"
fi

# Process PDFs
echo ""
print_step "Processing PDF files..."

# Check for PDF extraction tools
has_pdf_tools=false
if command -v pdftotext >/dev/null 2>&1; then
    print_success "Found pdftotext"
    has_pdf_tools=true
elif command -v python3 >/dev/null 2>&1 && python3 -c "import PyPDF2" 2>/dev/null; then
    print_success "Found Python with PyPDF2"
    has_pdf_tools=true
else
    print_warning "No PDF extraction tools found"
    print_substep "Install 'poppler-utils' or Python 'PyPDF2' to process PDFs"
fi

if [ "$has_pdf_tools" = true ] && [ -d "$PDFS_DIR" ]; then
    pdf_count=0
    for pdf_file in "$PDFS_DIR"/*.pdf; do
        if [ -f "$pdf_file" ]; then
            print_substep "Processing $(basename "$pdf_file")..."

            extracted_text=""

            # Try pdftotext
            if command -v pdftotext >/dev/null 2>&1; then
                extracted_text=$(pdftotext "$pdf_file" - 2>/dev/null || echo "")
            # Try Python PyPDF2
            elif command -v python3 >/dev/null 2>&1; then
                extracted_text=$(python3 -c "
try:
    import PyPDF2
    with open('$pdf_file', 'rb') as f:
        reader = PyPDF2.PdfReader(f)
        text = ''
        for page in reader.pages:
            text += page.extract_text()
        print(text)
except Exception as e:
    print('')
" 2>/dev/null || echo "")
            fi

            if [ -n "$extracted_text" ]; then
                echo "=== PDF: $(basename "$pdf_file") ===" >> "$OUTPUT_KB"
                echo "$extracted_text" >> "$OUTPUT_KB"
                echo -e "\n" >> "$OUTPUT_KB"
                print_success "Extracted $(basename "$pdf_file")"
                ((pdf_count++))
            else
                print_error "Failed to extract text from $(basename "$pdf_file")"
            fi
        fi
    done

    if [ $pdf_count -eq 0 ]; then
        print_info "No PDF files found in $PDFS_DIR"
        print_substep "Add PDF documentation to $PDFS_DIR for training"
    else
        print_success "Processed $pdf_count PDF file(s)"
    fi
else
    print_info "Skipping PDF processing"
    print_substep "Add PDFs to $PDFS_DIR and install extraction tools"
fi

# Add FAQ/Common Questions section
echo ""
print_step "Adding FAQ section..."

cat >> "$OUTPUT_KB" << 'EOF'

=== Frequently Asked Questions ===

Q: How do I initialize the TrustArc SDK?
A: The initialization process varies by platform:
- iOS: Call TrustArcConsentImpl.shared.initialize() in AppDelegate
- Android: Call TrustArcConsentImpl.initialize(this) in Application class
- React Native: Call TrustArcConsentImpl.initialize() in useEffect hook
- Flutter: Call TrustArcConsentImpl.initialize() in main()

Q: How do I show the consent dialog?
A: Use TrustArcConsentImpl.openCm() on all platforms. This displays the consent management interface.

Q: How do I get consent data?
A: Use TrustArcConsentImpl.getConsentData() to retrieve current consent preferences.

Q: What platforms are supported?
A: TrustArc Mobile Consent SDK supports iOS (Swift), Android (Kotlin), React Native (TypeScript/JavaScript), and Flutter (Dart).

Q: What are the minimum requirements?
A:
- iOS: iOS 12.0+, Swift 5.0+
- Android: API 28+, Kotlin
- React Native: Expo or Bare Metal with auto-linking
- Flutter: Flutter 2.0+

EOF

print_success "Added FAQ section"

# Statistics
echo ""
print_divider
echo ""
print_step "Knowledge Base Statistics"
echo ""

kb_size=$(du -h "$OUTPUT_KB" | cut -f1)
kb_lines=$(wc -l < "$OUTPUT_KB")
kb_words=$(wc -w < "$OUTPUT_KB")

print_info "File: $OUTPUT_KB"
print_substep "Size: $kb_size"
print_substep "Lines: $kb_lines"
print_substep "Words: $kb_words"

# Copy to distribution location
echo ""
print_step "Copying to distribution location..."
cp "$OUTPUT_KB" "$DIST_KB"
dist_kb_size=$(du -h "$DIST_KB" | cut -f1)
print_success "Knowledge base ready for distribution: $DIST_KB ($dist_kb_size)"

echo ""
print_divider
echo ""
print_success "Training completed successfully!"
echo ""
print_info "Next steps:"
print_substep "1. Review the knowledge base: cat $DIST_KB"
print_substep "2. Test with AI: ./install.sh (select AI Assistant)"
print_substep "3. Commit changes: git add lib/knowledge-base.txt && git commit -m 'Update knowledge base'"
print_substep "4. Push to repository so users get the updated knowledge base"
echo ""
print_info "To add more content:"
print_substep "• Add documentation to: $DOCS_DIR"
print_substep "• Add PDF files to: $PDFS_DIR"
print_substep "• Run this script again: ./train-ai.sh"
echo ""
