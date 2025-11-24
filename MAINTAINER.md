# Maintainer Guide - AI Training

This guide is for TrustArc CLI maintainers only. It explains how to train and update the AI assistant's knowledge base.

## Overview

The AI assistant uses a pre-built knowledge base that is distributed to users. As a maintainer, you can update this knowledge base by:
1. Adding new documentation files
2. Indexing PDF documentation
3. Running the training script
4. Committing the updated knowledge base to the repository

## Training Script

The training script (`train-ai.sh`) is **NOT** run by end users. Only maintainers use it to build the knowledge base.

### Usage

```bash
# Run the training script
./train-ai.sh
```

The script will:
1. Collect all implementation examples (Swift, Kotlin, TypeScript, Dart, etc.)
2. Process markdown documentation from `training/docs/`
3. Extract text from PDFs in `training/pdfs/`
4. Add FAQ section
5. Generate knowledge base at `lib/knowledge-base.txt`

## Directory Structure

```
trustarc-cli/
├── train-ai.sh              # Training script (maintainers only)
├── training/                 # Training data (not distributed)
│   ├── docs/                # Additional markdown/text docs
│   └── pdfs/                # PDF documentation files
├── lib/
│   ├── knowledge-base.txt   # Generated knowledge base (committed to repo)
│   └── ai.sh                # AI module (downloads knowledge-base.txt)
```

## Adding New Documentation

### Markdown/Text Files

1. Add files to `training/docs/`:
```bash
cp ~/path/to/integration-guide.md training/docs/
cp ~/path/to/api-reference.txt training/docs/
```

2. Run training:
```bash
./train-ai.sh
```

### PDF Files

1. Install PDF extraction tools (if not already installed):

**macOS:**
```bash
brew install poppler
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install poppler-utils
```

**Alternative - Python:**
```bash
pip install PyPDF2
```

2. Add PDFs to `training/pdfs/`:
```bash
cp ~/path/to/sdk-documentation.pdf training/pdfs/
cp ~/path/to/integration-manual.pdf training/pdfs/
```

3. Run training:
```bash
./train-ai.sh
```

## Training Workflow

### Step 1: Prepare Documentation

```bash
# Create training directories (first time only)
mkdir -p training/docs training/pdfs

# Add your documentation
cp /path/to/docs/*.md training/docs/
cp /path/to/pdfs/*.pdf training/pdfs/
```

### Step 2: Run Training

```bash
# Make script executable (first time only)
chmod +x train-ai.sh

# Run training
./train-ai.sh
```

**Output:**
```
╭──────────────────────────────────────────────────────────╮
│         TrustArc AI Training (Maintainer Only)           │
╰──────────────────────────────────────────────────────────╯

[WARN] This script is for maintainers only!
[INFO] It builds the knowledge base that will be distributed to users.

[=>] Building knowledge base...

  • Adding implementation examples...
[OK] Added Swift implementation
[OK] Added Kotlin implementation
[OK] Added TypeScript implementation
[OK] Added Dart implementation
[OK] Added README documentation

  • Checking for additional documentation...
[OK] Added integration-guide.md
[OK] Added troubleshooting.md

[=>] Processing PDF files...
[OK] Found pdftotext
  • Processing sdk-manual.pdf...
[OK] Extracted sdk-manual.pdf
[OK] Processed 2 PDF file(s)

[=>] Adding FAQ section...
[OK] Added FAQ section

────────────────────────────────────────────────────────────

[=>] Knowledge Base Statistics

[INFO] File: /path/to/training/knowledge.txt
  • Size: 1.2M
  • Lines: 15432
  • Words: 234567

[=>] Copying to distribution location...
[OK] Knowledge base ready for distribution: lib/knowledge-base.txt (1.2M)

────────────────────────────────────────────────────────────

[OK] Training completed successfully!

[INFO] Next steps:
  • 1. Review the knowledge base: cat lib/knowledge-base.txt
  • 2. Test with AI: ./install.sh (select AI Assistant)
  • 3. Commit changes: git add lib/knowledge-base.txt && git commit -m 'Update knowledge base'
  • 4. Push to repository so users get the updated knowledge base

[INFO] To add more content:
  • Add documentation to: training/docs
  • Add PDF files to: training/pdfs
  • Run this script again: ./train-ai.sh
```

