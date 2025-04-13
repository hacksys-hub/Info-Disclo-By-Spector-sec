#!/bin/bash

# Define colors for a better interface
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
CYAN=$(tput setaf 6)
BOLD=$(tput bold)
RESET=$(tput sgr0)

# Ask for target input
echo "${BOLD}${CYAN}Do you want to enter a single target or load from a file?${RESET}"
echo "${YELLOW}1) Single Target"
echo "2) Load from target.txt${RESET}"
read -p "Select option (1/2): " target_option

if [[ "$target_option" == "1" ]]; then
    read -p "Enter the target domain (e.g., example.com): " TARGET
    TARGET_FILE="/tmp/single_target.txt"
    echo "$TARGET" > "$TARGET_FILE"
elif [[ "$target_option" == "2" ]]; then
    read -p "Enter the path to target file (default: target.txt): " TARGET_FILE
    TARGET_FILE=${TARGET_FILE:-"target.txt"}
else
    echo "${RED}Invalid option! Exiting...${RESET}"
    exit 1
fi

# Create output directory
OUTPUT_DIR="output"
mkdir -p "$OUTPUT_DIR"

# Log file setup
LOG_FILE="$OUTPUT_DIR/scan.log"
> "$LOG_FILE"

# User agents file setup
USER_AGENTS_FILE="user_agents.txt"
if [[ ! -f "$USER_AGENTS_FILE" ]]; then
    echo "${YELLOW}Warning: user_agents.txt not found! Using default user agents.${RESET}"
    echo -e "Mozilla/5.0\nGooglebot/2.1\ncurl/7.68.0" > "$USER_AGENTS_FILE"
fi

# Ask for further refinements
read -p "Enter max depth for recursion (default: 5): " MAX_DEPTH
MAX_DEPTH=${MAX_DEPTH:-5}

read -p "Enter delay between requests in seconds (default: 2): " DELAY
DELAY=${DELAY:-2}

read -p "Enter file types to accept (default: html,js,css): " ACCEPT_TYPES
ACCEPT_TYPES=${ACCEPT_TYPES:-"html,js,css"}

read -p "Enter sensitive keywords regex (default: API keys, tokens, etc.): " SENSITIVE_KEYWORDS
SENSITIVE_KEYWORDS=${SENSITIVE_KEYWORDS:-"(api_key|password|secret|token|endpoint|auth|credential|access_key|private_key|session_id|oauth)"}

# Function to process each target
process_target() {
    local target=$1
    local output_dir="$OUTPUT_DIR/$target"
    mkdir -p "$output_dir"

    # Randomly select a user agent
    local user_agent=$(shuf -n 1 "$USER_AGENTS_FILE")

    echo "${GREEN}Processing target: $target${RESET}" | tee -a "$LOG_FILE"

    # Download website content
    wget -r -l "$MAX_DEPTH" --domains "$target" --accept "$ACCEPT_TYPES" \
        --random-wait --wait="$DELAY" --user-agent="$user_agent" --no-check-certificate \
        -P "$output_dir" "https://$target" 2>> "$LOG_FILE"

    # Search for sensitive keywords
    echo "${CYAN}Scanning for sensitive information...${RESET}"
    grep -riE "$SENSITIVE_KEYWORDS" "$output_dir" | tee -a "$LOG_FILE"

    echo "${BOLD}${BLUE}Finished processing: $target${RESET}" | tee -a "$LOG_FILE"
    echo "----------------------------------------" | tee -a "$LOG_FILE"
}

# Export functions for xargs
export -f process_target
export OUTPUT_DIR LOG_FILE USER_AGENTS_FILE DELAY MAX_DEPTH ACCEPT_TYPES SENSITIVE_KEYWORDS

# Trap SIGINT (Ctrl+C) to save progress before exiting
trap 'echo -e "${RED}\nScan aborted! Saving results...${RESET}"; cat "$LOG_FILE"; exit' SIGINT

# Process all targets
cat "$TARGET_FILE" | while read -r target; do
    [[ -z "$target" ]] && continue
    process_target "$target"
done

echo "${GREEN}Scanning complete! Results saved in ${BOLD}$LOG_FILE${RESET}
