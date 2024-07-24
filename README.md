# devopsfetch

## Overview

`devopsfetch` is a command-line tool designed for DevOps to collect and display comprehensive server information. It covers active ports, user logins, Nginx configurations, Docker images, and container statuses. Additionally, it includes a systemd service for continuous monitoring and logging.

## Features

### Information Retrieval

1. **Ports**
   - **All Active Ports:** Display all active ports and their associated services.
     ```
     devopsfetch -p
     ```
   - **Specific Port:** Display detailed information about a specific port.
     ```
     devopsfetch -p <port_number>
     ```

2. **Docker**
   - **All Docker Images and Containers:** List all Docker images and containers.
     ```
     devopsfetch -d
     ```
   - **Specific Container:** Display detailed information about a specific container.
     ```
     devopsfetch -d <container_name>
     ```

3. **Nginx**
   - **All Nginx Domains:** Display all Nginx domains and their configurations.
     ```
     devopsfetch -n
     ```
   - **Specific Domain:** Provide detailed configuration information for a specific domain.
     ```
     devopsfetch -n <domain>
     ```

4. **Users**
   - **All Users:** List all users and their last login times.
     ```
     devopsfetch -u
     ```
   - **Specific User:** Provide detailed information about a specific user.
     ```
     devopsfetch -u <username>
     ```

5. **Time Range**
   - **Activities Within a Time Range:** Display system activities within a specified time range.
     ```
     devopsfetch -t 'YYYY-MM-DD HH:MM:SS' 'YYYY-MM-DD HH:MM:SS'
     ```

### Output Formatting

- Outputs are formatted in readable tables with descriptive column names for clarity.

## Installation

The following script installs necessary dependencies and sets up the `devopsfetch` tool along with a systemd service for continuous monitoring.

```bash
#!/bin/bash

# Function to stop processes using port 80
stop_port_80_users() {
    port_80_users=$(sudo lsof -i :80 -t)
    if [ -n "$port_80_users" ]; then
        sudo kill -9 $port_80_users
    fi
}

# Update package lists and install necessary packages
sudo apt-get update

# Stop Nginx service if it's running
sudo systemctl stop nginx

# Install required packages
sudo apt-get install -y iproute2 docker.io nginx jq

# Create the devopsfetch bash script
sudo tee /usr/local/bin/devopsfetch > /dev/null << 'EOF'
#!/bin/bash

print_table_header() {
    printf "┌──────────────────────────────┬───────┐\n"
    printf "│ %-28s │ %-5s │\n" "SERVICE" "PORT"
    printf "├──────────────────────────────┼───────┤\n"
}

print_table_footer() {
    printf "└──────────────────────────────┴───────┘\n"
}

print_table_row() {
    printf "│ %-28s │ %-5s │\n" "$1" "$2"
}

get_active_ports() {
    print_table_header
    sudo ss -tulnp | awk '/users:\(\(/ {
        user = gensub(/.*users:\(\("([^"]+).*/, "\\1", "g", $NF);
        split($5, port, ":");
        printf "%-30s%s\n", user, port[2]
    }' | sed 's/^users://; s/[(,].*//' | sort | uniq | while read -r line; do
        service=$(echo "$line" | awk '{print $1}')
        port=$(echo "$line" | awk '{print $2}')
        print_table_row "$service" "$port"
    done
    print_table_footer
}

get_port_info() {
    print_table_header
    sudo ss -tulnp | grep ":$1 " | awk '/users:\(\(/ {
        user = gensub(/.*users:\(\("([^"]+).*/, "\\1", "g", $NF);
        split($5, port, ":");
        printf "%-30s%s\n", user, port[2]
    }' | sed 's/^users://; s/[(,].*//' | sort | uniq | while read -r line; do
        service=$(echo "$line" | awk '{print $1}')
        port=$(echo "$line" | awk '{print $2}')
        print_table_row "$service" "$port"
    done
    print_table_footer
}

# Other functions remain the same as before...

# Make the devopsfetch script executable
sudo chmod +x /usr/local/bin/devopsfetch

# Create the systemd service file for continuous monitoring
sudo tee /etc/systemd/system/devopsfetch.service > /dev/null << 'EOF'
[Unit]
Description=DevOps Fetch Service

[Service]
ExecStart=/usr/local/bin/devopsfetch --monitor
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable, and start the service
sudo systemctl daemon-reload
sudo systemctl enable devopsfetch
sudo systemctl start devopsfetch

# Start Nginx service after the installation is complete
sudo systemctl start nginx

echo "Installation complete. Use 'devopsfetch -h' for usage information."
```

## Usage

- **Help:**
  ```
  devopsfetch -h
  ```
  Displays usage instructions and available options.

- **Monitor Mode:**
  - Continuously monitor and log activities to `/var/log/devopsfetch.log`.
  ```
  devopsfetch --monitor
  ```

## Logging

- The logs are continuously written to `/var/log/devopsfetch.log`.
- Ensure log rotation and management to avoid excessive disk usage.

---

This concise documentation provides all necessary details to install, configure, and use `devopsfetch` for comprehensive server information retrieval and monitoring.
