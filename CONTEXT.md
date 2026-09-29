# uvid

Personal log of timestamped ideas and insights. Entries are captured on several devices (CLI, Telegram bot) and reconciled into one canonical store.

## Language

**Entry**:
One logged idea: a timestamp, text, author, source, and device, stored as a single line.
_Avoid_: record, note, item

**Author**:
Who the idea came from. `.` means "me / unspecified".
_Avoid_: user, owner

**Source**:
Where the idea came from (a book, a conversation, `telegram-voice`). `-` means "none".
_Avoid_: origin, reference

**Placeholder**:
The `.` author or `-` source written when the field is empty, so every Entry carries both fields.

**Device**:
The machine or channel that logged an Entry, e.g. `laptop`, `vps`.
_Avoid_: host, machine name

**Entry identity**:
What makes two Entries the same across devices: timestamp + Device + position among Entries sharing that timestamp and Device. An Entry with matching identity but different text is an edit.
_Avoid_: dedup key, ID

**Log file**:
All Entries for one calendar month.
_Avoid_: logfile, journal

**Canonical store**:
The VPS copy of all Log files; the result of every Merge.
_Avoid_: master, server logs

**Merge**:
Combining incoming Log files into the Canonical store by Entry identity. Deletes do not propagate.
_Avoid_: dedup, reconcile

**Sync**:
Push local Log files, Merge on the VPS, pull the Canonical store back.