### Step 3: Test the Knowledge Base

```bash
# Run the CLI
./install.sh

# Select option 3: AI Assistant
# Select option 1: Chat with AI Assistant
# Ask test questions to verify the new content
```

### Step 4: Commit Changes

```bash
# Review the updated knowledge base
git diff lib/knowledge-base.txt

# Commit the changes
git add lib/knowledge-base.txt
git commit -m "Update AI knowledge base with new documentation"

# Push to repository
git push origin main
```

**Important:** After you push, users will automatically get the updates. The knowledge base:
- Auto-syncs from GitHub every time users access the AI Assistant
- Is cached locally at `~/.trustarc-cli/ai/knowledge.txt`
- Falls back to cached version if GitHub is unreachable
- Updates are transparent and instant (only 7.2KB)

## What Gets Distributed

**Distributed to users:**
- `lib/knowledge-base.txt` - Pre-built knowledge base (downloaded from GitHub)
- `lib/ai.sh` - AI module that downloads the knowledge base

**NOT distributed to users:**
- `train-ai.sh` - Training script
- `training/` directory - Source documentation
- `MAINTAINER.md` - This file

## Knowledge Base Contents

The knowledge base automatically includes:

1. **Implementation Examples:**
   - `TrustArcConsentImpl.swift` - iOS implementation
   - `TrustArcConsentImpl.kt` - Android implementation
   - `TrustArcConsentImpl.ts` - React Native TypeScript
   - `TrustArcConsentImpl.js` - React Native JavaScript
   - `TrustArcConsentImpl.dart` - Flutter implementation

2. **Documentation:**
   - `README.md` - Main CLI documentation
   - All files in `training/docs/`

3. **PDF Content:**
   - All PDFs in `training/pdfs/` (text extracted)

4. **FAQ Section:**
   - Common questions and answers
   - Platform requirements
   - Integration steps

## Best Practices

### Documentation Format

- Use clear headings and structure
- Include code examples with syntax
- Add platform-specific notes
- Keep content concise and actionable

### PDF Requirements

- Use text-based PDFs (not scanned images)
- Ensure PDFs have selectable text
- Test extraction quality before committing

### Knowledge Base Size

- Current size: ~1.2MB (reasonable)
- Target: Keep under 5MB for fast downloads
- Large files slow down user setup

### Testing

Before committing:
1. Test AI responses with common questions
2. Verify new content is being used
3. Check for duplicate or outdated information
4. Ensure code examples are correct

## Troubleshooting

### "No PDF extraction tools found"

Install PDF tools:
```bash
# macOS
brew install poppler

# Linux
sudo apt-get install poppler-utils

# Or use Python
pip install PyPDF2
```

### "Failed to extract text from PDF"

The PDF might be:
- Scanned images (OCR required)
- Password protected
- Corrupted

Try opening the PDF and copy-pasting text to verify it's extractable.

### Knowledge base too large

- Remove verbose or redundant documentation
- Compress PDFs before adding
- Focus on essential integration information

## Updating the Training Script

If you need to modify the training process, edit `train-ai.sh`:

```bash
# Example: Add support for a new file format
vim train-ai.sh

# Test changes
./train-ai.sh

# Commit if working
git add train-ai.sh
git commit -m "Update training script"
```

## Security Notes

- Never commit API keys or tokens to knowledge base
- Review generated knowledge base before committing
- Don't include customer-specific information
- Keep internal documentation separate

## Support

For questions about AI training, contact the TrustArc CLI maintainer team.
