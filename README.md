# uvid
uvid is a simple script for capturing timestamped ideas with optional source and author metadata, saved to a yearly log file. Implemented in Bash (`uvid.sh`); on Windows, `uvid.ps1` and `uvid.cmd` forward to it through Git Bash, so Git for Windows is required.

## Install

**Bash:**
```bash
chmod +x uvid.sh
./uvid.sh --install
```

**PowerShell:**
```powershell
.\uvid.ps1 --install
```

This adds `uvid` as a command available anywhere in your shell.

## Usage

### Inline
```bash
uvid "text entry" [-s "source"] [-a "author"]
```

### Interactive
Run `uvid` with no arguments to be prompted for each field:
```
$ uvid
Text: some insight
Source: book title
Author: John Doe

Logged: [28.02.2026 14:30] some insight [John Doe] (book title)
File:   2026_uvid.log
```
Source and author are optional — press Enter to leave them blank.

### List recent entries
```bash
uvid --list        # last 10 entries
uvid --list 5      # last 5 entries
```

### Search
```bash
uvid --search "keyword"
```
Searches across all log files.

### Edit an entry
```bash
uvid --edit
```
Browse recent entries or search, then edit the selected entry field by field.

### Delete an entry
```bash
uvid --delete
```
Browse recent entries or search, then confirm deletion.

### Export to Markdown
```bash
uvid --export                                       # all entries
uvid --export --search "keyword"                    # filter by text
uvid --export --author "Author Name"                # filter by author
uvid --export --year 2025                           # filter by year
uvid --export --from 01.03.2025 --to 15.06.2025    # filter by date range
```
Exports matching entries to `uvid_export_YYYY-MM-DD.md` in the current directory. Filters can be combined.

### Sync logs with VPS
```bash
uvid --sync
```
Manually trigger a sync with the VPS. Pushes local logs, merges with remote, pulls merged result. Also runs automatically every 15 minutes via cron.

Transfers use `rsync`, so unchanged log files (e.g. older monthly logs) are skipped instead of re-copied every sync. If `rsync` is not installed, sync falls back to `scp` (copying all files) and prints a warning.

If the VPS runs [uvid-telegram-bot](https://github.com/senf-f/uvid-telegram-bot), `--sync` also mirrors its idea pages to `~/.uvid/threads/` (one Markdown page per idea the bot has already sent as a reminder, with comments and branch links, plus `queue.md`). Pages (`*.md`) in that folder are replaced on every sync, so don't edit them; other files there (e.g. `.obsidian/`) are left alone. To keep your own notes alongside, open `~/.uvid` as the Obsidian vault and write notes outside `threads/`.

**Merge semantics:**
- New entries from any machine are preserved.
- Entries are keyed by timestamp; edits on one machine propagate on the next sync.
- **Deletes do not propagate.** An entry deleted on one machine will reappear on the next sync because the other machine still has it. To truly remove an entry, delete it on every machine.

**Setup:**
1. Create `.uvid-sync.conf` (gitignored) with `VPS_HOST="your-host-or-alias"`
2. Deploy merge script: `scp uvid-merge.sh root@VPS_HOST:~/uvid-logs/`
3. Run first sync: `uvid --sync`
4. Add cron: `*/15 * * * * /path/to/uvid/uvid-sync.sh >> /tmp/uvid-sync.log 2>&1`

### Help
```bash
uvid --help
```

## Options
| Flag | Description |
|------|-------------|
| `-s` | Source of the entry (optional) |
| `-a` | Author of the entry (optional) |
| `--list [n]` | Show last n entries from this year's log |
| `--search` | Search all log files for a term |
| `--edit` | Edit an existing entry interactively |
| `--delete` | Delete an existing entry with confirmation |
| `--export` | Export entries to Markdown file |
| `--author` | Filter export by author |
| `--year` | Filter export by year |
| `--from` | Start of date range filter |
| `--to` | End of date range filter |
| `--sync` | Sync logs with VPS |
| `--install` | Install uvid to your shell |
| `--help` | Show help |

## Log file
Entries are saved to `~/.uvid/YEAR_uvid.log`. A new file is created each year. The directory is auto-created on first run.

## Example
```bash
uvid "This is an example entry." -s "My Blog" -a "John Doe"
```
Produces the following entry in `2026_uvid.log`:
```
[28.02.2026 14:30] This is an example entry. [John Doe] (My Blog)
```
