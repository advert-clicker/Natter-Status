# Natter

**Private chat for you and your friends.** Everything you write is scrambled on your own device before it leaves it, so even the server only ever sees unreadable data. No email, no phone number, no password: pick a name and you're in.

## Install (Mac and Linux)

Open the **Terminal** app, paste this line, and press Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/advert-clicker/Natter-Status/refs/heads/main/install.sh | bash
```

A friendly installer walks you through four short steps (about a minute) and puts a **Natter** icon on your Desktop. It does not ask for your password in the normal case.

- **Mac:** nothing to approve, and no password. If your Mac doesn't have Python (the small helper Natter needs), the installer quietly adds a private copy of its own, about 25 MB, that only Natter uses. It won't touch your system or ask Apple for anything. If you already have Python, nothing extra is added.
- **Linux:** if Python 3 is missing, the installer asks once for your password (it shows a `•` for every key you type).

To open Natter later, double-click the **Natter** icon. A window opens showing that Natter is running; leave it open while you chat, and press **Ctrl+C** (or close it) to stop. Natter checks for updates every time it starts and installs them by itself.

## Install (Windows)

Press the **Start** button, type **PowerShell**, open it, paste this line and press Enter:

```powershell
irm https://raw.githubusercontent.com/advert-clicker/Natter-Status/refs/heads/main/install.ps1 | iex
```

The installer does the same four short steps and puts a **Natter** icon on your Desktop and in the Start menu. It never needs an administrator password. If your computer has no Python yet, it offers to add it for you (free, and only for your own account).

Prefer to do it by hand? Install [Python 3](https://www.python.org/downloads/) (tick **Add python.exe to PATH**), [download `natter-share.zip`](https://github.com/advert-clicker/Natter-Status/raw/refs/heads/main/natter-share.zip), unzip it, and double-click **`start-windows.bat`** in the `natter` folder.

## First time

Pick a display name and Natter does the rest: it creates your account on the server, gives you a short unique **tag** (like `Jane#A3F9`) that appears next to your name everywhere, and shows your **24-word recovery phrase**. Write that phrase down somewhere safe. It is the only way to get your account back if you lose this computer; nobody, including the server's owner, can recover it for you.

## What the server can and can't see

| The server's owner **can** see | and **cannot** see |
|---|---|
| your display name, tag and friend code | anything you write |
| when you connect, and your IP address | names of channels or spaces |
| which accounts post to the same (scrambled) chat | who is in your spaces, or your friend list |
| roughly how big each message is | your files, pictures or avatars (stored scrambled) |

Your keys and messages are stored in your own browser. If you clear that browser's site data for `localhost:5173`, you lose them, so keep your recovery phrase.

## Uninstall

Delete the **`Natter`** folder in your home folder and the **Natter** shortcut on your Desktop (Linux: also `~/.local/bin/natter` and `~/.local/share/applications/natter.desktop`). To erase your chats from the browser too, clear site data for `localhost:5173`.

## About this repository

This repository is only the **delivery point** for Natter. The files are updated automatically, so please don't edit them by hand.

| File | What it is |
|---|---|
| `install.sh` | the installer for Mac and Linux |
| `install.ps1` | the installer for Windows |
| `natter-share.zip` | the current Natter app |
| `version.txt` | the current version number and the zip's checksum; installed copies use it to update themselves |
| `status.txt` | where the chat server currently lives (line 1: web address, line 2: chat server). The app reads this to find the server |

Natter downloads updates only from this repository and checks each download against the checksum in `version.txt` before installing it.

## Need help?

Add my friend code in Natter (**Add a friend**, then paste it) and send me a message:

```
ncard1.AO17InNpZ24iOiJ5d0lHVXFHT2wzLW9rNUFyemM0ZXQ3anc3SlEteHBrOGhiaHJ3NkQxeDZRIiwiYm94IjoiMHVtanBnNTF2TUtxaUdKV3hqNFV0cndYU2dWTDNqZVBjV0hQQjN0RVZtTSIsImluYm94Ijoibmk1NzVxaXhibXhvdWNoNHpjYjdveXh6aXB2aXptM2dkcCIsInNlcnZlciI6Imh0dHBzOi8vYmVsaWV2ZXMtcmVjcnVpdG1lbnQtdGFja2xlLW1lbW9yeS50cnljbG91ZGZsYXJlLmNvbSIsIm5hbWUiOiJOb2xpIn3hk3p280febuy6b2Ae_Es2D_TCgXhul21Ucg0GBgjur7ddNDg2gSFRXqhAYLIVC_ZOpIWyy9cVsjs1Vm6pKqAJ
```
