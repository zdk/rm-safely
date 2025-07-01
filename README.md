# rm-safely

`rm` safely.

rm-safely is a safety alias to prevent the accidental deletion of important files.

Not an alternative tool, this is just wrapping around your standard system `/bin/rm`.

Note that, current implementation saves files in ~/.local/share/Trash which persists across reboots.

# Install

`curl -fsSL https://raw.githubusercontent.com/zdk/rm-safely/main/rm-safely.sh | bash -s install`

Or via homebrew,

```bash
brew install zdk/tools/rm-safely
```

# Usage

`rm` to delete things as usual, but safer ＼(◎o◎)／

In other words when you run `rm -rf file directory/`

You will have files/dir the trash,
then you can decide to delete or clean them later on.

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
