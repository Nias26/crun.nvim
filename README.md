# Crun

An Emacs' Compile mode clone, built around neovim's quickfix.

## Install

You can install it by using any package manager of your liking:

```lua
{ "Nias26/Crun.nvim" }
```

If you're using `Lazy`:

```lua
return {
    "Nias26/Crun.nvim",
    cmd = { "Cc", "Ckill" },
}
```

## Usage

The `Cc` command will execute any command you give and asynchronously output the running program's stdout and stderr in the quickfix list.
It accepts multiple arguments, so you can run something like:

```command
:Cc ls -la
```

In order to kill a process that is being run, you can use the `Ckill` command.

The command has been renamed to `Cc` since rust ftp creates a `Crun` command to run cargo so, to avoid confusion, I renamed it this way.

## API

Crun offers some function that behaves like the commands:

```lua
require("crun").crun() -- Run a program

require("crun").ckill() -- Kill current program
```
