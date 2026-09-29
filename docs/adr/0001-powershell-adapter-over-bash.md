# 1. PowerShell is an adapter over uvid.sh

Date: 2026-09-29

## Status

Accepted

## Context

uvid had two full implementations, `uvid.sh` and `uvid.ps1`, that had to stay in sync on the entry format, parsing, list/search/edit/delete/export, and sync. They drifted: a PS7-only `??` broke `uvid.cmd` (Windows PowerShell 5.1) and went unnoticed, and sync moved into PowerShell after a bare `bash` call resolved to WSL instead of Git Bash.

## Decision

`uvid.sh` is the only implementation. `uvid.ps1` forwards its arguments to it through Git Bash (`$env:ProgramFiles\Git\bin\bash.exe`, by full path), and only handles `--install` itself, since that edits the Windows user PATH. Both shells use `--flags`. Arguments travel in the `UVID_ARGS` env var (each terminated by `\x1f`) because Git Bash strips quotes from a native caller's argv. `uvid.cmd` calls `uvid.ps1`.

## Consequences

- Windows needs Git for Windows.
- Each call costs about 0.3 s more than native PowerShell (≈300 ms vs ≈20 ms in a warm session).
- Git Bash has no rsync, so sync from Windows falls back to scp and copies every log file.
- Behaviour changes in one place; the PowerShell tests only check the hop (quoting, output parity, flag rejection).
