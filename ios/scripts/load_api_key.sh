#!/bin/bash

# Script to load Google Maps API Key from local.properties
# This script reads the API key from ios/local.properties and:
# 1. Generates GoogleMapsAPIKey.xcconfig
# 2. Updates Info.plist with the actual API key value
# Run this script before building: ./ios/scripts/load_api_key.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_PROPERTIES="$IOS_DIR/local.properties"
XCCONFIG_FILE="$IOS_DIR/Flutter/GoogleMapsAPIKey.xcconfig"
INFO_PLIST="$IOS_DIR/Runner/Info.plist"

GOOGLE_MAPS_API_KEY=""

if [ -f "$LOCAL_PROPERTIES" ]; then
    # Read GOOGLE_MAPS_API_KEY from local.properties
    while IFS= read -r line; do
        # Skip empty lines and comments
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
            continue
        fi
        
        # Check if line contains GOOGLE_MAPS_API_KEY=
        if [[ "$line" =~ ^GOOGLE_MAPS_API_KEY= ]]; then
            GOOGLE_MAPS_API_KEY="${line#GOOGLE_MAPS_API_KEY=}"
            GOOGLE_MAPS_API_KEY=$(echo "$GOOGLE_MAPS_API_KEY" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            break
        fi
    done < "$LOCAL_PROPERTIES"
fi

# Fallback to environment variable if not found in local.properties
if [ -z "$GOOGLE_MAPS_API_KEY" ]; then
    GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY_ENV:-}"
fi

# Generate xcconfig file
if [ -n "$GOOGLE_MAPS_API_KEY" ]; then
    echo "// Auto-generated from ios/local.properties - DO NOT EDIT MANUALLY" > "$XCCONFIG_FILE"
    echo "GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY" >> "$XCCONFIG_FILE"
    
    # Update Info.plist with the actual API key value
    if [ -f "$INFO_PLIST" ]; then
        # Use sed to replace the GoogleMapsAPIKey value in Info.plist
        # Escape special characters in the API key for sed
        ESCAPED_KEY=$(echo "$GOOGLE_MAPS_API_KEY" | sed 's/[[\.*^$()+?{|]/\\&/g')
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS uses BSD sed
            sed -i '' "s|<string>\$(GOOGLE_MAPS_API_KEY)</string>|<string>$ESCAPED_KEY</string>|g" "$INFO_PLIST"
        else
            # Linux uses GNU sed
            sed -i "s|<string>\$(GOOGLE_MAPS_API_KEY)</string>|<string>$ESCAPED_KEY</string>|g" "$INFO_PLIST"
        fi
    fi
    
    echo "✓ Google Maps API Key loaded from local.properties"
    echo "  - Written to GoogleMapsAPIKey.xcconfig"
    echo "  - Updated Info.plist"
else
    echo "⚠ WARNING: Google Maps API Key not found in ios/local.properties"
    # Create empty file to avoid build errors
    echo "// Google Maps API Key not found - check ios/local.properties" > "$XCCONFIG_FILE"
    echo "GOOGLE_MAPS_API_KEY=" >> "$XCCONFIG_FILE"
fi

