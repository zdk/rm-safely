# rm-hook

`rm` safely.

# Install

`curl -fsSL https://raw.githubusercontent.com/zdk/rm-hook/main/rm-hook.sh | bash -s install`

# Usage

`rm` to delete things as usual, but safer ＼(◎o◎)／

In other words when you run `rm -rf file directory/`

It will backup to trash first, then delete.

# Additional features

```
rm --list-trash    # Show trash contents
rm --empty-trash   # Empty trash
```

# Uninstall

`curl -fsSL https://raw.githubusercontent.com/zdk/rm-hook/main/rm-hook.sh | bash -s uninstall`
