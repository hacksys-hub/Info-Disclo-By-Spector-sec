#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${GREEN}"
echo "  ____  _   _ ____  _____ ____  ____  _____ ____  "
echo " / ___|| | | |  _ \| ____|  _ \|  _ \| ____|  _ \ "
echo " \___ \| |_| | |_) |  _| | |_) | |_) |  _| | |_) |"
echo "  ___) |  _  |  __/| |___|  __/|  __/| |___|  _ < "
echo " |____/|_| |_|_|   |_____|_|   |_|   |_____|_| \_\\"
echo -e "${NC}"
echo "Automated Vulnerability Search Tool"
echo "Created by Spector-sec"
echo "===================================="

# Prompt for server type and version
read -p "Enter the server type (e.g., Apache, Nginx, IIS, PHP): " server_type
read -p "Enter the version (e.g., 2.4.49, 1.25.3): " version

# Combine server type and version
target="$server_type $version"

# Output directory
output_dir="vuln_search_results"
mkdir -p "$output_dir"

# SearchSploit
echo -e "${YELLOW}[+] Searching Exploit-DB for $target...${NC}"
searchsploit "$target" > "$output_dir/searchsploit_${server_type}_${version}.txt"
echo -e "${GREEN}[+] SearchSploit results saved to $output_dir/searchsploit_${server_type}_${version}.txt${NC}"

# Metasploit
echo -e "${YELLOW}[+] Searching Metasploit for $target...${NC}"
msfconsole -q -x "search $target; exit" > "$output_dir/msf_${server_type}_${version}.txt"
echo -e "${GREEN}[+] Metasploit results saved to $output_dir/msf_${server_type}_${version}.txt${NC}"

# CVE Search using Circl.lu API
echo -e "${YELLOW}[+] Searching CVE database for $target...${NC}"
curl -s "https://cve.circl.lu/api/search/$server_type/$version" | jq '.' > "$output_dir/cve_${server_type}_${version}.json"
echo -e "${GREEN}[+] CVE results saved to $output_dir/cve_${server_type}_${version}.json${NC}"

# Grep high-impact vulnerabilities from SearchSploit results
echo -e "${YELLOW}[+] Filtering high-impact vulnerabilities...${NC}"
grep -iE "rce|remote|unauth|bypass" "$output_dir/searchsploit_${server_type}_${version}.txt" > "$output_dir/high_impact_${server_type}_${version}.txt"
echo -e "${GREEN}[+] High-impact vulnerabilities saved to $output_dir/high_impact_${server_type}_${version}.txt${NC}"

# Final message
echo -e
