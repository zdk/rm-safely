# rm-safely

`rm` safely.

rm-safely is a safety alias to prevent the accidental deletion of important files.

Not an alternative tool, this is just wrapping around your standard system `/bin/rm`.

Note that, current implementation saves files in /tmp/.rm-trash which gets cleared on reboot.

# Install

`curl -fsSL https://raw.githubusercontent.com/zdk/rm-safely/main/rm-safely.sh | bash -s install`

```bash
brew tap zdk/tools
brew install rm-safely
```

# Usage

`rm` to delete things as usual, but safer ＼(◎o◎)／

In other words when you run `rm -rf file directory/`

It will backup to trash first, then delete.

# Really Remove

use `rm --rm`

`rm --rm file directory/`

# Additional features

```
rm --list-trash    # Show trash contents
rm --empty-trash   # Empty trash
```

# Uninstall

`curl -fsSL https://raw.githubusercontent.com/zdk/rm-safely/main/rm-safely.sh | bash -s uninstall`
