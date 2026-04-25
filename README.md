# uvid
uvid is a simple script for capturing timestamped ideas with optional source and author metadata, saved to a yearly log file. Available as a Bash script (`uvid.sh`) and a PowerShell script (`uvid.ps1`).

## Install

**Bash:**
```bash
chmod +x uvid.sh
./uvid.sh --install
```

**PowerShell:**
```powershell
.\uvid.ps1 -Install
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
```powershell
uvid -List 10
```

### Search
```bash
uvid --search "keyword"
```
```powershell
uvid -Search "keyword"
```
Searches across all log files.

### Edit an entry
```bash
uvid --edit
```
```powershell
uvid -Edit
```
Browse recent entries or search, then edit the selected entry field by field.

### Delete an entry
```bash
uvid --delete
```
```powershell
uvid -Delete
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
```powershell
uvid -Export
uvid -Export -Search "keyword"
uvid -Export -Author "Author Name"
uvid -Export -Year 2025
uvid -Export -From "01.03.2025" -To "15.06.2025"
```
Exports matching entries to `uvid_export_YYYY-MM-DD.md` in the current directory. Filters can be combined.

### Sync logs with VPS
```bash
uvid --sync
```
Manually trigger a sync with the VPS. Pushes local logs, merges with remote, pulls merged result. Also runs automatically every 15 minutes via cron.

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
```powershell
uvid -Help
```

## Options
| Flag | Description |
|------|-------------|
| `-s` | Source of the entry (optional) |
| `-a` | Author of the entry (optional) |
| `--list [n]` / `-List n` | Show last n entries from this year's log |
| `--search` / `-Search` | Search all log files for a term |
| `--edit` / `-Edit` | Edit an existing entry interactively |
| `--delete` / `-Delete` | Delete an existing entry with confirmation |
| `--export` / `-Export` | Export entries to Markdown file |
| `--author` / `-Author` | Filter export by author |
| `--year` / `-Year` | Filter export by year |
| `--from` / `-From` | Start of date range filter |
| `--to` / `-To` | End of date range filter |
| `--sync` | Sync logs with VPS |
| `--install` / `-Install` | Install uvid to your shell |
| `--help` / `-Help` | Show help |

## Log file
Entries are saved to `YEAR_uvid.log` in the current directory. A new file is created each year.

## Example
```bash
uvid "This is an example entry." -s "My Blog" -a "John Doe"
```
Produces the following entry in `2026_uvid.log`:
```
[28.02.2026 14:30] This is an example entry. [John Doe] (My Blog)
```
