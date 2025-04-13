
### Bash Tools Dependencies
For the Bash tools (Wayback Extractor, Web Scanner, Vuln Search, Enhanced Recon), create a `dependencies.sh` file:

`bash-tools/dependencies.sh`:
```bash
#!/bin/bash
# Install common dependencies for all bash tools

sudo apt update
sudo apt install -y \
    curl \
    wget \
    grep \
    sed \
    jq \
    exploitdb \
    metasploit-framework
