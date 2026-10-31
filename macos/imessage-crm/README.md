# Send texts to the lab CRM

`imessage-crm-sync` runs on the Mac every hour. It copies your iMessage and SMS conversations
with the people on the lab CRM's text list to the Coder workspace, where the CRM's daily refresh
adds them to the outreach CRM page.

```
CRM page (my-texts) ─> daily refresh ─> workspace:/home/coder/lab-crm-texts/allowlist.json
                                                        │ ssh, hourly
Mac: Contacts + Messages (chat.db) <─ imessage-crm-sync ┘
                                   ─> workspace:/home/coder/lab-crm-texts/texts.json ─> next daily refresh ─> CRM page
```

You keep the list on the CRM page: open a person and use the "My texts" panel, or add someone who
isn't in the CRM under About. Each entry is a name, or phone numbers and email addresses. A name
is looked up in your Contacts. The list never goes into this repo. The refresh writes it to the
workspace, and the job reads it from there over SSH.

## What leaves the Mac

- Only conversations that include someone on the list, since 2026-01-01. A group chat counts when
  one listed person is in it.
- People's names, not their phone numbers or email addresses. A sender who isn't in your Contacts
  shows as "someone not in Contacts".
- Text and attachment file names. Reactions and group events, such as a renamed group, stay out.

The CRM page removes phone numbers from the text. Everyone in `board-access@picnic.ai` can read
the page's data, the texts included.

## One-time setup

1. On the Mac, pull this repo and run the installer:

   ```sh
   cd ~/dotfiles && git pull && macos/imessage-crm/install.sh
   ```

   It links the script to `~/.local/bin/imessage-crm-sync`, and installs and starts the
   LaunchAgent `com.user.imessage-crm-sync`.
2. Give Full Disk Access to the two paths the installer prints: `/usr/bin/python3`, and the
   `Python.app` inside the Python it runs. Messages and Contacts keep their databases in
   folders that macOS protects. Use System Settings > Privacy & Security > Full Disk Access >
   +, then press Cmd+Shift+G and paste each path.
3. Run the job once and read its log:

   ```sh
   launchctl kickstart -k gui/$(id -u)/com.user.imessage-crm-sync
   tail ~/Library/Logs/imessage-crm-sync.log
   ```

   Each run logs one line per listed person: how many numbers and addresses it found, and the
   conversations and messages it sent. A name is looked up as written first. When no card has
   it, a card with the same last name and a shortened first name counts: "Paxton Maeder-York"
   finds "Pax Maeder-York", and the log says so. A name that finds no one, or two people, is
   left out and named in the log. Give that entry a phone number on the CRM page.

After the first install, a new shell runs the installer again when a file here changes
(`dotfiles-mac-check` in `zsh-functions`). It never installs the job on its own.

## Notes

- **SSH host.** The job connects to `coder.troy-workspace`. To use another host, write its
  name to `~/.config/imessage-crm/host`.
- **A stopped workspace stays stopped.** `coder ssh` starts a stopped workspace by default.
  The job sets `CODER_SSH_DISABLE_AUTOSTART`, so a run fails while the workspace is stopped,
  and the next run sends everything again.
- **Timing.** A change to the list reaches the Mac after the next morning refresh. The texts
  reach the page at the refresh after that, or when you run the refresh by hand.
- **SMS.** Texts from Android phones reach the Mac only when Text Message Forwarding is on for
  this Mac, in the iPhone's Messages settings. Older history needs Messages in iCloud.
- **Full Disk Access still missing.** The log says "Can't read ... Full Disk Access" after you
  granted both paths. macOS may check the Python binary itself. Add the third path the log
  names, then run the job again.
