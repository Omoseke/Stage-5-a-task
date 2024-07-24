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
    }' | sed 's/^users://; s/[(,].*//' | while read -r line; do
        service=$(echo "$line" | awk '{print $1}')
        port=$(echo "$line" | awk '{print $2}')
        print_table_row "$service" "$port"
    done
    print_table_footer
}

get_docker_images() {
    printf "┌───────────────────────┬───────────────┬───────────────┐\n"
    printf "│ REPOSITORY            │ TAG           │ IMAGE ID      │\n"
    printf "├───────────────────────┼───────────────┼───────────────┤\n"
    docker images --format "{{.Repository}}│ {{.Tag}}│ {{.ID}}" | \
        while IFS='│' read -r repo tag id; do
            printf "│ %-21s │ %-13s │ %-13s │\n" "$repo" "$tag" "$id"
        done
    printf "└───────────────────────┴───────────────┴───────────────┘\n"
}

get_docker_container_info() {
    docker inspect "$1"
}

get_nginx_domains() {
    sudo nginx -T | grep -E 'server_name|listen'
}

get_nginx_domain_info() {
    sudo nginx -T | awk -v domain="$1" '/server_name/ {flag=0} /server_name '"$domain"'/ {flag=1} flag'
}

get_user_logins() {
    lastlog
}

get_user_info() {
    lastlog -u "$1"
}

get_logs() {
    journalctl --since "$1" --until "$2"
}

monitor_mode() {
    while true; do
        {
            echo "=== Active Ports ==="
            get_active_ports
            echo
            echo "=== Docker Images ==="
            get_docker_images
            echo
            echo "=== Nginx Domains ==="
            get_nginx_domains
            echo
            echo "=== User Logins ==="
            get_user_logins
            echo
        } >> /var/log/devopsfetch.log
        sleep 60
    done
}

show_help() {
    printf "┌─────────────────────────────────────────────────────────────────────────────┐\n"
    printf "│ Usage: devopsfetch [options]                                                │\n"
    printf "│ Options:                                                                    │\n"
    printf "│   -p, --port [PORT]       Display active ports                              │\n"
    printf "│   -d, --docker [CONTAINER] Display Docker images                            │\n"
    printf "│   -n, --nginx [DOMAIN]    Display Nginx domains                             │\n"
    printf "│   -u, --users [USER]      Display user logins a specific user               │\n"
    printf "│   -t, --time START END    Display logs within a specified time range        │\n"
    printf "│   --monitor               Run in continuous monitoring mode                 │\n"
    printf "│   -h, --help              Display this help message                         │\n"
    printf "└─────────────────────────────────────────────────────────────────────────────┘\n"
}

case "$1" in
    -p|--port)
        if [ -z "$2" ]; then
            get_active_ports
        else
            get_port_info "$2"
        fi
        ;;
    -d|--docker)
        if [ -z "$2" ]; then
            get_docker_images
        else
            get_docker_container_info "$2"
        fi
        ;;
    -n|--nginx)
        if [ -z "$2" ]; then
            get_nginx_domains
        else
            get_nginx_domain_info "$2"
        fi
        ;;
    -u|--users)
        if [ -z "$2" ]; then
            get_user_logins
        else
            get_user_info "$2"
        fi
        ;;
    -t|--time)
        get_logs "$2" "$3"
        ;;
    --monitor)
        monitor_mode
        ;;
    -h|--help)
        show_help
        ;;
    *)
        show_help
        ;;
esac
EOF

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

