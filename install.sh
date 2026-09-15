#!/usr/bin/env bash
set -e

# Setup interactive terminal input descriptor (FD 3)
# Keeps STDIN (FD 0) clean so curl ... | bash works without hanging!
if [ -c /dev/tty ]; then
    exec 3< /dev/tty
else
    exec 3<&0
fi

# Ensure root / sudo privileges
if [ "$EUID" -ne 0 ]; then
    printf "\e[38;5;196m[!] Error: Please run this script with root or sudo privileges.\e[0m\n"
    exit 1
fi

INSTALL_DIR="/opt/helper-bot"
SERVICE_NAME="helper-bot"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
REPO_URL="https://github.com/Aporis3674/telegram-helper-bot.git"

# ANSI Color definitions (fastfetch inspired)
C_RESET="\e[0m"
C_BOLD="\e[1m"
C_DIM="\e[2m"
C_BLUE="\e[38;5;39m"
C_CYAN="\e[38;5;45m"
C_MAGENTA="\e[38;5;201m"
C_PURPLE="\e[38;5;141m"
C_GREEN="\e[38;5;82m"
C_YELLOW="\e[38;5;220m"
C_RED="\e[38;5;196m"
C_GRAY="\e[38;5;244m"
C_WHITE="\e[38;5;255m"

# System Information detection
get_os_info() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$PRETTY_NAME"
    else
        uname -sr
    fi
}

get_python_version() {
    if command -v python3 >/dev/null 2>&1; then
        python3 --version 2>&1 | awk '{print $2}'
    else
        echo "Not installed"
    fi
}

has_systemd() {
    if [ -d /run/systemd/system ] || pidof systemd >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

get_service_status() {
    if has_systemd; then
        if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            echo -e "${C_GREEN}Active (Running)${C_RESET}"
        elif [ -f "$SERVICE_FILE" ]; then
            echo -e "${C_YELLOW}Inactive (Stopped)${C_RESET}"
        else
            echo -e "${C_GRAY}Not Installed${C_RESET}"
        fi
    else
        if pgrep -f "$INSTALL_DIR/bot.py" >/dev/null 2>&1; then
            echo -e "${C_GREEN}Active (Process Running)${C_RESET}"
        else
            echo -e "${C_GRAY}Container (No Systemd)${C_RESET}"
        fi
    fi
}

is_installed() {
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/bot.py" ] && [ -f "$INSTALL_DIR/.env" ]; then
        local token=$(grep "^TELEGRAM_BOT_TOKEN=" "$INSTALL_DIR/.env" 2>/dev/null | cut -d '=' -f2- | tr -d ' "')
        if [ -n "$token" ]; then
            return 0
        fi
    fi
    return 1
}

# Fastfetch style Banner & System Card
draw_header() {
    command -v clear >/dev/null 2>&1 && clear || printf "\033c"

    local os_str=$(get_os_info)
    local py_ver=$(get_python_version)
    local srv_status=$(get_service_status)
    local cur_model="N/A"

    if [ -f "$INSTALL_DIR/.env" ]; then
        cur_model=$(grep "^AI_MODEL=" "$INSTALL_DIR/.env" 2>/dev/null | cut -d '=' -f2- | tr -d '"' || echo "N/A")
        [ -z "$cur_model" ] && cur_model="gpt-4o-mini"
    fi

    printf "${C_CYAN}${C_BOLD}"
    cat << "EOF"
  _  _ _____ _     ___ ___ ___
 | || | ____| |   | _ \ __| _ \
 | __ |  _| | |   |  _/ _||   /
 |_||_|_____|____ |_| |___|_|_\
EOF
    printf "${C_RESET}\n"
    printf "  ${C_BLUE}${C_BOLD}Helper AI Bot${C_RESET} ${C_GRAY}-${C_RESET} ${C_WHITE}Telegram Assistant CLI${C_RESET}\n"
    printf "  ${C_GRAY}--------------------------------------------------${C_RESET}\n"
    printf "  ${C_CYAN}%-14s${C_RESET} : ${C_WHITE}%s${C_RESET}\n" "OS" "$os_str"
    printf "  ${C_CYAN}%-14s${C_RESET} : ${C_WHITE}%s${C_RESET}\n" "Kernel" "$(uname -r)"
    printf "  ${C_CYAN}%-14s${C_RESET} : ${C_WHITE}%s${C_RESET}\n" "Python" "$py_ver"
    printf "  ${C_CYAN}%-14s${C_RESET} : ${C_WHITE}%s${C_RESET}\n" "Directory" "$INSTALL_DIR"
    printf "  ${C_CYAN}%-14s${C_RESET} : %b\n" "Service" "$srv_status"
    if is_installed; then
        printf "  ${C_CYAN}%-14s${C_RESET} : ${C_WHITE}%s${C_RESET}\n" "AI Model" "$cur_model"
    fi
    printf "  ${C_GRAY}--------------------------------------------------${C_RESET}\n"
    # Fastfetch color palette squares
    printf "  \e[48;5;0m   \e[48;5;1m   \e[48;5;2m   \e[48;5;3m   \e[48;5;4m   \e[48;5;5m   \e[48;5;6m   \e[48;5;7m   \e[0m\n"
    printf "  \e[48;5;8m   \e[48;5;9m   \e[48;5;10m   \e[48;5;11m   \e[48;5;12m   \e[48;5;13m   \e[48;5;14m   \e[48;5;15m   \e[0m\n\n"
}

# Interactive Arrow-Navigation Menu
menu_select() {
    local prompt="$1"
    shift
    local options=("$@")
    local cur=0
    local count=${#options[@]}
    local key=""

    trap 'printf "\e[?25h"; exit 0' INT TERM

    printf "\e[?25l" # Hide cursor

    printf "  ${C_BOLD}%s${C_RESET} ${C_GRAY}(Use UP/DOWN arrows, press ENTER to select):${C_RESET}\n\n" "$prompt"

    while true; do
        for ((i=0; i<count; i++)); do
            if [ $i -eq $cur ]; then
                printf "\e[2K  ${C_BLUE}${C_BOLD}> [x] %s${C_RESET}\n" "${options[$i]}"
            else
                printf "\e[2K  ${C_GRAY}  [ ] %s${C_RESET}\n" "${options[$i]}"
            fi
        done

        # Read keystroke from FD 3 (terminal tty)
        IFS= read -u 3 -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -u 3 -rsn2 -t 0.1 rest || true
            key+="$rest"
        fi

        case "$key" in
            $'\x1b[A'|$'\x1bOA'|"k"|"K") # UP
                cur=$(( (cur - 1 + count) % count ))
                ;;
            $'\x1b[B'|$'\x1bOB'|"j"|"J") # DOWN
                cur=$(( (cur + 1) % count ))
                ;;
            ""|$'\n'|$'\r') # ENTER
                printf "\e[?25h" # Restore cursor
                SELECTED_INDEX=$cur
                return 0
                ;;
            "q"|"Q")
                printf "\e[?25h"
                SELECTED_INDEX=$((count - 1))
                return 0
                ;;
        esac

        # Move cursor back up count lines
        printf "\e[%dA" "$count"
    done
}

