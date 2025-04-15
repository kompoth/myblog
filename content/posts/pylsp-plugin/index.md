---
title: "Custom pylsp plugin"
date: "2025-04-15"
summary: "On creating custom pylsp plugins."
description: "On creating custom pylsp plugins."
toc: true 
readTime: true
autonumber: false 
tags: ["Neovim", "Python", "LSP"]
showTags: false
---

In the previous post I mentioned `python-lsp-server` plugin system. This feature is one of the reasons why I like
`pylsp` and use it together with much faster Ruff language server. Plugins make `pylsp` very flexible and easily
customisable. It comes with a bunch of useful built-in plugins, some disabled by default. There are also very handy
third-party plugins like `pylsp-mypy`. And the greatest part -- I can easily create my own plugins.

`pylsp` plugin system relies on [Pluggy](https://pluggy.readthedocs.io/en/latest/) library used by `pytest`.
It introduces *hook functions* that are basically predefined methods of the *host* program (`pylsp` in our case).
The plugin in this case is a package that defines implementations for hooks specified by the host.

I am going to explain this in detail with some toy examples. For real life examples feel free to
check out my project [Starkiller](https://github.com/kompoth/starkiller).

## Implementing plugin logic

[Here](https://github.com/python-lsp/python-lsp-server/blob/04fa3e59e82e05a43759f7d3b5bea2fa7a9b539b/pylsp/hookspecs.py)
you can see the full list of hooks specified by `pylsp`. No docstrings, but it is usually pretty obvious what they do.

To create some hook implementation you need to write a method with the same name and arguments:

```python
from pylsp import hookimpl

@hookimpl
def pylsp_code_actions(
    config: Config,
    workspace: Workspace,
    document: Document,
    range: dict,
    context: dict,
) -> list[dict]:
    ...
```

There is a problem determining the expected return type though. It kind of makes sense that we need to return some JSON
serializable objects defined by LSP specification. To make things simple we can just use Microsoft's
[lsprotocol](https://github.com/microsoft/lsprotocol/tree/main/packages/python) package that implements all necessary
structures.

Let's implement a simple Code Action that deletes the line under cursor. Code Actions are basically commands that the
language server can execute on source code selected in your IDE. See the full specification
[here](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_codeAction).

```python
from lsprotocol.converters import get_converter
from lsprotocol.types import (
    CodeAction,
    CodeActionKind,
    Position,
    Range,
    TextEdit,
    WorkspaceEdit,
)
from pylsp import hookimpl
from pylsp.workspace import Document, Workspace

# This object is used to structure and unstructure LSP entities
converter = get_converter()


@hookimpl
def pylsp_code_actions(
    # These are pylsp entities
    config: Config,
    workspace: Workspace,
    document: Document,
    # These are raw LSP dicts
    range: dict,
    context: dict,
) -> list[dict]:
    # Convert selected code coordinates into a structured object and get first line range
    active_range = converter.structure(range, Range)
    line = document.lines[active_range.start.line].rstrip("\r\n")
    line_range = Range(
        start=Position(line=active_range.start.line, character=0),
        end=Position(line=active_range.start.line, character=len(line)),
    )

    # Prepare text edit
    line_range.end.line += 1
    line_range.end.character = 0
    text_edit = TextEdit(range=line_range, new_text="")

    # Prepare workspace edit
    workspace_edit = WorkspaceEdit(changes={document.uri: [text_edit]})

    # Prepare code action
    code_action = CodeAction(
        title="Delete line",
        kind=CodeActionKind.QuickFix,
        edit=workspace_edit,
    )
    
    return converter.unstructure([code_action])
```

This is of course just a toy example. Real life use cases will require a lot more lines of code invoking
[static code analysis](https://en.wikipedia.org/wiki/Static_program_analysis) and refactoring (maybe in the whole
document or even the project, not only in lines under the cursor). Here are some libraries that you might find helpful
for such tasks:

- [ast](https://docs.python.org/3/library/ast.html), a built-in Python
    [AST](https://en.wikipedia.org/wiki/Abstract_syntax_tree)
    implementation, very useful for fast linting.
- [Parso](https://parso.readthedocs.io), a
    [CST](https://en.wikipedia.org/wiki/Parse_tree)
    implementation, which will help with complex source code refactoring.
- [Jedi](https://jedi.readthedocs.io) and [Rope](https://github.com/python-rope/rope), powerful refactoring libraries.

## Logging

You'll probably want to see tracebacks and log messages from `pylsp` and our plugin. To do that we need to edit `pylsp`
call in our LSP client, be it Neovim or your preferred IDE. Just make sure it is called with
`-vv --log-file /tmp/pylsp.log`. E.g. for Neovim with `lspconfig` configuration must look like this:

```lua {hl_lines=[7]}
{
    "neovim/nvim-lspconfig",
    config = function()
        local lspconfig = require("lspconfig")
        
        lspconfig.pylsp.setup {
            cmd = {"pylsp", "-vv", "--log-file", "/tmp/pylsp.log"},
            settings = {
                -- doesn't matter right now
            }
        }
    end
}
```

Now we will see error and `pylsp` log messages in `/tmp/pylsp.log` file.

If you want to add custom log messages for your plugin, it can be easily done with this code:

```python
import logging

log = logging.getLogger(__name__)
log.debug("Initializing custom pylsp plugin")
```

## Plugin entry point

We need to configure package [entry point](https://packaging.python.org/en/latest/specifications/entry-points/) for
Pluggy to recognise our custom plugin. The modern way to set this and other package attributes is `pyproject.toml` file.

Assume we have the following project structure:
```bash
pylsp-plugin-project/
├── src
│   ├── __init__.py
│   └── plugin.py 
└── pyproject.py
```

Where `plugin.py` will contain hook implementations for our plugin (we'll get to it soon).

Here is what we need to have in our `pyproject.toml` than:

```toml
[project.entry-points.pylsp]
our_plugin = "src.plugin"
```

Note the `our_plugin` word -- this is basically the name of our plugin as it will be introduced to `pylsp`. We'll use
this word to enable and configure the plugin in `pylsp` settings.

## Enabling the plugin in `pylsp`

To enable our plugin in `pylsp` we need to build it as a package and install it into the same virtual environment where
we have `pylsp` installed.

First part could be achieved with various tools for building Python packages. It is a completely different subject which
is way out of this post scope, so we won't go deep into it. You probably should just stick with
[Poetry](https://python-poetry.org/) or [uv](https://docs.astral.sh/uv/). These two are modern tools for dependency and
environment management, and the latter is also blazing fast. Both provide `build` command to build your project into a
package. I'll just need to configure `pyproject.toml` file correctly (see docs for details).

With this being done you'll have a [wheel](https://packaging.python.org/en/latest/discussions/package-formats/) file --
the plugin's distribution. It will probably be located in `dist/` directory of your project. Now we need to
install it.

As I already mentioned in the previous post, I prefer `pipx` utility to install Python tools. It manages tool's virtual
environment and can also easily inject additional dependencies for the already installed tool. If you have `pylsp`
installed via `pipx`, you'll need to `inject` your plugin into `pylsp` environment:

```bash
pipx inject python-lsp-server ./dist/pylsp-plugin-project-<VERSION>-py3-none-any.whl 
```

With this `pylsp` will find the plugin in its environment and will recognise hook implementations inside it.

Finally, we need to enable the plugin in `pylsp` configuration. With Neovim and `lspconfig`:

```lua {hl_lines=[9]}
{
    "neovim/nvim-lspconfig",
    config = function()
        local lspconfig = require("lspconfig")
        
        lspconfig.pylsp.setup {
            cmd = {"pylsp", "-vv", "--log-file", "/tmp/pylsp.log"},
            settings = {
                our_plugin = {enabled = true}
            }
        }
    end
}
```

As you can see, we use here the name of our package entry point from the previous section.

Now try to run your code editor and request available Code Actions in any Python script. In Neovim it can be done with
`vim.lsp.buf.code_action()` command. AFAIK, in PyCharm with [LSP4IJ](https://github.com/redhat-developer/lsp4ij) plugin
Code Actions are listed with the right mouse button click.

If there are any problems, check out the log. If you implemented and enabled the plugin correctly, you'll see messages
like this:
```plain
INFO - pylsp.config.config - Loaded pylsp plugin our_plugin ...
```
