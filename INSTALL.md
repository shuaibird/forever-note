# Installing Forever Note: guide for AI assistants

This file is written for an AI assistant (Claude, ChatGPT, Codex, Cursor, …) helping someone
install Forever Note. If you're a person, the [README](README.md#install) has the same steps.

To use it, tell your assistant:

> Read https://github.com/shuaibird/forever-note/blob/main/INSTALL.md and help me install Forever Note.

---

## For the assistant

Forever Note is a macOS menu-bar notepad (no Dock icon): ⌘E opens a single note, ⌘E again
closes it. Repository: `https://github.com/shuaibird/forever-note`. Bundle id:
`com.shuaibird.forevernote`. App name on disk: `Forever Note.app`. Process name: `ForeverNote`.
The note itself is `~/Library/Application Support/ForeverNote/note.txt`.

### Ground rules

- **Explain before you act.** Say what each command does before running it, or before asking
  the user to run it if you can't run commands yourself.
- **Never** disable Gatekeeper system-wide (`spctl --master-disable`, `--global-disable`) and
  never use `sudo`. Neither is needed.
- Removing the quarantine flag from Forever Note is the user's decision. Explain what it means
  (step R4) and get a yes first.
- **Don't touch the note file** (`note.txt`). When updating, it is kept as is. If the user
  wants a backup first: `cp ~/Library/Application\ Support/ForeverNote/note.txt ~/forever-note-backup.txt`.
- If a step fails, show the user the exact error and use [Troubleshooting](#troubleshooting)
  before trying anything else.

### Step 0: check the Mac

```sh
sw_vers -productVersion   # must be 13.0 or later
uname -m                  # arm64 (Apple silicon) or x86_64 (Intel); both are supported
```

If macOS is older than 13, stop: Forever Note won't run there.

### Step 1: pick a path

Ask the user which they want, and recommend the first unless they say otherwise:

1. **Download the release** (recommended for most people): a minute or two, no developer
   tools. macOS shows a one-time "could not verify" warning because the app isn't notarized.
2. **Build from source**: for people who'd rather not run a prebuilt binary or who want to
   change the code. Needs the Xcode command line tools, but there's no Gatekeeper warning.

---

## Path A: download the release

**R1. Download the latest zip and its checksum** into a fresh folder:

```sh
mkdir -p ~/Downloads/forever-note && cd ~/Downloads/forever-note
api=https://api.github.com/repos/shuaibird/forever-note/releases/latest
for url in $(curl -fsSL "$api" | grep -oE '"browser_download_url": *"[^"]+\.zip(\.sha256)?"' | grep -oE 'https://[^"]+'); do
  curl -fLO "$url"
done
ls
```

You should see `Forever-Note-<version>.zip` and `Forever-Note-<version>.zip.sha256`. If the API
is rate-limited or unreachable, have the user download both files by hand from
`https://github.com/shuaibird/forever-note/releases/latest`.

**R2. Verify the checksum:**

```sh
shasum -a 256 -c Forever-Note-*.zip.sha256
```

It must print `OK`. If it doesn't, delete the files and stop; don't install a mismatched zip.

**R3. Unzip and move to Applications.** If Forever Note is already running (updating), quit it
first: right-click the menu-bar icon → **Quit Forever Note**.

```sh
ditto -x -k Forever-Note-*.zip .
rm -rf "/Applications/Forever Note.app"
mv "Forever Note.app" /Applications/
```

The app must run from Applications, not Downloads. (On recent macOS, menu-bar managers such as
Hidden Bar can only keep the icon visible for apps in /Applications.)

**R4. Get past Gatekeeper (one time per version).** Explain first: *the release is built by
GitHub Actions from the public source, but it isn't signed with an Apple Developer ID or
notarized, so macOS blocks the first launch.* Then offer two ways:

- **Terminal (quicker).** With the user's OK:

  ```sh
  xattr -dr com.apple.quarantine "/Applications/Forever Note.app"
  open "/Applications/Forever Note.app"
  ```

- **System Settings (no Terminal).** Walk the user through it:
  1. Open **Forever Note** from Applications. macOS says *"Apple could not verify 'Forever
     Note' is free of malware…"*. Click **Done**.
  2. Open **System Settings → Privacy & Security**, scroll to **Security**, click
     **Open Anyway** next to "Forever Note was blocked…", then confirm with **Open Anyway**
     and the login password.
  3. The button only shows for about an hour after the blocked launch. If it's missing, open
     the app once more and check again.

  On macOS 15 and later, Control-click → Open no longer skips this.

Then continue with [First run](#first-run).

---

## Path B: build from source

**B1. Check the toolchain:**

```sh
xcode-select -p
swiftc --version
```

If `xcode-select -p` fails, the user needs developer tools: `xcode-select --install` (the
Command Line Tools are enough; full Xcode also works). If Xcode was just installed, it may need
its license accepted: open Xcode once.

**B2. Clone, build and install:**

```sh
git clone https://github.com/shuaibird/forever-note.git
cd forever-note
./build.sh install
```

This builds `build/Forever Note.app`, quits any running copy, copies it to `/Applications` and
launches it. Self-built apps aren't quarantined, so there's no Gatekeeper prompt.
`./build.sh` without `install` only builds.

**Updating later:** `git pull && ./build.sh install` from the clone.

Then continue with [First run](#first-run).

---

## First run

Tell the user:

1. Forever Note appears **only in the menu bar** (a small note icon). There's no Dock icon or
   window. If the menu bar is crowded, the icon may be hidden behind the notch or a menu-bar
   manager.
2. Press **⌘E** anywhere to open the note, type, and press **⌘E** again (or Esc, or click
   away) to close it. It saves automatically.
3. To start it at login: right-click the menu-bar icon → **Launch at Login**.

---

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| "Forever Note is damaged and can't be opened" | The zip was unpacked by a tool that broke the signature. Re-download, unzip with Finder or `ditto` (step R3), then do step R4. |
| "Open Anyway" button not in Privacy & Security | It only shows for about an hour after a blocked launch. Open the app again, then look again. |
| Nothing visible after opening | It's a menu-bar app; look for the icon, which can be hidden behind the notch. `pgrep -x ForeverNote` confirms it's running. |
| ⌘E does nothing | Another app owns ⌘E (the shortcut is fixed). Forever Note still opens from its menu-bar icon. Check the log with `log show --last 5m --predicate 'process == "ForeverNote"'` for "Cmd+E is already taken". |
| `swiftc: command not found` / `xcrun: error: invalid active developer path` | Developer tools are missing; see B1. |
| Want to remove it | Quit from the menu, then delete `/Applications/Forever Note.app`. The note stays in `~/Library/Application Support/ForeverNote/` until the user deletes that folder too. |

For anything else, point the user to the
[issue tracker](https://github.com/shuaibird/forever-note/issues) with the macOS version, the
install path they used, and the exact error.
