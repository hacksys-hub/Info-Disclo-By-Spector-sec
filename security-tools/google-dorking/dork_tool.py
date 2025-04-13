import sys
import time
import random
import colorama
from colorama import Fore, Style
from serpapi import GoogleSearch  # Import SerpAPI
import signal

colorama.init(autoreset=True)

API_KEY = "ffb978a27bfc8db7cbabf5ae5699a59fd37edd757f9e274a056fc9b50affe181"  # Get a free API key from https://serpapi.com/

def banner():
    print(Fore.RED + Style.BRIGHT + "\n[+] Advanced Google Dorking Tool - Spector-Sec [+]\n")

def get_target():
    choice = input(Fore.CYAN + "[?] Enter 1 for single target, 2 for target.txt: ")
    if choice == "1":
        return [input(Fore.CYAN + "[+] Enter target domain: ")]
    elif choice == "2":
        filename = input(Fore.CYAN + "[+] Enter filename containing target list: ")
        with open(filename, "r") as file:
            return [line.strip() for line in file.readlines()]
    else:
        print(Fore.RED + "[!] Invalid choice, exiting...")
        sys.exit()

def get_queries():
    choice = input(Fore.CYAN + "[?] Enter 1 for single dork query, 2 for dork.txt list: ")
    if choice == "1":
        return [input(Fore.CYAN + "[+] Enter your Google Dork query (e.g., filetype:sql): ")]
    elif choice == "2":
        filename = input(Fore.CYAN + "[+] Enter filename containing dork queries: ")
        with open(filename, "r") as file:
            return [line.strip() for line in file.readlines()]
    else:
        print(Fore.RED + "[!] Invalid choice, exiting...")
        sys.exit()

def perform_dorking(queries, targets):
    results = {}

    for target in targets:
        for query in queries:
            search_query = f"site:{target} {query}"
            print(Fore.MAGENTA + f"\n[+] Searching: {search_query}\n")
            results[search_query] = []

            try:
                params = {
                    "engine": "google",
                    "q": search_query,
                    "api_key": API_KEY
                }
                search = GoogleSearch(params)
                response = search.get_dict()

                # Extract results
                if "organic_results" in response:
                    for result in response["organic_results"]:
                        url = result.get("link")
                        if url:
                            results[search_query].append(url)
                            print(Fore.GREEN + f"[+] Found: {url}")  # Real-time display

                print(Fore.GREEN + f"[+] Found {len(results[search_query])} results for {search_query}")

            except Exception as e:
                print(Fore.RED + f"[!] Error performing dorking: {e}")

    return results

def save_results(results):
    save = input(Fore.YELLOW + "\n[?] Save results to a file? (y/n): ").lower()
    if save == "y":
        filename = f"dorking_results_{int(time.time())}.txt"
        with open(filename, "w") as f:
            for query, urls in results.items():
                f.write(f"\nQuery: {query}\n")
                f.write("\n".join(urls) + "\n")
        print(Fore.CYAN + f"[+] Results saved to {filename}")

def handle_exit(signal_received, frame):
    print(Fore.YELLOW + "\n[!] Process interrupted. Do you want to save results? (y/n): ", end="")
    choice = input().lower()
    if choice == "y":
        save_results(global_results)
    sys.exit(0)

global_results = {}

def main():
    global global_results
    banner()
    targets = get_target()
    queries = get_queries()
    signal.signal(signal.SIGINT, handle_exit)  # Capture Ctrl+C

    global_results = perform_dorking(queries, targets)

    save_results(global_results)

if __name__ == "__main__":
    main()
