@echo off
setlocal EnableDelayedExpansion

set ARGS=
for %%A in (%*) do (
    set "ARG=%%~A"
    if "!ARG!"=="--help" (set "ARG=-Help"
    ) else if "!ARG!"=="-h" (set "ARG=-Help"
    ) else if "!ARG!"=="--list" (set "ARG=-List"
    ) else if "!ARG!"=="--search" (set "ARG=-Search"
    ) else if "!ARG!"=="--install" (set "ARG=-Install"
    ) else if "!ARG!"=="--edit" (set "ARG=-Edit"
    ) else if "!ARG!"=="--delete" (set "ARG=-Delete"
    ) else if "!ARG!"=="--sync" (set "ARG=-Sync"
    ) else if "!ARG!"=="--export" (set "ARG=-Export"
    ) else if "!ARG!"=="--author" (set "ARG=-Author"
    ) else if "!ARG!"=="--year" (set "ARG=-Year"
    ) else if "!ARG!"=="--from" (set "ARG=-From"
    ) else if "!ARG!"=="--to" (set "ARG=-To"
    )
    set ARGS=!ARGS! "!ARG!"
)

powershell.exe -ExecutionPolicy Bypass -File "%~dp0uvid.ps1" %ARGS%
