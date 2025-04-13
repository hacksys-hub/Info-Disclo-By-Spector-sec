import os
import requests
import hashlib
import mmh3
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
from colorama import Fore, Style, init
import concurrent.futures
import argparse
import json
import time

# Initialize colorama
init(autoreset=True)

# Constants
TIMEOUT = 15
HEADERS = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'}

# Enhanced favicon URL discovery
def fetch_favicon_urls(domain):
    favicon_urls = set()
    try:
        if not domain.startswith(('http://', 'https://')):
            domain = f'https://{domain}'

        response = requests.get(domain, headers=HEADERS, timeout=TIMEOUT, allow_redirects=True)
        response.raise_for_status()
        final_url = response.url  # Get final URL after redirects
        domain = urlparse(final_url).netloc

        soup = BeautifulSoup(response.text, 'html.parser')

        # Find all possible favicon links
        for link in soup.find_all('link', rel=['icon', 'shortcut icon', 'apple-touch-icon', 'apple-touch-icon-precomposed']):
            if 'href' in link.attrs:
                favicon_url = link['href']
                if not favicon_url.startswith(('http://', 'https://')):
                    favicon_url = urljoin(final_url, favicon_url)
                favicon_urls.add(favicon_url)

        # Check for common favicon locations
        common_paths = [
            '/favicon.ico',
            '/static/favicon.ico',
            '/img/favicon.ico',
            '/images/favicon.ico',
            '/assets/favicon.ico'
        ]

        with concurrent.futures.ThreadPoolExecutor() as executor:
            futures = []
            for path in common_paths:
                futures.append(executor.submit(
                    requests.head,
                    urljoin(final_url, path),
                    headers=HEADERS,
                    timeout=TIMEOUT/2,
                    allow_redirects=True
                ))

            for future in concurrent.futures.as_completed(futures):
                try:
                    response = future.result()
                    if response.status_code == 200:
                        favicon_urls.add(response.url)
                except:
                    continue

        return list(favicon_urls)

    except Exception as e:
        print(f"{Fore.RED}[-] Error fetching favicons for {domain}: {e}{Style.RESET_ALL}")
        return []

# Enhanced favicon download and hashing
def process_favicon(favicon_url, domain):
    try:
        response = requests.get(favicon_url, headers=HEADERS, timeout=TIMEOUT, stream=True)
        response.raise_for_status()
        content = response.content

        # Calculate hashes
        md5_hash = hashlib.md5(content).hexdigest()
        sha1_hash = hashlib.sha1(content).hexdigest()
        sha256_hash = hashlib.sha256(content).hexdigest()
        mmh3_hash = mmh3.hash(content)

        # File info
        file_size = len(content)
        file_type = response.headers.get('Content-Type', 'unknown')

        # Save favicon
        os.makedirs('favicons', exist_ok=True)
        domain_clean = domain.replace(':', '_').replace('/', '_')
        filename = f"favicons/{domain_clean}_{md5_hash}.ico"

        with open(filename, 'wb') as f:
            f.write(content)

        return {
            'url': favicon_url,
            'file_path': filename,
            'hashes': {
                'md5': md5_hash,
                'sha1': sha1_hash,
                'sha256': sha256_hash,
                'mmh3': mmh3_hash
            },
            'file_info': {
                'size': file_size,
                'type': file_type
            },
            'scan_urls': {
                'shodan': f"https://www.shodan.io/search?query=http.favicon.hash%3A{mmh3_hash}",
                'virustotal': f"https://www.virustotal.com/gui/file/{sha256_hash}",
                'censys': f"https://search.censys.io/search?resource=hosts&q=services.http.response.favicon.md5_hash%3A{md5_hash}",
                'urlscan': f"https://urlscan.io/search/#page.favicon.md5%3A%22{md5_hash}%22"
            }
        }

    except Exception as e:
        print(f"{Fore.RED}[-] Error processing {favicon_url}: {e}{Style.RESET_ALL}")
        return None

