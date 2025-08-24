#!/bin/bash

# Script to delete old BitcoinZ wallet data
# Run this to clear all wallet data and start fresh

echo "🗑️  BitcoinZ Wallet Data Cleanup Script"
echo "========================================"
echo ""

# Function to delete directory if it exists
delete_if_exists() {
    if [ -d "$1" ]; then
        echo "✅ Found: $1"
        rm -rf "$1"
        echo "   ➜ Deleted"
    else
        echo "❌ Not found: $1"
    fi
}

# Function to delete file if it exists
delete_file_if_exists() {
    if [ -f "$1" ]; then
        echo "✅ Found file: $1"
        rm -f "$1"
        echo "   ➜ Deleted"
    else
        echo "❌ File not found: $1"
    fi
}

echo "1️⃣  Checking for BitcoinZ Blue wallet data..."
delete_if_exists "$HOME/Library/Application Support/bitcoinz-blue-wallet-data"

echo ""
echo "2️⃣  Checking for BitcoinZ Black Amber wallet data..."
delete_if_exists "$HOME/Library/Application Support/BitcoinZ Black Amber"
delete_if_exists "$HOME/Library/Application Support/com.bitcoinz.blackamber"

echo ""
echo "3️⃣  Checking for Zecwallet Lightclient data (default Rust location)..."
delete_if_exists "$HOME/Library/Application Support/Zecwallet Lightclient"

echo ""
echo "4️⃣  Checking for test/debug wallet data..."
delete_if_exists "$HOME/Library/Application Support/bitcoinz-mobile-wallet"
delete_if_exists "$HOME/Library/Application Support/bitcoinz_wallet"

echo ""
echo "5️⃣  Checking for Flutter app cache..."
delete_if_exists "$HOME/Library/Caches/com.bitcoinz.blackamber"
delete_if_exists "$HOME/Library/Caches/bitcoinz_black_amber"

echo ""
echo "6️⃣  Checking for database files..."
delete_file_if_exists "$HOME/Documents/bitcoinz_wallet.db"
delete_file_if_exists "$HOME/Library/Application Support/bitcoinz_wallet.db"

echo ""
echo "7️⃣  Checking for preferences..."
# macOS preferences
if [ -f "$HOME/Library/Preferences/com.bitcoinz.blackamber.plist" ]; then
    echo "✅ Found preferences: com.bitcoinz.blackamber.plist"
    defaults delete com.bitcoinz.blackamber 2>/dev/null
    echo "   ➜ Deleted"
else
    echo "❌ No preferences found"
fi

echo ""
echo "8️⃣  Checking project's local wallet data..."
# Check in the Flutter app directory
FLUTTER_APP_DIR="$(dirname "$0")"
delete_if_exists "$FLUTTER_APP_DIR/wallet"
delete_if_exists "$FLUTTER_APP_DIR/wallet_data"
delete_file_if_exists "$FLUTTER_APP_DIR/wallet.dat"

echo ""
echo "============================================"
echo "✨ Wallet data cleanup complete!"
echo ""
echo "Next steps:"
echo "1. Run 'flutter clean' to clear Flutter cache"
echo "2. Run 'flutter pub get' to restore dependencies"
echo "3. Run the app to create a fresh wallet"
echo ""
echo "⚠️  Note: All wallet data has been deleted."
echo "    You'll need to create a new wallet or"
echo "    restore from your seed phrase."