# Action: Install
do_install() {
    printf "\n${C_BLUE}${C_BOLD}=== Starting Installation ===${C_RESET}\n\n"

    printf "${C_CYAN}[1/5]${C_RESET} Updating apt repositories and installing packages...\n"
    apt-get update -y
    apt-get install -y python3 python3-pip python3-venv curl git

    printf "\n${C_CYAN}[2/5]${C_RESET} Downloading repository into ${C_WHITE}%s${C_RESET}...\n" "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    if [ -d "$INSTALL_DIR/.git" ]; then
        cd "$INSTALL_DIR"
        git fetch --all
        git reset --hard origin/main || true
    elif [ -f "$INSTALL_DIR/bot.py" ]; then
        cd "$INSTALL_DIR"
    else
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
    cd "$INSTALL_DIR"

    printf "\n${C_CYAN}[3/5]${C_RESET} Setting up Python virtual environment...\n"
    python3 -m venv venv
    "$INSTALL_DIR/venv/bin/pip" install --upgrade pip
    "$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"

    printf "\n${C_CYAN}[4/5]${C_RESET} Configuring environment credentials...\n"
    read -u 3 -p "  Enter Telegram Bot Token: " TG_TOKEN
    read -u 3 -p "  Enter AI Endpoint URL [Default: https://api.openai.com/v1]: " AI_BASE_URL
    AI_BASE_URL=${AI_BASE_URL:-"https://api.openai.com/v1"}
    read -u 3 -p "  Enter AI API Key: " AI_KEY
    read -u 3 -p "  Enter AI Model [Default: gpt-4o-mini]: " AI_MODEL
    AI_MODEL=${AI_MODEL:-"gpt-4o-mini"}

    cat <<EOF > "$INSTALL_DIR/.env"
TELEGRAM_BOT_TOKEN=$TG_TOKEN
AI_API_KEY=$AI_KEY
AI_BASE_URL=$AI_BASE_URL
AI_MODEL=$AI_MODEL
EOF
    chmod 600 "$INSTALL_DIR/.env"

    printf "\n${C_CYAN}[5/5]${C_RESET} Registering and starting background service...\n"
    if has_systemd; then
        cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Telegram Helper AI Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/bot.py
Restart=always
RestartSec=5
EnvironmentFile=$INSTALL_DIR/.env

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable "$SERVICE_NAME"
        systemctl restart "$SERVICE_NAME"

        printf "\n${C_GREEN}${C_BOLD}[+] Helper Bot successfully installed and started!${C_RESET}\n"
        printf "    Status: systemctl status %s\n" "$SERVICE_NAME"
        printf "    Logs  : journalctl -u %s -f\n\n" "$SERVICE_NAME"
    else
        pkill -f "$INSTALL_DIR/bot.py" 2>/dev/null || true
        nohup "$INSTALL_DIR/venv/bin/python3" "$INSTALL_DIR/bot.py" > "$INSTALL_DIR/bot.log" 2>&1 &
        printf "\n${C_GREEN}${C_BOLD}[+] Helper Bot started in background (PID: $!)!${C_RESET}\n"
        printf "    Logs  : tail -f %s/bot.log\n\n" "$INSTALL_DIR"
    fi
}

