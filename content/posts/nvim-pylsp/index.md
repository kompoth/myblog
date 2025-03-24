---
title: "Neovim Python LSP setup"
date: "2025-03-04"
summary: "My take on a sane Neovim LSP and static type checker configuration."
description: "My take on a sane Neovim configuration with a LSP and a static type checker for a Python Developer."
toc: true 
readTime: true
autonumber: false 
tags: ["Neovim", "Python", "LSP"]
showTags: false 
---

As a dedicated Python Developer I want to be productive and write reliable code. To some point this could be assured by
various programming tools, such as linters, formatters, type checkers, and LSP servers. Most modern IDEs offer
out-of-the-box support of these clever utilities, so some developers don't even think about them.

I've been using Vim and Neovim text editiors as my primary coding tools for years now, and I had to figure out all this
LSP stuff myself to make it work. I don't mind to do some hands-on tinkering, especially if the topic is of interest
for me. Besides, thankfully, Nevim provides some first-class support for LSP servers.

So, this is my take on a sane Neovim LSP configuration for a Python developer. 

## Why `python-lsp-server`?

There are plenty of Python LSP implementations, all of them have some cool and sometimes unique features. Probably, the
most popular among them is [Pyright](https://github.com/microsoft/pyright), which combines type checking with LSP
functionality. It is an open source core of the Microsoft's Pylance. Pyright might be a good place to start.

There is also a bunch of language servers based on an amazing [Jedi](https://jedi.readthedocs.io/en/latest/) Python
refactoring package. It powers some essential LSP functions like symbols search, renaming, showing references and
definitions, and detecting virtual environments. The languages servers that use Jedi are listed on its wiki:

- [jedi-language-server](https://github.com/pappasam/jedi-language-server)
- [python-language-server](https://github.com/palantir/python-language-server) (currently unmaintained)
- [python-lsp-server](https://github.com/python-lsp/python-lsp-server) (fork from python-language-server)
- [anakin-language-server](https://github.com/muffinmad/anakin-language-server)

I personally prefer `python-lsp-server` (or `pylsp`) for the following reasons:

1. It is written in Python, so I can easily understand its source and patch it.
2. It has a plugin mechanism which allows me to choose from a bunch of external tools.

In particular, I use `python-lsp-ruff` and `pylsp-mypy` plugins. The first one replaces default `pylsp` formatting and
linting with [Ruff](https://docs.astral.sh/ruff/), that I adore for its speed, flexibility and an enormous set of rules
you can enable in your project. The second plugin integrates [mypy](https://github.com/python/mypy), a reference type
checker for Python.

As up to now, Ruff already has its own built-in language server, and there is some huge work being done to implement
static type checking functionality (see [red-knot](https://github.com/astral-sh/ruff/issues?q=label%3Ared-knot%20)
label in the issue tracker). I am very excited about both things, but as for now I think I gonna stick with `pylsp`.
It might be slow, but the plugin functionality gives me an opportunity to choose between various tools and develop my
own without directly forking the whole project. Probably this might change at some point.

## Neovim setup basics
A detailed overview of my Neovim config is beyond the scope of this post, but I still need to point out some
fundamentals.

So you might already know that Neovim is configured by a bunch of files. Those are not just configuration files, but
proper scripts in Lua programming language (or Vimscript, if you are an old school person). My configuration scripts
are organised in a following way:

```bash
nvim/
├── ftplugin
│   └── python.lua 
├── init.lua
└── lua
    ├── config
    │   └── lazy.lua
    └── plugins
        ├── lspconfig.lua
        ├── lualine.lua
        └── ... and all the other plugins I use
```

The `init.lua` script contains some basic config like encoding, indentation rules, highlighting, etc.
The `lua/plugins/` directory contains a separate configuration script for each plugin.
The `ftplugin/` contains language/extension specific configurations (e.g. if you want to have 2-spaced indentation for
Perl and 4-spaced for Python).

I use [lazy.nvim](https://lazy.folke.io/) to install and update Neovim plugins, it is very handy and simple to use.

That's mostly simple as that.

## Installing Python LSP with `pipx`
I am aware of [Mason](https://github.com/williamboman/mason.nvim), a Neovim plugin to manage LSPs, linters, etc. Might
give it a try some day.

For now my preferred approach is `pipx`, a tool to install Python packages in dedicated virtual environments.
IMHO this is the most convenient way to install Python utilities: linters, formatters, dependency managers, and any
Python LSP implementation you prefer.

We are going to install `python-lsp-server` with `python-lsp-ruff` and `pylsp-mypy` optional plugins. `pylsp` will be
installed with all optional dependencies so that we'll have a convenient linting and format checking functionality even
without optional plugins.

```bash
pipx install python-lsp-server[all]
pipx inject python-lsp-server pylsp-mypy
pipx inject python-lsp-server python-lsp-ruff
```

As you can see here, we ensure that plugin packages are installed to the same virtual environment where we have our
`pylsp` package installed.

## lspconfig setup
Now we need to configure Neovim to use the preferred LSP. This can be achieved pretty easily with the help of
[lspconfig](https://github.com/neovim/nvim-lspconfig), a total must-have for your Neovim LSP configuration.
This plugin provides basic configurations for various LSP servers.

I have it set up just as any other plugin in it's own dedicated script:
```lua
return {
    "neovim/nvim-lspconfig",
    tag = "v0.1.8",
    config = function()
        require("lspconfig").pylsp.setup {
            settings = {
                pylsp = {
                    pylsp_mypy = {enabled = true},
                    ruff = {enabled = true},
                }
            }
        }
    end
```
As you can see, there is not so much to configure here. I just have the plugins enabled, which isn't necessary, they
will be enabled by default. With this you should have diagnostic messages from `pylsp` in your Neovim buffer with Python
code:

![LSP messages](lsp-messages.png)

You may find more configuration options
[here](https://github.com/python-lsp/python-lsp-server/blob/develop/CONFIGURATION.md), and here is an
[example config](https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#pylsp) from the `lspconfig` repo.

## On `mypy` configuration
When using LSP with integrated `mypy` make sure that it knows where to look for third-party packages. If you are using
a virtual environment in your project, you need to specify its path for `mypy`. It could be achieved via `mypy.ini`
configuration file in the root of your project with the following lines (assuming your virtual environment is located
in `.venv/`):

```ini
[mypy]
python_executable=./.venv/bin/python
```

If you want to disable all type messages for a specific project, just add this setting in the same file:

```ini
[mypy]
ignore_errors=true
```

## Adding handy key bindings
The Neovim's LSP functionality is much more than just showing diagnostic messages.
You probably would like to have some LSP actions binded to hotkeys, like showing a method signature or unwrapping a
long error message.

The following Lua code will execute each time any LSP attaches the current buffer. Keep in mind while all these actions
are not `pylsp`-specific, some LSP implementations might not have them.

```lua
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Buffer local mappings
    local opts = { buffer = ev.buf }
    
    -- Go to the definition of the symbol (return with CTRL-I)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    
    -- Show a hover window with symbol's docs
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)

    -- Show symbol usage in the project
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)

    -- Show diagnostics message
    vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)
})
```

More useful LSP methods and their binding examples could be found in the `lspconfig` docs:
`:help lspconfig-keybindings`.

## Useful links
- [Blog post by Heiker Curiel](https://vonheikemen.github.io/devlog/tools/neovim-lsp-client-guide/)
