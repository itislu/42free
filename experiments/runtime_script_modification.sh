#!/bin/bash

# What happens when a script is modified while it is running?

script=$(mktemp)

echo "=== Testing Line-by-line Version ==="

# Create the non-function version
cat << 'EOF' > "$script"
#!/bin/bash

echo "Starting script execution..."
echo "Line-by-line: Line 1 - Original"
sleep 2
echo "Line-by-line: Line 2 - Original"
sleep 2
echo "Line-by-line: Line 3 - Original"
sleep 2
echo "Line-by-line: Line 4 - Original"
sleep 2
echo "Finished execution"
EOF

chmod +x "$script"

# Start the line-by-line version
"$script" &
SCRIPT_PID=$!

# Wait before modifying
sleep 3

# Modify the script
cat << 'EOF' > "$script"
#!/bin/bash

echo "Starting script execution..."
echo "Line-by-line: Line 1 - Modified"
sleep 2
echo "Line-by-line: Line 2 - Modified"
sleep 2
echo "Line-by-line: Line 3 - Modified"
sleep 2
echo "Line-by-line: Line 4 - Modified"
sleep 2
echo "Finished execution"
EOF

# Wait for script to finish
wait $SCRIPT_PID

echo -e "\nRunning modified regular version:"
"$script"

echo -e "\n=== Testing Function Version ==="

# Create the function version
cat << 'EOF' > "$script"
#!/bin/bash

test_function() {
    echo "Function: Line 1 - Original"
    sleep 2
    echo "Function: Line 2 - Original"
    sleep 2
    echo "Function: Line 3 - Original"
    sleep 2
    echo "Function: Line 4 - Original"
    sleep 2
}

echo "Starting script execution..."
test_function
echo "Finished execution"
EOF

chmod +x "$script"

# Start the function version
"$script" &
SCRIPT_PID=$!

# Wait before modifying
sleep 3

# Modify the script
cat << 'EOF' > "$script"
#!/bin/bash

test_function() {
    echo "Function: Line 1 - Modified"
    sleep 2
    echo "Function: Line 2 - Modified"
    sleep 2
    echo "Function: Line 3 - Modified"
    sleep 2
    echo "Function: Line 4 - Modified"
    sleep 2
}

echo "Starting script execution..."
test_function
echo "Finished execution"
EOF

# Wait for script to finish
wait $SCRIPT_PID

echo -e "\nRunning modified function version:"
"$script" &
SCRIPT_PID=$!

# Wait for script to finish
wait $SCRIPT_PID

# Clean up
rm -f "$script"
