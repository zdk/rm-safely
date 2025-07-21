# rm-safely

`rm` safely.

rm-safely is a safety shell alias to prevent the accidental deletion of important files.

This is just a handy `rm` wrapping function with `mv` along with option to directly invoke `/bin/rm` with `--rm`.

Note that, current implementation saves files in `~/.local/share/Trash` which persists across reboots.

# Demo

![demo.gif](./docs/demo.gif)

# Install

Via curl,

`curl -fsSL https://raw.githubusercontent.com/zdk/rm-safely/main/rm-safely | bash -s install`

Or via homebrew,

```bash
brew install zdk/tools/rm-safely
```

# Usage

Use `rm` command to delete things as usual, but safer ＼(◎o◎)／

In other words when you run `rm -rf file directory/`

You will have files/dir the trash first,
then you can decide to delete or clean them later on.

# Really Remove

If you don't really care to move it to Trash first.

Use `rm --rm`

e.g. `rm --rm file directory/`

# Additional features

```
rm --list-trash       # Show trash contents
rm --empty-trash      # Empty trash
rm --show-trash-path  # Display the trash directory path
```

# Uninstall

`curl -fsSL https://raw.githubusercontent.com/zdk/rm-safely/main/rm-safely | bash -s uninstall`
