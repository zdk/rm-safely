# rm-hook

Use 'rm' safely

# Install

Directly via:

`curl -fsSL https://raw.githubusercontent.com/zdk/rm-hook/main/rm-hook.sh | bash -s install`

Or, manually by:

`git clone git@github.com:zdk/rm-hook.git`
`cd rm-hook`
`./rm-hook.sh install`

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

Or,

`./rm-hook.sh uninstall`
