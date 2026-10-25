# Forever Note

**One note. One shortcut. Always there.**

A tiny macOS menu-bar notepad. Press ⌘E anywhere, jot something down, press ⌘E again. It's saved, and it's still there next time. No windows, no files, no accounts, no sync.

## Why

Notes apps make you create a note, name it, and pick a folder. Most of the time you just need somewhere to drop a code, a link or a snippet *right now*. Forever Note is that one place.

## What you get

- **⌘E from anywhere** opens the note. ⌘E again, Esc or clicking away closes it.
- **Autosaved.** A moment after you stop typing, and again on close and quit. Nothing to save, nothing to lose.
- **Live Markdown.** Headings, bold, italic, code, quotes, lists, `[ ]` tasks and links are styled as you type. The text stays plain Markdown.
- **Typed verbatim.** No smart quotes, no autocorrect. Fine for IDs, tokens and commands.
- **Small.** Under 500 KB, no dependencies, no network, no telemetry.

Your note is one plain-text file you can back up or grep: `~/Library/Application Support/ForeverNote/note.txt`

## Install

Needs macOS 13+ and the Xcode command line tools (`xcode-select --install`).

```sh
git clone https://github.com/shuaibird/forever-note.git
cd forever-note
./build.sh install   # builds, copies to /Applications, launches
```

`./build.sh` alone builds `build/Forever Note.app` without installing.

Right-click the menu-bar icon for **Launch at Login** and **Quit**.

## Limits

- One note. That's the point.
- The shortcut is fixed to ⌘E. If another app owns it, Forever Note still works from the menu-bar icon.
- Plain text only, no images or sync. Put the note's folder in iCloud/Dropbox yourself if you want that.

## License

[MIT](LICENSE)
