# uvid

uvid is a simple Bash script that provides a way to log entries with some metadata (text, source, and author) along with a timestamp. The log entries are saved in a year-specific log file.

## Usage

Save the `uvid` script in your preferred location and make sure it has executable permissions:

```bash
chmod +x uvid.sh
```

To use this script, execute it with the following command:
```bash
./uvid.sh -s "some source" -a "some author" "some text entry"
```

## Options
- -s, --source: Specifies the source of the log entry.
- -a, --author: Specifies the author of the log entry.
- uvid: Indicates the command name, which should always be included as an argument.
- Any remaining arguments after parsing will be considered as the text entry.

## Log file
The script creates a new log file named `uvid_<year>.log` in the current directory if it doesn't exist. The entries are stored in this log file, and a new log file is created each year to separate the entries.

## Example
```bash
./uvid.sh -s "My Blog" -a "John Doe" "This is an example entry."
```

The above command will create a log entry like this in `uvid_<year>.log`:

> [timestamp] This is an example entry. [John Doe] (My Blog)
