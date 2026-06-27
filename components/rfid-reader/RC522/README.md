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

### Optional RC522 configuration

The setup script creates `<phoniebox_dir>/settings/rc522.conf` with default values:

```ini
speed=1000000
pin_irq=18
pin_rst=22
remove_after=3.0
partial_uids=
```

- `speed` is the SPI speed. Some inexpensive RC522 boards or long jumper wires may require a lower value such as `50000`, `25000`, or `10000`.
- `pin_irq` can be set to an empty value to skip IRQ waiting and use polling mode.
- `pin_rst` is used for a hardware reset pulse when the reader starts.
- `remove_after` controls how long `PLACENOTSWIPE` waits before treating a missing card read as card removal.
- `partial_uids` is an optional comma-separated map for NTAG-style tags that only expose the first UID cascade reliably. Example: `partial_uids=536574:5365744c030001,53996b:53996b4c030001`.

When `partial_uids` is used, the first value is the first three UID bytes as hex and the second value is the full card ID you want Phoniebox to use.

## Working cards/tags

Cards or tags must support 13.56 MHz. Currently, only cards/tags of the type "NXP Mifare Classic 1k(S50)", "NXP Mifare Classic 4k(S70)" and "NXP Mifare Ultralight (C)" can be used. Type "NXP Mifare NTAG2xx" will not work!

NTAG2xx support is still experimental. The `partial_uids` fallback may work for UID-only use cases, but MIFARE Classic or MIFARE Ultralight (C) tags remain the recommended option.
