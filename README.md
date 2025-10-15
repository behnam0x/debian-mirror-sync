# 🌀 Debian Mirror Sync Script

A Bash script for interactive and customizable Debian mirror synchronization using `debmirror`. Supports multiple distributions, suites, and section filtering with lockfile handling and detailed logging.

---

## 🚀 Features

- Interactive distro selection or full automation (`--all`, `--manual`)
- Supports syncing:
  - Base distributions (e.g., `bullseye`, `sid`,`stretch`,`buster`,`bookworm`,`trixie`,`forky`)
  - Security updates
  - Stable updates
  - Backports
- Section filtering: `main`, `contrib`, `non-free`
- Custom mirror URL support
- Lockfile detection and cleanup
- Excludes large desktop environments and multimedia packages
- Logs activity to `/var/log/debmirror-update.log`
- Color-coded terminal output for clarity

---

## 📦 Requirements

- Bash (tested on Debian-based systems)
- `debmirror` installed:
  ```bash
  sudo apt install debmirror


## 📜 License

This project is licensed under the [MIT License](LICENSE).

