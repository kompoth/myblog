---
title: "Custom pylsp plugin"
date: "2025-03-08"
summary: "On writing a pylsp plugin and enabling it in Neovim."
description: "On writing a pylsp plugin and enabling it in Neovim."
toc: true 
readTime: true
autonumber: false 
tags: ["Neovim", "Python", "LSP"]
showTags: false
draft: true
---

Before reading this blog post, it might be helpful to check out [this overview of my Python LSP setup for Neovim](/posts/nvim-pylsp).
There I mention `pylsp-mypy` plugin which enables [mypy](https://github.com/python/mypy) static type checker functionality in our local `python-lsp-server` instance.
So, I've been wondering how I can create a custom `pylsp` plugin.
Hopefully, not only it would be interesting by itself but it could also provide us an insight on a general approach of LSP customization.

## The goal
I set a goal to write a simple plugin to fix star imports which sounds pretty achievable and somewhat useable.
I currently am refactoring a huge project with tons of `from ... import *` constructions. They are quite an annoyance:
it is almost impossible to quickly understand where an object was defined and is it used correctly.

So, the idea is following. Consider the following `main.py` script:

```python
from numpy import *

from modules.submodule1 import *
from modules.submodule2 import *

my_array = array([SomeClass(1), SomeClass(2), SomeClass(3)])
my_array = reverse_array(my_array)
```

How do we know where `SomeClass`, `array` and `reverse_array` entities are defined? Or if any of them is defined at all? 

In this case I would like my LSP to know how to format `main.py` imports as following:

```python
from numpy import array

from modules.submodule1 import SomeClass
from modules.submodule2 import reverse_array
```

It would also be great to be able to import the whole module with an alias and use objects from it as its attributes:

```python
from numpy import array

from modules.submodule1 import SomeClass
import modules.submodule2 as sm2

my_array = array([SomeClass(1), SomeClass(2), SomeClass(3)])
my_array = sm2.reverse_array(my_array)
```

This would be very handy if we want to import lots of entities from `submodule2` and not to clog the `main.py` heading.

I'm not saying that such plugin would give any priceless or unique functionality: there is a [removestar](https://github.com/asmeurer/removestar) utility
and I'm pretty sure `pylsp` already [provides some import automation](https://github.com/python-lsp/python-lsp-server/blob/develop/docs/autoimport.md)
which would basically remove any need in star import replacing. That isn't the point anyways :D
