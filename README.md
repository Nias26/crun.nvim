# Crun

An Emacs' Compile mode clone, built around neovim's quickfix

## Install

You can install it by using any package manager of your liking

```lua
{ "Nias26/Crun.nvim" }
```

If you're using `Lazy`:

```lua
return {
    "Nias26/Crun.nvim",
    cmd = "Crun",
}
```

## Usage

The `Crun` command is available and it will execute any command you give, asynchronously, while it outputs everything in the quickfix list.
it accepts multiple arguments, so you can run something like:

```command
:Crun ls -la
```

In order to kill a process that is being run, you can use the `Ckill` command.
The command is by default bind to the 'K' key, available only in the quickfix buffer
