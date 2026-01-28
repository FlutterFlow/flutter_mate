#!/bin/bash

# Ensure we have curl in PATH
export PATH="/usr/bin:/bin:/usr/local/bin:$PATH"

# Script to run a Flutter web project and download all generated JS files
# Usage: ./download_flutter_web_js.sh <project_dir> [port]
#
# JS files will be saved to <project_dir>/build_js/
#
# Example:
#   ./download_flutter_web_js.sh /tmp/flutter_debug_dummy 8083
#   ./download_flutter_web_js.sh /path/to/real_project 8084

PROJECT_DIR="$1"
PORT="${2:-8083}"

if [ -z "$PROJECT_DIR" ]; then
    echo "Usage: $0 <project_dir> [port]"
    echo ""
    echo "JS files will be saved to <project_dir>/build_js/"
    echo ""
    echo "Example:"
    echo "  $0 /tmp/flutter_debug_dummy 8083"
    echo "  $0 /path/to/real_project 8084"
    exit 1
fi

# Convert to absolute path
PROJECT_DIR=$(cd "$PROJECT_DIR" 2>/dev/null && pwd)
if [ -z "$PROJECT_DIR" ] || [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Project directory does not exist: $1"
    exit 1
fi

OUTPUT_DIR="$PROJECT_DIR/build_js"

# Create output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "=== Starting Flutter web server ==="
echo "Project: $PROJECT_DIR"
echo "Output: $OUTPUT_DIR"
echo "Port: $PORT"

# Start Flutter web server in background
cd "$PROJECT_DIR"
flutter run -d web-server --web-port=$PORT > /tmp/flutter_web_server_$PORT.log 2>&1 &
FLUTTER_PID=$!

echo "Flutter PID: $FLUTTER_PID"
echo "Waiting for server to start..."

# Wait for server to be ready
MAX_WAIT=120
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -s "http://localhost:$PORT/" > /dev/null 2>&1; then
        echo "Server is ready!"
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
    echo "  Waiting... ($WAITED seconds)"
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "Error: Server did not start within $MAX_WAIT seconds"
    echo "Log:"
    cat /tmp/flutter_web_server_$PORT.log
    kill $FLUTTER_PID 2>/dev/null
    exit 1
fi

# Trigger full compilation by requesting all bootstrap files
echo "Triggering compilation..."

# Request the bootstrap chain to trigger compilation
curl -s "http://localhost:$PORT/" > /dev/null
curl -s "http://localhost:$PORT/flutter_bootstrap.js" > /dev/null
curl -s "http://localhost:$PORT/main.dart.js" > /dev/null
curl -s "http://localhost:$PORT/dart_sdk.js" > /dev/null
curl -s "http://localhost:$PORT/main_module.bootstrap.js" > /dev/null

# Wait for main.dart.js
COMPILE_WAIT=0
while [ $COMPILE_WAIT -lt 60 ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/main.dart.js")
    if [ "$HTTP_CODE" = "200" ]; then
        echo "main.dart.js ready"
        break
    fi
    sleep 2
    COMPILE_WAIT=$((COMPILE_WAIT + 2))
done

# Now request the signature file to trigger its compilation
TEST_FILE="packages/flutter/src/cupertino/text_form_field_row.dart.lib.js"
echo "Requesting signature file to trigger compilation..."
curl -s "http://localhost:$PORT/$TEST_FILE" > /dev/null &
CURL_PID=$!

# Wait for package with timeout
PACKAGE_WAIT=0
while [ $PACKAGE_WAIT -lt 90 ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/$TEST_FILE")
    if [ "$HTTP_CODE" = "200" ]; then
        echo "Flutter packages ready! (${PACKAGE_WAIT}s)"
        break
    fi
    sleep 3
    PACKAGE_WAIT=$((PACKAGE_WAIT + 3))
    echo "  Compiling... ($PACKAGE_WAIT seconds)"
done

kill $CURL_PID 2>/dev/null

if [ "$HTTP_CODE" != "200" ]; then
    echo "Warning: Signature file not available (status: $HTTP_CODE)"
    echo "Proceeding anyway - some files may be missing"
fi

sleep 1

echo ""
echo "=== Discovering available files ==="

# Download main.dart.js and look for module paths
curl -s "http://localhost:$PORT/main.dart.js" > "$OUTPUT_DIR/main.dart.js"
echo "main.dart.js size: $(wc -c < "$OUTPUT_DIR/main.dart.js" | tr -d ' ') bytes"

# Check main_module.bootstrap.js for the module list
curl -s "http://localhost:$PORT/main_module.bootstrap.js" > "$OUTPUT_DIR/main_module.bootstrap.js" 2>/dev/null
if [ -s "$OUTPUT_DIR/main_module.bootstrap.js" ]; then
    echo "Found main_module.bootstrap.js"
    # Extract module paths from bootstrap
    grep -o '"src": "[^"]*"' "$OUTPUT_DIR/main_module.bootstrap.js" | head -20
fi

# Try some test URLs to figure out the structure
echo ""
echo "Testing URL patterns..."
for pattern in \
    "packages/flutter/foundation.dart.lib.js" \
    "packages/flutter/foundation.dart.js" \
    "packages/flutter_foundation.dart.lib.js" \
    "dart_sdk.js" \
    "flutter_bootstrap.js"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/$pattern")
    echo "  $HTTP_CODE - $pattern"
done

echo ""
echo "=== Downloading JS files ==="

# Extract module list from bootstrap file and download Flutter packages
echo "Extracting module list from bootstrap..."
grep -o '"src": "[^"]*"' "$OUTPUT_DIR/main_module.bootstrap.js" | \
    sed 's/"src": "//; s/"$//' | \
    grep "^packages/flutter" > "$OUTPUT_DIR/flutter_modules.txt"

echo "Found $(wc -l < "$OUTPUT_DIR/flutter_modules.txt" | tr -d ' ') Flutter modules"
cat "$OUTPUT_DIR/flutter_modules.txt"

# Also check for key signature files
SIGNATURE_FILES=(
    "packages/flutter/src/cupertino/text_form_field_row.dart.lib.js"
    "packages/flutter/src/widgets/widget_preview.dart.lib.js"
    "packages/flutter/src/widget_previews/widget_previews.dart.lib.js"
)

echo ""
echo "=== Checking signature files ==="
for sig in "${SIGNATURE_FILES[@]}"; do
    HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:$PORT/$sig")
    if [ "$HTTP_CODE" = "200" ]; then
        SIZE=$(curl -s "http://localhost:$PORT/$sig" | wc -c | tr -d ' ')
        echo "  ✓ EXISTS: $sig ($SIZE bytes)"
    else
        echo "  ✗ MISSING: $sig"
    fi
done

# Read modules from file
FLUTTER_PACKAGES=()
while IFS= read -r line; do
    FLUTTER_PACKAGES+=("$line")
done < "$OUTPUT_DIR/flutter_modules.txt"

for pkg in "${FLUTTER_PACKAGES[@]}"; do
    dir=$(dirname "$OUTPUT_DIR/$pkg")
    mkdir -p "$dir"
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$OUTPUT_DIR/$pkg" "http://localhost:$PORT/$pkg")
    if [ "$HTTP_CODE" = "200" ] && [ -s "$OUTPUT_DIR/$pkg" ]; then
        SIZE=$(wc -c < "$OUTPUT_DIR/$pkg" | tr -d ' ')
        echo "  ✓ $pkg ($SIZE bytes)"
    else
        rm -f "$OUTPUT_DIR/$pkg"
        echo "  ✗ $pkg (HTTP $HTTP_CODE)"
    fi
done

echo ""
echo "=== Stopping Flutter server ==="
kill $FLUTTER_PID 2>/dev/null
pkill -P $FLUTTER_PID 2>/dev/null

echo ""
echo "=== Done ==="
echo "JS files saved to: $OUTPUT_DIR"
find "$OUTPUT_DIR" -type f -name "*.js" -size +0 | wc -l | xargs echo "Files downloaded:"
