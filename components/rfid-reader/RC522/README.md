# RC522 Reader

## How to setup the RC522 RFID reader

1. **You can use the `setup_rc522.sh` script (recommended)** or follow the manual steps:

2. Install Python dependencies
   - `sudo python3 -m pip install -q -r <phoniebox_dir>/components/rfid-reader/RC522/requirements.txt`

3. Configure experimental reader
   - `cd <phoniebox_dir>/scripts`
   - `cp Reader.py.experimental Reader.py`
   - Run `python3 RegisterDevice.py`
   - Select 0 (MFRC522)

4. Restart the phoniebox-rfid-reader service:
   - `sudo systemctl restart phoniebox-rfid-reader.service`

By default Phoniebox uses the RC522 IRQ pin for card detection (on the Raspberry Pi and Zero normally GPIO 24 / physical pin 18). If IRQ is unreliable for your reader or OS/kernel combination, set `pin_irq=` in `settings/rc522.conf` to use polling mode instead.

## Wiring

Wire the RC522 to the Raspberry Pi SPI0 bus. Use 3.3 V only; do not power the RC522 from 5 V.

| RC522 Pin | Raspberry Pi Physical Pin | GPIO / Function |
|---|---:|---|
| `3.3V` | 1 | 3.3 V power |
| `RST` | 22 | GPIO 25 |
| `GND` | 25 | Ground |
| `IRQ` | 18 | GPIO 24 |
| `MISO` | 21 | GPIO 9 / SPI0 MISO |
| `MOSI` | 19 | GPIO 10 / SPI0 MOSI |
| `SCK` | 23 | GPIO 11 / SPI0 SCLK |
| `SDA` / `SS` | 24 | GPIO 8 / SPI0 CE0 |

After enabling SPI, `/dev/spidev0.0` and `/dev/spidev0.1` should exist.

## Setup Steps

Recommended setup:

```bash
cd /home/pi/RPi-Jukebox-RFID
./components/rfid-reader/RC522/setup_rc522.sh
```

If your RC522 reader is unreliable with IRQ or with NTAG-style cards, edit `/home/pi/RPi-Jukebox-RFID/settings/rc522.conf` after running the setup script. For Tonnie-Py, stable full UID reads were achieved by increasing the distance between the tag and reader and using polling mode at `100000` SPI speed:

```ini
speed=100000
pin_irq=
pin_rst=22
remove_after=3.0
partial_uids=
partial_uid_suffix=
```

Then restart the service:

```bash
sudo systemctl restart phoniebox-rfid-reader.service
```

Use the logs to confirm card detection:

```bash
journalctl -u phoniebox-rfid-reader -f
```

## Recreate the Tonnie-Py NTAG Setup

These are the exact steps used for the Tonnie-Py build with an RC522 reader and ISO14443A / NTAG-style cards.

1. Install this fork and branch:

```bash
cd
rm -f install-jukebox.sh
wget https://raw.githubusercontent.com/jacques20/RPi-Jukebox-RFID/rc522-ntag-place-mode-fix/scripts/installscripts/install-jukebox.sh
chmod +x install-jukebox.sh
GIT_URL=https://github.com/jacques20/RPi-Jukebox-RFID.git GIT_BRANCH=rc522-ntag-place-mode-fix bash ./install-jukebox.sh
```

2. Configure RC522 support:

```bash
cd /home/pi/RPi-Jukebox-RFID
./components/rfid-reader/RC522/setup_rc522.sh
```

3. Edit `/home/pi/RPi-Jukebox-RFID/settings/rc522.conf` for the Tonnie-Py card/reader behavior:

```ini
speed=100000
pin_irq=
pin_rst=22
remove_after=3.0
partial_uids=
partial_uid_suffix=
```

The Tonnie-Py root-cause finding was tag/reader coupling distance: when cards were placed too close to the RC522, full UID reads were intermittent. With a larger gap, the RC522 version register stayed stable at `0x82` and full UIDs read repeatedly without `partial_uids` or `partial_uid_suffix`.

4. Set place/remove playback mode so playback pauses when a card is removed:

```bash
printf 'PLACENOTSWIPE' > /home/pi/RPi-Jukebox-RFID/settings/Swipe_or_Place
sudo chown pi:www-data /home/pi/RPi-Jukebox-RFID/settings/Swipe_or_Place
sudo chmod 777 /home/pi/RPi-Jukebox-RFID/settings/Swipe_or_Place
```

5. Restart the services:

```bash
sudo systemctl restart phoniebox-rfid-reader.service
sudo systemctl restart mpd.service
```

6. Verify the reader and playback:

```bash
systemctl status phoniebox-rfid-reader.service
journalctl -u phoniebox-rfid-reader -f
mpc status
```

Expected behavior:

- Placing a mapped card logs `Card detected.` and `Trigger Play Cardid=<card-id>`.
- Keeping the card on the reader keeps playback running.
- Removing the card pauses playback after about `remove_after` seconds.
- If full UID reads are unstable, first adjust the physical card distance from the reader. Use `partial_uids` or `partial_uid_suffix` only as a fallback for hardware/card combinations that cannot be made stable.

Tonnie-Py cards used during testing:

| Card | Card ID | `partial_uids` key |
|---|---|---|
| ABBA | `5365744c030001` | `536574` |
| Queen | `53996b4c030001` | `53996b` |
| Ed Sheeran | `53fa634c030001` | `53fa63` |
| Snow Patrol | `5330414c030001` | `533041` |
| Paramore | `53eb2c4c030001` | `53eb2c` |

### Optional RC522 configuration

The setup script creates `<phoniebox_dir>/settings/rc522.conf` with default values:

```ini
speed=1000000
pin_irq=18
pin_rst=22
remove_after=3.0
partial_uids=
partial_uid_suffix=
```

- `speed` is the SPI speed. Some inexpensive RC522 boards or long jumper wires may require a lower value such as `50000`, `25000`, or `10000`.
- `pin_irq` can be set to an empty value to skip IRQ waiting and use polling mode.
- `pin_rst` is used for a hardware reset pulse when the reader starts.
- `remove_after` controls how long `PLACENOTSWIPE` waits before treating a missing card read as card removal.
- `partial_uids` is an optional comma-separated map for NTAG-style tags that only expose the first UID cascade reliably. Example: `partial_uids=536574:5365744c030001,53996b:53996b4c030001`.
- `partial_uid_suffix` is an optional shared suffix for batches of NTAG-style cards where the first three UID bytes are stable and the remaining bytes are shared. Example: `partial_uid_suffix=4c030001` turns a partial UID `533041` into card ID `5330414c030001`.

When `partial_uids` is used, the first value is the first three UID bytes as hex and the second value is the full card ID you want Phoniebox to use.

## Working cards/tags

Cards or tags must support 13.56 MHz. Currently, only cards/tags of the type "NXP Mifare Classic 1k(S50)", "NXP Mifare Classic 4k(S70)" and "NXP Mifare Ultralight (C)" can be used. Type "NXP Mifare NTAG2xx" will not work!

NTAG2xx support is still experimental. The `partial_uids` fallback may work for UID-only use cases, but MIFARE Classic or MIFARE Ultralight (C) tags remain the recommended option.