# Main processor
def process_domain(domain):
    results = {'domain': domain, 'favicons': []}
    print(f"\n{Fore.GREEN}[+] Processing: {domain}{Style.RESET_ALL}")

    favicon_urls = fetch_favicon_urls(domain)
    if not favicon_urls:
        print(f"{Fore.YELLOW}[!] No favicons found for {domain}{Style.RESET_ALL}")
        return results

    print(f"{Fore.CYAN}[*] Found {len(favicon_urls)} favicon URLs{Style.RESET_ALL}")

    with concurrent.futures.ThreadPoolExecutor() as executor:
        futures = []
        for url in favicon_urls:
            futures.append(executor.submit(process_favicon, url, domain))

        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            if result:
                results['favicons'].append(result)
                print(f"\n{Fore.MAGENTA}[+] Favicon Analysis:{Style.RESET_ALL}")
                print(f"URL: {result['url']}")
                print(f"Saved to: {result['file_path']}")
                print(f"Size: {result['file_info']['size']} bytes")
                print(f"Type: {result['file_info']['type']}")
                print(f"\n{Fore.BLUE}Hashes:{Style.RESET_ALL}")
                print(f"MD5:    {result['hashes']['md5']}")
                print(f"SHA1:   {result['hashes']['sha1']}")
                print(f"SHA256: {result['hashes']['sha256']}")
                print(f"mmh3:   {result['hashes']['mmh3']}")
                print(f"\n{Fore.YELLOW}Scan Links:{Style.RESET_ALL}")
                print(f"Shodan:     {result['scan_urls']['shodan']}")
                print(f"VirusTotal: {result['scan_urls']['virustotal']}")
                print(f"Censys:     {result['scan_urls']['censys']}")
                print(f"URLScan:    {result['scan_urls']['urlscan']}")
                print("-"*50)

    return results

# Main function
def main():
    print(f"""{Fore.CYAN}
   _____         _ _             _____      _             _____          _
  / ____|       | (_)           |  __ \    (_)           / ____|        | |
 | |  __ ___   _| |_ _ __   __ _| |__) | __ _ _ __   ___| |     ___   __| | ___
 | | |_ | / / | | | | '_ \ / _` |  ___/ '__| | '_ \ / _ \ |    / _ \ / _` |/ _ \\
 | |__| |/ /| |_| | | | | | (_| | |   | |  | | | | |  __/ |___| (_) | (_| |  __/
  \_____|/_/  \__,_|_|_| |_|\__, |_|   |_|  |_|_| |_|\___|\_____\___/ \__,_|\___|
                             __/ |
                            |___/
    {Style.RESET_ALL}""")

    parser = argparse.ArgumentParser(description=r'Advanced Favicon Analysis Tool')
    parser.add_argument('target', help='Domain or file containing domains')
    parser.add_argument('-o', '--output', help='Output file (JSON format)')
    args = parser.parse_args()

    domains = []
    if os.path.isfile(args.target):
        with open(args.target, 'r') as f:
            domains = [line.strip() for line in f.readlines() if line.strip()]
    else:
        domains = [args.target]

    all_results = []
    start_time = time.time()

    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        future_to_domain = {executor.submit(process_domain, domain): domain for domain in domains}
        for future in concurrent.futures.as_completed(future_to_domain):
            domain = future_to_domain[future]
            try:
                result = future.result()
                all_results.append(result)
            except Exception as e:
                print(f"{Fore.RED}[-] Error processing {domain}: {e}{Style.RESET_ALL}")

    if args.output:
        with open(args.output, 'w') as f:
            json.dump(all_results, f, indent=2)
        print(f"\n{Fore.GREEN}[+] Results saved to {args.output}{Style.RESET_ALL}")

    print(f"\n{Fore.GREEN}[+] Processed {len(domains)} domains in {time.time()-start_time:.2f} seconds{Style.RESET_ALL}")

if __name__ == "__main__":
    main()
