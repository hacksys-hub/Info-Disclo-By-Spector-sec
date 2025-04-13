#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage information
show_help() {
    echo -e "${CYAN}Usage:${NC}"
    echo -e "  $0 [target_file]"
    echo -e "\n${CYAN}Description:${NC}"
    echo -e "  This script extracts URLs from Wayback Machine for domains in the specified file."
    echo -e "  If no file is provided, it will prompt for one (default: urls.txt)."
    echo -e "\n${CYAN}Options:${NC}"
    echo -e "  ${YELLOW}--help${NC}    Show this help message"
    exit 0
}

# Check for help flag
if [[ "$1" == "--help" ]]; then
    show_help
fi

# Set default target file
DEFAULT_TARGET="urls.txt"

# Check if target file was provided as argument
if [ $# -ge 1 ] && [ "$1" != "--help" ]; then
    target_file="$1"
else
    # Prompt for target file
    echo -e "${CYAN}Enter path to target file (default: ${YELLOW}${DEFAULT_TARGET}${CYAN}):${NC}"
    read -r target_file
    target_file=${target_file:-$DEFAULT_TARGET}
fi

# Validate target file
if [ ! -f "$target_file" ]; then
    echo -e "${YELLOW}⚠️  ${target_file} not found!${NC}"
    echo -e "${CYAN}Would you like to create it now? (y/n)${NC}"
    read -r create_file

    if [[ "$create_file" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Enter target domains (one per line). Press Ctrl+D when finished:${NC}"
        cat > "$target_file"
        echo -e "\n${GREEN}✅ ${target_file} created successfully!${NC}"
    else
        echo -e "${RED}❌ Aborting: Target file is required${NC}"
        exit 1
    fi
fi

# Check if target file is empty
if [ ! -s "$target_file" ]; then
    echo -e "${RED}❌ ${target_file} is empty! Please add some domains.${NC}"
    exit 1
fi

# Create output directory with timestamp
output_dir="wayback_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$output_dir"
output_file="${output_dir}/extracted_urls.txt"

# Display processing header
echo -e "\n${MAGENTA}=============================================${NC}"
echo -e "${MAGENTA}🚀 Wayback Machine URL Extractor${NC}"
echo -e "${MAGENTA}Processing targets from: ${YELLOW}${target_file}${NC}"
echo -e "${MAGENTA}=============================================${NC}\n"

# Process each domain from target file
total_urls=0
processed_domains=0
skipped_domains=0

while IFS= read -r domain; do
    # Remove http:// and https:// if present
    domain=$(echo "$domain" | sed -E 's/^https?:\/\///' | sed 's/\/$//')

    # Skip empty lines and comments
    if [[ -z "$domain" || "$domain" =~ ^# ]]; then
        continue
    fi

    ((processed_domains++))
    echo -e "\n${CYAN}🕵️  Processing [${processed_domains}]: ${YELLOW}${domain}${NC}"

    # Run Wayback Machine query with timeout
    results=$(timeout 30 curl -Gs "https://web.archive.org/cdx/search/cdx" \
        --data-urlencode "url=*.${domain}/*" \
        --data-urlencode "collapse=urlkey" \
        --data-urlencode "output=text" \
        --data-urlencode "fl=original,timestamp" 2>&1)

    curl_exit=$?

    if [ $curl_exit -eq 124 ]; then
        echo -e "${RED}⏱️  Timeout occurred while querying ${domain}${NC}"
        ((skipped_domains++))
        continue
    elif [ $curl_exit -ne 0 ]; then
        echo -e "${RED}❌ Curl error (${curl_exit}) while querying ${domain}${NC}"
        echo -e "${YELLOW}Error details:${NC}\n${results}"
        ((skipped_domains++))
        continue
    fi

    if [ -z "$results" ]; then
        echo -e "${YELLOW}⚠️  No archived URLs found for ${domain}${NC}"
        ((skipped_domains++))
        continue
    fi

    # Count URLs and add to total
    url_count=$(echo "$results" | wc -l)
    ((total_urls += url_count))

    # Save results with domain header
    echo -e "\n# Domain: ${domain} (${url_count} URLs)" >> "$output_file"
    echo "$results" >> "$output_file"

    # Colorized processing with interesting findings highlighted
    echo "$results" | awk \
        -v green="$GREEN" -v yellow="$YELLOW" -v cyan="$CYAN" \
        -v magenta="$MAGENTA" -v blue="$BLUE" -v red="$RED" -v nc="$NC" \
    '
    BEGIN {
        printf "%s=== Found %d URLs for %s ===%s\n", magenta, url_count, domain, nc
    }
    {
        # Split into components
        split($0, parts, " ")
        url = parts[1]
        timestamp = parts[2]

        # Highlight interesting patterns
        if (match(url, /(api|auth|login|admin|secure|restricted)/)) {
            url = substr(url, 1, RSTART-1) red substr(url, RSTART, RLENGTH) nc substr(url, RSTART+RLENGTH)
        }

        # Highlight file extensions
        if (match(url, /\.(php|asp|jsp|cgi|pl|sh|py|rb|js|action|do|env|config|ini)/)) {
            ext = substr(url, RSTART, RLENGTH)
            url = substr(url, 1, RSTART-1) blue ext nc substr(url, RSTART+RLENGTH)
        }

        # Highlight parameters
        if (match(url, /\?(.*)/)) {
            params = substr(url, RSTART)
            url = substr(url, 1, RSTART-1) yellow params nc
        }

        printf "▸ %s%s%s [%s%s%s]\n", cyan, url, nc, green, timestamp, nc
    }'

    echo -e "${GREEN}✅ Found ${url_count} URLs for ${YELLOW}${domain}${NC}"

done < "$target_file"

# Final summary
echo -e "\n${MAGENTA}=============================================${NC}"
echo -e "${GREEN}🎉 Processing complete!${NC}"
echo -e "${CYAN}Target file used: ${YELLOW}${target_file}${NC}"
echo -e "${CYAN}Processed domains: ${YELLOW}${processed_domains}${NC}"
echo -e "${CYAN}Skipped domains: ${YELLOW}${skipped_domains}${NC}"
echo -e "${CYAN}Total URLs found: ${YELLOW}${total_urls}${NC}"
echo -e "${CYAN}Output directory: ${YELLOW}${output_dir}${NC}"
echo -e "${CYAN}Full results saved to: ${YELLOW}${output_file}${NC}"
echo -e "${MAGENTA}=============================================${NC}\n"
