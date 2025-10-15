#!/bin/bash                          
# Author: Behnam0x
# diffrent distroes 
# === Configuration ===
ARCH="amd64"                             # Sets architecture to 64-bit Debian packages.
SECTIONS="main"                          # Limits mirror to the 'main' section (free software).
PROTO="http"                             # Uses HTTP protocol for downloading.
HOST="deb.debian.org"                    # Sets the Debian mirror host.
ROOT="/debian"                           # Sets the root path on the mirror server.
MIRROR_DIR="/Debian-Repository"          # Local directory to store mirrored packages.
LOGFILE="/var/log/debmirror-update.log"  # Log file to record update activity.

# === Codename to Version Mapping ===
declare -A DISTRO_MAP=(             # Declares an associative array mapping codenames to versions.
  ["stretch"]="9"                   # Maps 'stretch' to Debian version 9.
  ["buster"]="10"                   # Maps 'buster' to Debian version 10.
  ["bullseye"]="11"                 # Maps 'bullseye' to Debian version 11.
  ["bookworm"]="12"                 # Maps 'bookworm' to Debian version 12.
  ["trixie"]="13"                   # Maps 'trixie' to Debian version 13.
  ["forky"]="14"                    # Maps 'forky' to Debian version 14.
  ["sid"]="unstable"                # Maps 'sid' to the unstable rolling release.
)

# === Color Codes ===
RED='\033[0;31m'                    # ANSI escape code for red text.
GREEN='\033[0;32m'                  # ANSI escape code for green text.
YELLOW='\033[1;33m'                 # ANSI escape code for yellow text.
BLUE='\033[0;34m'                   # ANSI escape code for blue text.
CYAN='\033[0;36m'                   # ANSI escape code for cyan text.
NC='\033[0m'                        # Resets text color to default.


# === Start logging ===
exec > >(tee -a "$LOGFILE") 2>&1  # Redirect output to log file and console
echo -e "${CYAN}🕒 $(date '+%Y-%m-%d %H:%M:%S') — Starting Debian mirror update${NC}"  # Timestamp log start

# === Parse arguments ===
DISTROS=()  # Initialize empty distro list
CUSTOM_MODE=false  # Default to non-custom mode

if [[ "$1" == "--all" ]]; then  # If --all is passed, select all distros
    for DISTRO in "${!DISTRO_MAP[@]}"; do
        DISTROS+=("$DISTRO")
    done
elif [[ "$1" == "--manual" ]]; then  # If --manual is passed, ask for custom mirror
    CUSTOM_MODE=true
    echo -ne "${CYAN}🔗 Enter base mirror URL (e.g. https://mirror.iranserver.com/debian): ${NC}"
    read CUSTOM_URL
    echo -ne "${CYAN}📦 Enter distro codename (e.g. bullseye): ${NC}"
    read CUSTOM_DISTRO
    DISTROS=("$CUSTOM_DISTRO")
    HOST=$(echo "$CUSTOM_URL" | awk -F/ '{print $3}')  # Extract host from URL
    ROOT="/${CUSTOM_URL#*//*/}"  # Extract root path from URL
    PROTO=$(echo "$CUSTOM_URL" | awk -F: '{print $1}')  # Extract protocol from URL
else  # Default interactive mode
    echo -e "${NC}📦 Available Debian distributions:${NC}"
    i=1
    for DISTRO in "${!DISTRO_MAP[@]}"; do  # List available distros
        VERSION="${DISTRO_MAP[$DISTRO]}"
        echo -e "${YELLOW}$i. $DISTRO (Debian $VERSION)${NC}"
        AVAILABLE_DISTROS+=("$DISTRO")
        ((i++))
    done
    echo -ne "${CYAN}👉 Enter the numbers of the distros you want (e.g., 1 3 5): ${NC}"
    read -a SELECTED
    for index in "${SELECTED[@]}"; do  # Add selected distros to list
        DISTROS+=("${AVAILABLE_DISTROS[$((index-1))]}")
    done
fi

# === Ask user which suites to include ===
echo -e "${CYAN}🔧 You can choose additional suites to mirror:${NC}"
echo -ne "${CYAN}🔐 Include security updates? [y/N]: ${NC}"
read INCLUDE_SECURITY
echo -ne "${CYAN}🔄 Include stable updates? [y/N]: ${NC}"
read INCLUDE_UPDATES
echo -ne "${CYAN}📦 Include backports? [y/N]: ${NC}"
read INCLUDE_BACKPORTS

# === Ask user which sections to include ===
echo -e "${CYAN}📦 Choose repository sections:${NC}"
echo -e "${YELLOW}1. main${NC}"
echo -e "${YELLOW}2. main,contrib${NC}"
echo -e "${YELLOW}3. main,contrib,non-free${NC}"
echo -ne "${CYAN}👉 Enter the number of your choice: ${NC}"
read SECTION_CHOICE

case "$SECTION_CHOICE" in  # Set section based on user input
  1) SECTIONS="main" ;;
  2) SECTIONS="main,contrib" ;;
  3) SECTIONS="main,contrib,non-free" ;;
  *) echo -e "${RED}⚠️ Invalid choice. Defaulting to main.${NC}"; SECTIONS="main" ;;
