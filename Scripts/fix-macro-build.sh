#!/usr/bin/env bash
# Fix Swift macro / SPM prebuilts compiler version mismatch.
# Run when you see: "Compiled module was created by a different version of the compiler"
# or "Unable to find module dependency: 'SwiftDiagnostics'"

set -e
echo "Disabling SPM prebuilts (force build from source with current compiler)..."
defaults write com.apple.dt.Xcode IDEPackageEnablePrebuilts NO 2>/dev/null || true

echo "Removing Utouto DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Utouto-*

echo "Removing local .build if present..."
rm -rf .build

echo "Done. Next steps:"
echo "  1. Open Xcode and open this project"
echo "  2. File → Packages → Reset Package Caches"
echo "  3. File → Packages → Resolve Package Versions"
echo "  4. Product → Clean Build Folder"
echo "  5. Build (⌘B)"
