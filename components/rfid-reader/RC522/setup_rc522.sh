#!/usr/bin/env bash

HOME_DIR="/home/pi"
JUKEBOX_HOME_DIR="${HOME_DIR}/RPi-Jukebox-RFID"

question() {
    local question=$1
    read -p "${question} (Y/n)? " choice
    case "$choice" in
      [nN][oO]|[nN]) exit 0;;
      * ) ;;
    esac
}

printf "Please make sure that the RC522 reader is wired up correctly to the GPIO ports before continuing...\n"
question "Continue"

printf "Use backward-compatible card ID (not suggested for new installations)?\n"
read -p "(y/N) " choice
case "$choice" in
  y|Y ) printf "OFF" > "${JUKEBOX_HOME_DIR}"/settings/Rfidreader_Rc522_Readmode_UID;;
  * ) printf "ON" > "${JUKEBOX_HOME_DIR}"/settings/Rfidreader_Rc522_Readmode_UID;;
esac

printf "Installing Python requirements for RC522...\n"
sudo python3 -m pip install --upgrade --force-reinstall --no-deps -q -r "${JUKEBOX_HOME_DIR}"/components/rfid-reader/RC522/requirements.txt

printf "Activating SPI...\n"
sudo raspi-config nonint do_spi 0

printf "Configure RFID reader in Phoniebox...\n"
cp "${JUKEBOX_HOME_DIR}"/scripts/Reader.py.experimental "${JUKEBOX_HOME_DIR}"/scripts/Reader.py
if [ ! -f "${JUKEBOX_HOME_DIR}"/settings/rc522.conf ]; then
  cat > "${JUKEBOX_HOME_DIR}"/settings/rc522.conf <<'EOF'
# RC522 reader options.
# Pin numbers use physical board numbering to match pi-rc522 defaults.
speed=1000000
pin_irq=18
pin_rst=22
remove_after=3.0
# Optional comma-separated partial UID fallbacks for NTAG-style tags.
# Format: first-three-uid-bytes-as-hex:full-card-id
# Example: partial_uids=536574:5365744c030001,53996b:53996b4c030001
partial_uids=
# Optional suffix for NTAG-style tags from the same batch where the first
# three UID bytes are stable but the remaining bytes are shared.
# Example: partial_uid_suffix=4c030001
partial_uid_suffix=
EOF
fi
printf "MFRC522" > "${JUKEBOX_HOME_DIR}"/scripts/deviceName.txt
sudo chown pi:www-data "${JUKEBOX_HOME_DIR}"/scripts/deviceName.txt "${JUKEBOX_HOME_DIR}"/settings/rc522.conf
sudo chmod 644 "${JUKEBOX_HOME_DIR}"/scripts/deviceName.txt "${JUKEBOX_HOME_DIR}"/settings/rc522.conf

printf "Restarting phoniebox-rfid-reader service...\n"
sudo systemctl restart phoniebox-rfid-reader.service

printf "Done.\n"
