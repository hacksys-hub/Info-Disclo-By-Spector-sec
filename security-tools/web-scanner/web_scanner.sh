#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Sensitive patterns to search for
PATTERNS="(api[_-]?key|password|secret|token|endpoint|auth|credential|access[_-]?key|private[_-]?key|session[_-]?id|oauth)"

# Prompt for target file
echo -e "${CYAN}Enter path to target file (default: urls.txt):${NC}"
read -r target_file
target_file=${target_file:-urls.txt}

# Validate target file
if [ ! -f "$target_file" ]; then
    echo -e "${RED}❌ Error: Target file '$target_file' not found!${NC}"
    exit 1
fi

if [ ! -s "$target_file" ]; then
    echo -e "${RED}❌ Error: Target file '$target_file' is empty!${NC}"
    exit 1
fi

# Create output directory
output_dir="scan_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$output_dir"

echo -e "\n${MAGENTA}=============================================${NC}"
echo -e "${MAGENTA}🌐 Web Content Scanner & Sensitive Data Finder${NC}"
echo -e "${MAGENTA}=============================================${NC}\n"

total_targets=$(grep -vc '^$' "$target_file")
current_target=0

while IFS= read -r target; do
    # Skip empty lines
    [ -z "$target" ] && continue

    ((current_target++))
    target=$(echo "$target" | sed -E 's/^https?:\/\///')

    echo -e "\n${CYAN}🔍 [${current_target}/${total_targets}] Processing: ${YELLOW}${target}${NC}"

    # Create target-specific directory
    target_dir="${output_dir}/${target}"
    mkdir -p "$target_dir"

    # Download web content
    echo -e "${BLUE}⬇️  Downloading content (recursive level 5)...${NC}"
    wget -q -r -l 5 --domains "$target" --accept html,js,css -P "$target_dir" "https://$target" 2>&1 | \
        while read -r line; do
            echo -e "${YELLOW}${line}${NC}"
        done

    # Search for sensitive patterns
    echo -e "\n${BLUE}🕵️  Searching for sensitive patterns...${NC}"
    grep -riE --color=always "$PATTERNS" "$target_dir" | \
        while read -r line; do
            # Highlight different parts of the match
            line=$(echo "$line" | sed -E "s/${PATTERNS}/${RED}\0${NC}/gi")
            line=$(echo "$line" | sed -E "s/^([^:]+:)/${CYAN}\1${NC}/")
            echo -e "$line"
        done > "${target_dir}/sensitive_matches.txt"

    # Show summary
    match_count=$(grep -c . "${target_dir}/sensitive_matches.txt" 2>/dev/null || echo 0)
    if [ "$match_count" -gt 0 ]; then
        echo -e "${RED}⚠️  Found ${match_count} sensitive matches!${NC}"
        echo -e "${YELLOW}Matches saved to: ${target_dir}/sensitive_matches.txt${NC}"
    else
        echo -e "${GREEN}✅ No sensitive patterns found${NC}"
    fi

done < "$target_file"

# Final summary
echo -e "\n${MAGENTA}=============================================${NC}"
echo -e "${GREEN}🎉 Scan completed!${NC}"
echo -e "${CYAN}Total targets processed: ${YELLOW}${total_targets}${NC}"
echo -e "${CYAN}Output directory: ${YELLOW}${output_dir}${NC}"
echo -e "${MAGENTA}=============================================${NC}\n"
