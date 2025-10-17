# rm-safely

`rm` safely.

rm-safely is a safety shell alias to prevent the accidental deletion of important files, especially, default MacOS `rm`

This is just a handy shell wrapping function along with option to directly invoke `/bin/rm` with `--rm`.

If you always use `/bin/rm -i` or alias it already, you will probably be fine.

But, with this rm-safely alias, it should prevent you in case of autocomplete from shell history that left of with unintended `rm -rf`.

_Keys_,

- Written in shell script, no dependencies.
- Save files in `~/.local/share/Trash` and in `/.Trash-$(id-u)` for mounted volumes.
- Tested on:
  - Shell
    - zsh
  - OS:
    - macOS 15.5+
    - Linux arch-linux 6.17.1-2-cachyos

# Demo

![demo.gif](./docs/demo.gif)

# Install

Via curl:

`curl -fsSL https://raw.githubusercontent.com/zdk/rm-safely/main/rm-safely | bash -s install`

Via homebrew:

```bash
brew install zdk/tools/rm-safely
```

# Usage

Use `rm` command to delete things as usual, but safer ＼(◎o◎)／

In other words when you run `rm -rf file directory/`

You will have files/dir the trash first,
then you can decide to delete or clean them later on.

# Additional features

```
rm --rm              Skip trash, execute real 'rm'
rm --list-trash      Show trash contents from all filesystems
rm --restore <hash>  Restore a file from trash using its hash
rm --undo            Restore the last deleted files
rm --empty-trash     Empty all trash directories
rm --show-trash-path Display all trash directory paths
```

# Really Remove

If you don't really care to move it to Trash first.

rm-safely provide bypass to your OS rm via `--rm` option.

That means, use `rm --rm`

For examples:

- remove files and directy with OS rm.

`rm --rm file directory/`

- see the OS rm --help

```rm --rm --help
/bin/rm: illegal option -- -
usage: rm [-f | -i] [-dIPRrvWx] file ...
       unlink [--] file
```

`--rm` is nothing special other than execute `/bin/rm` from current shell.

Or, you could just `/bin/rm` directly.

# Uninstall

`curl -fsSL https://raw.githubusercontent.com/zdk/rm-safely/main/rm-safely | bash -s uninstall`

# Notes

- Main goal of rm-safely is to write it in a pure shell script
  as a gateway and a suppliment to rm, not a replacement.

- Alternative tools:

  - https://github.com/MilesCranmer/rip2 (rust)
  - https://github.com/Byron/trash-rs (rust)
  - https://github.com/kaelzhang/shell-safe-rm (bash)
  - https://github.com/hitzhangjie/rm (go)

[Important Reminder],

Regarding the normal bahaviour of unix alias,

- Please keep in mind, _the rm-safely alias is available in current user only_.
- So please always use `sudo -s` to switch to root user, then run `rm` in the next step.
