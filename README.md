# uvid
uvid is a simple script that logs timestamped entries with optional source and author metadata to a yearly log file. Available as a Bash script (`uvid.sh`) and a PowerShell script (`uvid.ps1`).

## Setup

**Bash:**
```bash
chmod +x uvid.sh
```

**PowerShell:** no setup required.

## Usage

### Inline
```bash
./uvid.sh "text entry" [-s "source"] [-a "author"]
```
```powershell
.\uvid.ps1 "text entry" [-s "source"] [-a "author"]
```

### Interactive
Run without arguments to be prompted for each field:
```
$ ./uvid.sh
Text: some insight
Source: book title
Author: John Doe

Logged: [28.02.2026 14:30] some insight [John Doe] (book title)
File:   2026_uvid.log
```
Source and author are optional — press Enter to leave them blank.

### Help
```bash
./uvid.sh --help
```
```powershell
.\uvid.ps1 -Help
```

## Options
| Flag | Description |
|------|-------------|
| `-s` | Source of the entry (optional) |
| `-a` | Author of the entry (optional) |

## Log file
Entries are saved to `YEAR_uvid.log` in the current directory. A new file is created each year.

## Example
```bash
./uvid.sh "This is an example entry." -s "My Blog" -a "John Doe"
```
Produces the following entry in `2026_uvid.log`:
```
[28.02.2026 14:30] This is an example entry. [John Doe] (My Blog)
```
