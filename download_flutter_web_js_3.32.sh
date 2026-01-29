#!/bin/bash

# Ensure we have curl in PATH
export PATH="/usr/bin:/bin:/usr/local/bin:$PATH"

# Script to run a Flutter web project and download all generated JS files
# Uses FVM with Flutter 3.32.2 (RequireJS/AMD module format)
#
# Usage: ./download_flutter_web_js_3.32.sh <project_dir> [port]
#
# JS files will be saved to <project_dir>/build_js/
#
# Example:
#   ./download_flutter_web_js_3.32.sh /tmp/flutter_debug_dummy 8083
#   ./download_flutter_web_js_3.32.sh /path/to/real_project 8084

FLUTTER_VERSION="3.32.2"
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

echo "=== Setting up FVM with Flutter $FLUTTER_VERSION ==="
cd "$PROJECT_DIR"

# Install the Flutter version if not already installed
if ! fvm list | grep -q "$FLUTTER_VERSION"; then
    echo "Installing Flutter $FLUTTER_VERSION..."
    fvm install "$FLUTTER_VERSION"
fi

# Use the specified Flutter version for this project
fvm use "$FLUTTER_VERSION" --force

echo "=== Starting Flutter web server ==="
echo "Project: $PROJECT_DIR"
echo "Output: $OUTPUT_DIR"
echo "Port: $PORT"
echo "Flutter: $FLUTTER_VERSION (via FVM)"

# Start Flutter web server in background with Hologram-style flags
fvm flutter run -d web-server \
    --web-port=$PORT \
    --web-hostname=127.0.0.1 \
    --suppress-analytics \
    --no-enable-dart-profiling \
    --track-widget-creation \
    --web-experimental-hot-reload \
    --debug \
    --no-devtools \
    --no-dds \
    > /tmp/flutter_web_server_$PORT.log 2>&1 &
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

# Trigger full compilation by requesting files
echo "Triggering compilation..."

# Request the bootstrap chain to trigger compilation
curl -s "http://localhost:$PORT/" > /dev/null
curl -s "http://localhost:$PORT/main.dart.js" > /dev/null
curl -s "http://localhost:$PORT/dart_sdk.js" > /dev/null

# Wait for dart_sdk.js (this is the big one in 3.32)
COMPILE_WAIT=0
while [ $COMPILE_WAIT -lt 90 ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/dart_sdk.js")
    if [ "$HTTP_CODE" = "200" ]; then
        echo "dart_sdk.js ready"
        break
    fi
    sleep 3
    COMPILE_WAIT=$((COMPILE_WAIT + 3))
    echo "  Compiling... ($COMPILE_WAIT seconds)"
done

sleep 2

echo ""
echo "=== Discovering available files ==="

# In Flutter 3.32, modules use .dart.js format (not .dart.lib.js)
# The main files are:
#   - dart_sdk.js (contains all Dart SDK + Flutter framework)
#   - packages/<pkg>/<file>.dart.js (app packages)
#   - web_entrypoint.dart.js

# Download core files
echo "Downloading core files..."
curl -s "http://localhost:$PORT/main.dart.js" > "$OUTPUT_DIR/main.dart.js"
curl -s "http://localhost:$PORT/main_module.bootstrap.js" > "$OUTPUT_DIR/main_module.bootstrap.js"
curl -s "http://localhost:$PORT/dart_sdk.js" > "$OUTPUT_DIR/dart_sdk.js"
curl -s "http://localhost:$PORT/web_entrypoint.dart.js" > "$OUTPUT_DIR/web_entrypoint.dart.js"
curl -s "http://localhost:$PORT/require.js" > "$OUTPUT_DIR/require.js"
curl -s "http://localhost:$PORT/stack_trace_mapper.js" > "$OUTPUT_DIR/stack_trace_mapper.js"

echo "  main.dart.js: $(wc -c < "$OUTPUT_DIR/main.dart.js" | tr -d ' ') bytes"
echo "  main_module.bootstrap.js: $(wc -c < "$OUTPUT_DIR/main_module.bootstrap.js" | tr -d ' ') bytes"
echo "  dart_sdk.js: $(wc -c < "$OUTPUT_DIR/dart_sdk.js" | tr -d ' ') bytes"
echo "  web_entrypoint.dart.js: $(wc -c < "$OUTPUT_DIR/web_entrypoint.dart.js" | tr -d ' ') bytes"

echo ""
echo "=== Downloading package modules ==="

# Get the project name from pubspec.yaml
PROJECT_NAME=$(grep "^name:" "$PROJECT_DIR/pubspec.yaml" | sed 's/name: *//' | tr -d ' ')
echo "Project name: $PROJECT_NAME"

# In Flutter 3.32, packages are accessed as packages/<name>/<file>.dart.js
# We need to discover what packages are available

# Common package patterns to try
PACKAGE_FILES=(
    "packages/$PROJECT_NAME/main.dart.js"
    "packages/flutter_mate/flutter_mate.dart.js"
)

# Also check dependencies from pubspec.yaml
DEPS=$(grep -A 100 "^dependencies:" "$PROJECT_DIR/pubspec.yaml" | grep -E "^  [a-z_]+:" | sed 's/:.*//' | tr -d ' ')

for dep in $DEPS; do
    # Skip flutter sdk dependency
    if [ "$dep" = "flutter" ]; then continue; fi
    PACKAGE_FILES+=("packages/$dep/$dep.dart.js")
done

mkdir -p "$OUTPUT_DIR/packages"

for pkg_file in "${PACKAGE_FILES[@]}"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/$pkg_file")
    if [ "$HTTP_CODE" = "200" ]; then
        dir=$(dirname "$OUTPUT_DIR/$pkg_file")
        mkdir -p "$dir"
        curl -s "http://localhost:$PORT/$pkg_file" > "$OUTPUT_DIR/$pkg_file"
        SIZE=$(wc -c < "$OUTPUT_DIR/$pkg_file" | tr -d ' ')
        echo "  ✓ $pkg_file ($SIZE bytes)"
    else
        echo "  ✗ $pkg_file (HTTP $HTTP_CODE)"
    fi
done

echo ""
echo "=== Stopping Flutter server ==="
kill $FLUTTER_PID 2>/dev/null
pkill -P $FLUTTER_PID 2>/dev/null

echo ""
echo "=== Done ==="
echo "JS files saved to: $OUTPUT_DIR"
echo ""
echo "Files downloaded:"
find "$OUTPUT_DIR" -type f -name "*.js" -size +0 -exec ls -lh {} \; | awk '{print "  " $NF ": " $5}'