# Action: Update
do_update() {
    printf "\n${C_BLUE}${C_BOLD}=== Updating Helper Bot ===${C_RESET}\n\n"
    if [ ! -d "$INSTALL_DIR" ]; then
        printf "${C_RED}[!] Error: Installation directory not found.${C_RESET}\n"
        return 1
    fi

    cd "$INSTALL_DIR"
    printf "${C_CYAN}[*]${C_RESET} Pulling latest source code from GitHub...\n"
    git fetch --all
    git reset --hard origin/main

    printf "${C_CYAN}[*]${C_RESET} Updating Python dependencies...\n"
    "$INSTALL_DIR/venv/bin/pip" install --upgrade pip
    "$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"

    printf "${C_CYAN}[*]${C_RESET} Restarting service...\n"
    if has_systemd; then
        systemctl restart "$SERVICE_NAME"
    else
        pkill -f "$INSTALL_DIR/bot.py" 2>/dev/null || true
        nohup "$INSTALL_DIR/venv/bin/python3" "$INSTALL_DIR/bot.py" > "$INSTALL_DIR/bot.log" 2>&1 &
    fi

    printf "\n${C_GREEN}${C_BOLD}[+] Helper Bot has been updated and restarted successfully!${C_RESET}\n\n"
}

# Action: Reconfigure
do_reconfigure() {
    printf "\n${C_BLUE}${C_BOLD}=== Reconfigure Environment Settings ===${C_RESET}\n\n"
    local old_token=""
    local old_key=""
    local old_base="https://api.openai.com/v1"
    local old_model="gpt-4o-mini"

    if [ -f "$INSTALL_DIR/.env" ]; then
        old_token=$(grep "^TELEGRAM_BOT_TOKEN=" "$INSTALL_DIR/.env" | cut -d '=' -f2- || true)
        old_key=$(grep "^AI_API_KEY=" "$INSTALL_DIR/.env" | cut -d '=' -f2- || true)
        old_base=$(grep "^AI_BASE_URL=" "$INSTALL_DIR/.env" | cut -d '=' -f2- || true)
        old_model=$(grep "^AI_MODEL=" "$INSTALL_DIR/.env" | cut -d '=' -f2- || true)
        [ -z "$old_base" ] && old_base="https://api.openai.com/v1"
        [ -z "$old_model" ] && old_model="gpt-4o-mini"
    fi

    printf "  Press ENTER to keep existing values in [brackets].\n\n"
    read -u 3 -p "  Telegram Bot Token [${old_token:0:8}...]: " NEW_TOKEN
    NEW_TOKEN=${NEW_TOKEN:-"$old_token"}

    read -u 3 -p "  AI Endpoint URL [$old_base]: " NEW_BASE
    NEW_BASE=${NEW_BASE:-"$old_base"}

    read -u 3 -p "  AI API Key [${old_key:0:8}...]: " NEW_KEY
    NEW_KEY=${NEW_KEY:-"$old_key"}

    read -u 3 -p "  AI Model [$old_model]: " NEW_MODEL
    NEW_MODEL=${NEW_MODEL:-"$old_model"}

    cat <<EOF > "$INSTALL_DIR/.env"
TELEGRAM_BOT_TOKEN=$NEW_TOKEN
AI_API_KEY=$NEW_KEY
AI_BASE_URL=$NEW_BASE
AI_MODEL=$NEW_MODEL
EOF
    chmod 600 "$INSTALL_DIR/.env"

    if has_systemd; then
        systemctl restart "$SERVICE_NAME"
    else
        pkill -f "$INSTALL_DIR/bot.py" 2>/dev/null || true
        nohup "$INSTALL_DIR/venv/bin/python3" "$INSTALL_DIR/bot.py" > "$INSTALL_DIR/bot.log" 2>&1 &
    fi
    printf "\n${C_GREEN}${C_BOLD}[+] Configuration updated and service restarted!${C_RESET}\n\n"
}

