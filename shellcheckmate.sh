#!/bin/bash

# Output an error message and exit
# # List of required tools
required_tools=("valgrind" "helgrind" "drd")

# List of required executables
required_executables=("executable1" "executable2" "executable3")

# Function to check the existence of a tool
function check_tool_exists() {
    command -v $1 >/dev/null 2>&1 || { echo >&2 "$1 is required but it's not installed.  Aborting."; exit 1; }
}

# Function to check the existence of an executable
function check_executable_exists() {
    if [ ! -f $1 ]; then
        echo "$1 executable does not exist. Aborting."
        exit 1
    fi
}

# Check all required tools
for tool in "${required_tools[@]}"
do
    check_tool_exists $tool
done

# Check all required executables
for executable in "${required_executables[@]}"
do
    check_executable_exists $executable
done

echo "All required tools and executables exist. Proceeding with tests..."
# Here you can continue with the actual testing part of your script

# Function to check for updates
function check_for_updates() {
    git fetch
    local local_hash=$(git rev-parse master)
    local remote_hash=$(git rev-parse origin/master)

    if [ $local_hash != $remote_hash ]; then
        echo "Updates are available on the remote repository. Please pull the latest changes."
    else
        echo "Local repository is up to date with the remote repository."
    fi
}

# Function to automatically update the tests
function update_tests() {
    git fetch
    local local_hash=$(git rev-parse master)
    local remote_hash=$(git rev-parse origin/master)

    if [ $local_hash != $remote_hash ]; then
        echo "Updates are available on the remote repository. Pulling the latest changes..."
        git pull
        echo "Update complete."
    else
        echo "Local repository is up to date with the remote repository."
    fi
}

test_valgrind () {
  local executable="$1"
  shift  # Shift the positional parameters to the left, dropping the first parameter
  local parameters="$@"

  timeout 30 valgrind --leak-check=full --errors-for-leak-kinds=all --error-exitcode=1 "$executable" $parameters &> "./valgrind_$executable.log"
  if [ $? -eq 0 ]; then
    echo "${green}[+] Valgrind Test Succeeded !${reset}"
  else
    echo "${red}[-] Valgrind Test Failed with parameters: $parameters ${reset}"
  fi
  rm -rf "./valgrind_$executable.log"
}

function test_valgrind_fds {
  local executable="$1"
  shift # Shift parameters to remove the first argument (the executable name)

  # Store the parameters used
  local parameters="$@"

  # Run valgrind and save the output
  valgrind_output=$(timeout 30 valgrind --leak-check=full --errors-for-leak-kinds=all --track-fds=yes "$executable" "$@")

  # Check for open file descriptors in the output
  open_fds=$(echo "$valgrind_output" | grep -o 'file descriptor [0-9]*' | cut -d ' ' -f 3)

  # Error out if any non-standard file descriptors are found
  for fd in $open_fds; do
    if [[ $fd -gt 2 ]]; then
      echo "Non-standard file descriptor $fd left open"
      echo "Valgrind test failed with parameters: $parameters"
      return 1
    fi
  done

  echo "No non-standard file descriptors left open"
  return 0
}
