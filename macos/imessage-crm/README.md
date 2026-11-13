# Send texts to the lab CRM

`imessage-crm-sync` runs on the Mac every hour, as two jobs. It copies your iMessage, SMS and WhatsApp
conversations with the people on the lab CRM's text list to the Coder workspace, where the CRM's
refresh adds them to the outreach CRM page.

```
CRM page (my-texts) ─> refresh ─> workspace:/home/coder/lab-crm-texts/allowlist.json
                                                │ ssh: transfer job (no Full Disk Access)
                                                v
                                 Mac: ~/.cache/imessage-crm/allowlist.json
                                                │
Contacts + Messages (chat.db)  ─> reader job (Full Disk Access) ─> ~/.cache/imessage-crm/out/texts.json
+ WhatsApp (ChatStorage.sqlite)                                                │ ssh: transfer job
                                                                               v
                                 workspace:/home/coder/lab-crm-texts/texts.json ─> next refresh ─> CRM page
```

You keep the list on the CRM page: open a person and use the "My texts" panel, or add someone who
isn't in the CRM under About. Each entry is a name, or phone numbers and email addresses. A name
is looked up in your Contacts. The list never goes into this repo. The refresh writes it to the
workspace, and the transfer job copies it to the Mac over SSH.

## What leaves the Mac

- Only conversations that include someone on the list, since 2026-01-01.
- A group chat only when everyone else in it is on the list or one of the Picnic people the list
  names (set in the CRM's `texts.py`), or when the CRM page names
  the group under "Group chats to include". The log names each group chat left out, with an id
  you can give the page. The page gets the id and the number of members, not the chat's name,
  because anyone in the chat can choose the name and the CRM's agents read what the page holds.
- People's names, not their phone numbers or email addresses.
- Text and attachment file names. Reactions and group events, such as a renamed group, stay out.
  A WhatsApp photo, video, voice message or document goes as that word, without the file.
- Suggestions: for each other person in the CRM whom your Contacts, Messages and WhatsApp show you
  texting, how many texts and group chats, and the date of the last text. Nothing they wrote.
  The CRM page lists them under About, with an Add button.

The CRM page removes phone numbers from the text. Everyone the page is shared with can read
the page's data, the texts included.

## Two jobs, and who has Full Disk Access

Messages, Contacts and WhatsApp keep their databases in folders that macOS protects, so reading
them needs Full Disk Access. macOS checks that grant against the program launchd starts, and every
process that program starts inherits it. A grant to `/usr/bin/python3` would therefore cover any
script that any LaunchAgent runs with it. So the sync is two LaunchAgents:

- **The reader**, `com.user.imessage-crm-read`, every hour. launchd starts
  `/usr/local/libexec/imessage-crm/imessage-crm-read`, a small launcher built from `launcher.c`. It
  runs one script, a root-owned copy of `imessage-crm-sync`, with a fixed command line and
  environment, and refuses to run if that copy or a folder above it isn't root's alone. Only the
  launcher has Full Disk Access. The reader writes `~/.cache/imessage-crm/out/texts.json` and runs
  no other program.
- **The transfer job**, `com.user.imessage-crm-sync`, every hour and whenever the reader writes.
  It runs this folder's script through `~/.local/bin/imessage-crm-sync`, without Full Disk Access.
  It sends the reader's export to the workspace and copies the text list back. It is the only job
  that runs `ssh`, because `ssh` runs the commands `~/.ssh/config` names, and anything running as
  you can change those.

So `git pull` changes the transfer job at once, and the reader only when you run
`install-reader.sh`. Code running as you can still start the reader with a list of its own and read
the export: your texts since 2026-01-01 with whoever it lists. It can't use the grant for anything
else.

## One-time setup

1. On the Mac, pull this repo and run both installers:

   ```sh
   cd ~/dotfiles && git pull && macos/imessage-crm/install-reader.sh
   ```

   `install-reader.sh` builds and signs the launcher, and copies it and the script into
   `/usr/local/libexec/imessage-crm`, which asks for your password. Then it runs `install.sh`,
   which links the script to `~/.local/bin/imessage-crm-sync` and loads both LaunchAgents.
2. Give the launcher Full Disk Access, and take it away from Python, as the installer prints: System
   Settings > Privacy & Security > Full Disk Access. Press +, then Cmd+Shift+G, and paste
   `/usr/local/libexec/imessage-crm/imessage-crm-read`. Select `python3` and `Python` and press -.
3. Run the reader once and read the log:

   ```sh
   launchctl kickstart -k gui/$(id -u)/com.user.imessage-crm-read
   sleep 30; tail -30 ~/Library/Logs/imessage-crm-sync.log
   ```

   Each reader run logs one line per listed person: how many numbers and addresses it found, and
   the conversations and messages it read. A name is looked up as written first. When no card has
   it, a card with the same last name and a shortened first name counts: "Alexandra Doe"
   finds "Alex Doe", and the log says so. A name that finds no one, or two people, is
   left out and named in the log. Give that entry a phone number on the CRM page. After the
   people, the log lists the group chats left out and the suggestions. Then the transfer job logs
   that it sent the export.

After the first install, a new shell runs `install.sh` again when a file here changes
(`dotfiles-mac-check` in `zsh-functions`). It never installs the jobs on its own, and it never
updates the reader: when the reader's copy is older than this folder, it says to run
`install-reader.sh`. Run that only after you have read the change, because the reader runs with
Full Disk Access. When `launcher.c` changed, the new launcher needs Full Disk Access again.

## Notes

- **SSH host.** The transfer job connects to `coder.troy-workspace`. To use another host, write its
  name to `~/.config/imessage-crm/host`.
- **A stopped workspace stays stopped.** `coder ssh` starts a stopped workspace by default.
  The transfer job sets `CODER_SSH_DISABLE_AUTOSTART`, so a run fails while the workspace is
  stopped, and the next run sends the newest export.
- **Timing.** A change to the list reaches the Mac after the next refresh pass. The texts
  reach the page at the pass after that, or when you run the refresh by hand.
- **WhatsApp.** The reader reads the database of the WhatsApp desktop app, in
  `~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared`. Without the app, it sends
  iMessage and SMS only. The database holds what the app synced from your phone, so open the app
  now and then. A person's WhatsApp chat is its own conversation in the CRM, apart from their
  iMessage and SMS chat. WhatsApp names many people by a private id in place of a phone number.
  The reader finds the number in WhatsApp's own contacts, or takes the Contacts card that alone has
  the name WhatsApp shows. The log's "WhatsApp:" line counts each kind. A person matched to no one
  counts as not on the list. WhatsApp does not document its database. When an update changes it,
  the log says the database "did not read as expected", and iMessage and SMS still go.
- **SMS.** Texts from Android phones reach the Mac only when Text Message Forwarding is on for
  this Mac, in the iPhone's Messages settings. Older history needs Messages in iCloud.
- **Full Disk Access missing.** The log says "Can't read ... Full Disk Access". Check that
  `imessage-crm-read` is in the Full Disk Access list and switched on. If `launcher.c` changed
  since you added it, remove it with - and add it again. Start the reader with `launchctl
  kickstart`, not from a terminal: a program started from a terminal gets the terminal's access.