# Action: Restart
do_restart() {
    printf "\n${C_CYAN}[*]${C_RESET} Restarting %s...\n" "$SERVICE_NAME"
    if has_systemd; then
        systemctl restart "$SERVICE_NAME"
        sleep 1
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            printf "${C_GREEN}${C_BOLD}[+] Service is active and running.${C_RESET}\n\n"
        else
            printf "${C_RED}[!] Warning: Service failed to start. Run journalctl -u %s -f to view errors.${C_RESET}\n\n" "$SERVICE_NAME"
        fi
    else
        pkill -f "$INSTALL_DIR/bot.py" 2>/dev/null || true
        nohup "$INSTALL_DIR/venv/bin/python3" "$INSTALL_DIR/bot.py" > "$INSTALL_DIR/bot.log" 2>&1 &
        printf "${C_GREEN}${C_BOLD}[+] Process restarted in background.${C_RESET}\n\n"
    fi
}

# Action: View Status & Logs
do_status_logs() {
    printf "\n${C_BLUE}${C_BOLD}=== Service Status ===${C_RESET}\n"
    if has_systemd; then
        systemctl status "$SERVICE_NAME" --no-pager || true
        printf "\n${C_BLUE}${C_BOLD}=== Recent Logs (Last 20 lines) ===${C_RESET}\n"
        journalctl -u "$SERVICE_NAME" -n 20 --no-pager || true
    else
        if pgrep -f "$INSTALL_DIR/bot.py" >/dev/null 2>&1; then
            printf "Process: Running (PID: $(pgrep -f "$INSTALL_DIR/bot.py" | tr '\n' ' '))\n"
        else
            printf "Process: Stopped\n"
        fi
        if [ -f "$INSTALL_DIR/bot.log" ]; then
            printf "\n${C_BLUE}${C_BOLD}=== Log file output ===${C_RESET}\n"
            tail -n 20 "$INSTALL_DIR/bot.log"
        fi
    fi
    printf "\n"
}

# Action: Uninstall
do_uninstall() {
    printf "\n${C_YELLOW}${C_BOLD}=== Uninstall Helper Bot ===${C_RESET}\n"
    read -u 3 -p "  Are you sure you want to completely remove Helper Bot? (y/N): " CONFIRM
    if [[ "$CONFIRM" =~ ^[yY]$ ]]; then
        printf "${C_CYAN}[*]${C_RESET} Stopping and disabling service...\n"
        if has_systemd; then
            systemctl stop "$SERVICE_NAME" 2>/dev/null || true
            systemctl disable "$SERVICE_NAME" 2>/dev/null || true
            rm -f "$SERVICE_FILE"
            systemctl daemon-reload
        else
            pkill -f "$INSTALL_DIR/bot.py" 2>/dev/null || true
        fi

        printf "${C_CYAN}[*]${C_RESET} Removing project files in %s...\n" "$INSTALL_DIR"
        rm -rf "$INSTALL_DIR"

        printf "${C_GREEN}${C_BOLD}[+] Helper Bot has been completely removed from this server.${C_RESET}\n\n"
    else
        printf "  Uninstallation canceled.\n\n"
    fi
}

# Main Execution Flow
main() {
    draw_header

    if is_installed; then
        # Menu for installed systems
        options=(
            "Update Bot (Pull latest code and restart)"
            "Reconfigure Settings (Edit API keys and model)"
            "Restart Service"
            "View Status & Logs"
            "Uninstall Bot"
            "Exit"
        )
        menu_select "Helper Bot is installed. Choose an action" "${options[@]}"

        case $SELECTED_INDEX in
            0) do_update ;;
            1) do_reconfigure ;;
            2) do_restart ;;
            3) do_status_logs ;;
            4) do_uninstall ;;
            5) printf "  Exiting.\n\n"; exit 0 ;;
        esac
    else
        # Menu for fresh systems
        options=(
            "Install Helper Bot"
            "Exit"
        )
        menu_select "Helper Bot is not installed. Choose an action" "${options[@]}"

        case $SELECTED_INDEX in
            0) do_install ;;
            1) printf "  Exiting.\n\n"; exit 0 ;;
        esac
    fi
}

main
