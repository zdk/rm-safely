# rm-hook

`rm` safely.

rm-hook is a safety alias to prevent the accidental deletion of important files by wrap around your system /bin/rm

Recovering files is possible because this will instead copy your files and directory to /tmp/.rm-trash/ instead of hard delete.

# Install

`curl -fsSL https://raw.githubusercontent.com/zdk/rm-hook/main/rm-hook.sh | bash -s install`

```bash
brew tap zdk/tools
brew install rm-hook
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

`curl -fsSL https://raw.githubusercontent.com/zdk/rm-hook/main/rm-hook.sh | bash -s uninstall`