esac

# === Loop through selected distros ===
for DIST in "${DISTROS[@]}"; do
    echo -e "${BLUE}🔄 Syncing $DIST...${NC}"

    SUITES=("$DIST")  # Always include base suite
    [[ "$INCLUDE_SECURITY" =~ ^[Yy]$ ]] && SUITES+=("${DIST}-security")  # Add security suite if selected
    [[ "$INCLUDE_UPDATES" =~ ^[Yy]$ ]] && SUITES+=("${DIST}-updates")  # Add updates suite if selected
    [[ "$INCLUDE_BACKPORTS" =~ ^[Yy]$ ]] && SUITES+=("${DIST}-backports")  # Add backports suite if selected

    for SUITE in "${SUITES[@]}"; do
        TARGET_DIR="$MIRROR_DIR/$SUITE"  # Set local target directory
        LOCKFILE="$TARGET_DIR/Archive-Update-in-Progress-debian"  # Lock file path
        TIMESTAMP_FILE="$TARGET_DIR/.last_update"  # Timestamp file path

        # === Handle lock file ===
        if [ -f "$LOCKFILE" ]; then  # Check if lock file exists
            PID=$(pgrep -f "debmirror.*$SUITE")  # Find running debmirror process
            if [ -z "$PID" ]; then  # If no process found, remove stale lock
                echo -e "${YELLOW}⚠️ Stale lock detected. Removing: $LOCKFILE${NC}"
                rm -f "$LOCKFILE"
            else  # If process is running, ask user to kill it
                echo -e "${YELLOW}⏳ debmirror is running with PID $PID.${NC}"
                echo -ne "${CYAN}❓ Do you want to kill it and continue? [y/N]: ${NC}"
                read CONFIRM
                if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                    echo -e "${RED}🛑 Killing process $PID...${NC}"
                    kill -9 "$PID"
                    rm -f "$LOCKFILE"
                    echo -e "${GREEN}✅ Process killed. Continuing...${NC}"
                else
                    echo -e "${RED}🚫 Aborting as requested.${NC}"
                    continue
                fi
            fi
        fi

        # === Ensure target directory exists ===
        mkdir -p "$TARGET_DIR"  # Create target directory if it doesn't exist

        # === Run debmirror ===
        echo -e "${BLUE}🚀 Running debmirror for $SUITE...${NC}"
        START_TIME=$(date +%s)  # Record start 
		# Start debmirror to sync Debian packages
		debmirror \
			# Specify architecture (e.g., amd64 for 64-bit systems)
			--arch="$ARCH" \
			# Set distribution codename (e.g., bullseye, sid)
			--dist="$SUITE" \
			# Limit to specific repository sections (e.g., main, contrib, non-free)
			--section="$SECTIONS" \
			# Choose protocol for downloading (http, ftp, rsync)
			--method="$PROTO" \
			# Define the mirror host (e.g., deb.debian.org)
			--host="$HOST" \
			# Set root path on the mirror server (usually /debian)
			--root="$ROOT" \
			# Show progress during download
			--progress \
			# Skip GPG signature verification for Release files
			--ignore-release-gpg \
			# Continue even if minor errors occur
			--ignore-small-errors \
			# Exclude source packages (download only binaries)
			--nosource \
			# Download Contents files (lists of files in each package)
			--getcontents \
			# Use passive FTP mode (helps with firewalls)
			--passive \
			# Set rsync timeout to 10 seconds to avoid hanging
			--rsync-options="--timeout=10" \
			# Exclude entire Debian sections like GNOME, KDE, multimedia, games, etc.
			--exclude-deb-section='^gnome$|^kde$|^x11$|^graphics$|^games$|^multimedia$|^video$|^sound$' \
			# Exclude specific packages by name or pattern (e.g., vlc, firefox, libgtk*)
			--exclude='vlc|gimp|pulseaudio|firefox|cheese|totem|rhythmbox|brasero|xserver-xorg|libgtk*|libqt*' \
			# Set local directory to store mirrored packages
		"$TARGET_DIR"


        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ debmirror completed successfully...${NC}"  # Success message.
            END_TIME=$(date +%s)         # Records end time.
            DURATION=$((END_TIME - START_TIME))  # Calculates duration.
            DISK_USAGE=$(du -sh "$TARGET_DIR" 2>/dev/null | cut -f1)  # Gets disk usage.
            echo -e "${CYAN}📊 Duration: ${DURATION}s | Disk usage: $DISK_USAGE${NC}"  # Logs stats.
            echo "$(date +%s)" > "$TIMESTAMP_FILE"  # Updates timestamp file.
        else
            echo -e "${RED}❌ debmirror failed for $SUITE...${NC}"  # Logs failure.
        fi

        echo -e "${BLUE}-----------------------------${NC}"  # Separator line.
    done
done

echo -e "${GREEN}🏁 All selected distributions processed.${NC}"  # Final success message.
