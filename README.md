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
