# Forever Note

**One note. One shortcut. Always there.**

A tiny macOS menu-bar notepad. Press ⌘E anywhere, jot something down, press ⌘E again. It's saved, and it's still there next time. No windows, no files, no accounts, no sync.

https://github.com/user-attachments/assets/84b1aae5-d076-4995-b993-7a394b5d791c

*A new API key that you'll only see once: ⌘E, paste it into the note, ⌘E. A minute later in another app: ⌘E, copy it back out, ⌘E, paste, connected.*

## Why

Notes apps make you create a note, name it, and pick a folder. Most of the time you just need somewhere to drop a code, a link or a snippet *right now*. Forever Note is that one place.

## What you get

- **⌘E from anywhere** opens the note. ⌘E again, Esc or clicking away closes it.
- **Autosaved.** A moment after you stop typing, and again on close and quit. Nothing to save, nothing to lose.
- **Live Markdown.** Headings, bold, italic, code, quotes, lists, `[ ]` tasks and links are styled as you type. The text stays plain Markdown.
- **Typed verbatim.** No smart quotes, no autocorrect. Fine for IDs, tokens and commands.
- **Small.** Under 1 MB, no dependencies, no network, no telemetry.

Your note is one plain-text file you can back up or grep: `~/Library/Application Support/ForeverNote/note.txt`

## Install

**Let an AI assistant walk you through it:** tell Claude, ChatGPT or another assistant
*"Read https://github.com/shuaibird/forever-note/blob/main/INSTALL.md and help me install Forever Note."*
[INSTALL.md](INSTALL.md) gives it step-by-step instructions for both options below.

### Download (prebuilt)

Get `Forever-Note-<version>.zip` from the [latest release](https://github.com/shuaibird/forever-note/releases/latest).
It is a universal app (Apple silicon and Intel) and needs macOS 13 Ventura or later.

1. Double-click the zip to unzip it, then drag **Forever Note.app** into **Applications**.
   Run it from Applications, not from Downloads.
2. Open Forever Note. The first time, macOS blocks it with
   *"Apple could not verify 'Forever Note' is free of malware…"*. Click **Done**.
3. Open **System Settings → Privacy & Security**, scroll down to **Security**, and click
   **Open Anyway** next to "Forever Note was blocked…". Confirm with **Open Anyway** and your
   login password. The button only appears for about an hour after the blocked launch;
   if it's gone, open the app again first.

   Or, in Terminal, after moving the app to Applications:

   ```sh
   xattr -dr com.apple.quarantine "/Applications/Forever Note.app"
   ```

Forever Note then lives in the menu bar (it has no Dock icon).

**Why the warning?** Forever Note is open source and each release is built by GitHub Actions
from the tagged source, but it isn't signed with an Apple Developer ID or notarized by Apple,
so macOS warns about it like any such app downloaded from the internet. (On macOS 15 and
later, Control-click → Open no longer skips this.) If you'd rather not trust a prebuilt
binary, [build it yourself](#build-from-source).

**Verify the download** (optional): download the matching `.sha256` file to the same folder, then

```sh
cd ~/Downloads && shasum -a 256 -c Forever-Note-<version>.zip.sha256
```

**Updating:** quit Forever Note (right-click the menu-bar icon → **Quit**), replace the app in
Applications with the new one, and repeat the Open Anyway step. Your note is kept.

### Build from source

Needs macOS 13+ and the Xcode command line tools (`xcode-select --install`).

```sh
git clone https://github.com/shuaibird/forever-note.git
cd forever-note
./build.sh install   # builds, copies to /Applications, launches
```

`./build.sh` alone builds `build/Forever Note.app` without installing. Apps you build yourself
aren't quarantined, so Gatekeeper doesn't block them.

Build options (environment variables for `build.sh`):

| Variable | Default | Effect |
| --- | --- | --- |
| `UNIVERSAL=1` | off | build for arm64 and x86_64 |
| `VERSION` | latest `v*` git tag, else `0.0.0-dev` | `CFBundleShortVersionString` |
| `CODESIGN_IDENTITY` | `-` (ad-hoc) | signing identity |

Right-click the menu-bar icon for **Launch at Login** and **Quit**.

## Releasing

Push a version tag and GitHub Actions builds the universal app, zips it with a SHA-256
checksum, and publishes a release:

```sh
git tag v1.0.0 && git push origin v1.0.0
```

A tag with a suffix (`v1.1.0-beta.1`) becomes a pre-release. Running the workflow by hand
(**Actions → Release → Run workflow**) makes a test build you can download from the run,
without publishing anything.

## Limits

- One note. That's the point.
- The shortcut is fixed to ⌘E. If another app owns it, Forever Note still works from the menu-bar icon.
- Plain text only, no images or sync. Put the note's folder in iCloud/Dropbox yourself if you want that.

## License

[MIT](LICENSE)
