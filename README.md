![wm.spoon banner](.github/wm.spoon.png)

# wm.spoon

Window manager built on top of [Hammerspoon](https://www.hammerspoon.org/)--the automation framework for macOS.

## Installation

Download the latest [release](https://github.com/cmpadden/wm.spoon/releases/), decompress the file, and double click the Spoon, or run the following commands:

```bash
   # Replace <v0.2.3> with your desired version
 λ curl -L -O "https://github.com/cmpadden/wm.spoon/releases/download/v0.2.3/wm.spoon.zip"

   # The Hammerspoon Console should open and indicate that plugin has loaded
 λ unzip wm.spoon.zip && open wm.spoon
```

Refer to the [official documentation](https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md) for more information on Spoons, and how to install them.

## Usage

There are two primary concepts of `wm.spoon`: **layouts** and **geometries**. To use `wm.spoon` one must first define a layouts (or many), which is a table of geometries. A geometry is a built-in utility of Hammerspoon, [hs.geometry](https://www.hammerspoon.org/docs/hs.geometry.html), that represents the height, width, and x-and-y positions of a rectangle.

The user defines an table of layouts on `config.layouts`, which are bound to `<prefix> + 1, 2, 3, ... n`; using these hotkeys one can cycle through window layouts.

Then, the user can cycle the position of a window between the geometries of this layout using `<prefix> + h`, and `<prefix> + l` by default.

After moving windows to their desired positions, the state can be saved using the default binding of `<prefix> + -`.

## Configuration

When initializing `wm.spoon`, the user is required to define their layouts, however, they also have the option to tweak key bindings along with a variety of other options.

A collection of pre-defined geometries can be found in `spoon.wm.builtins`.

```lua
hs.loadSpoon("wm")

spoon.wm.config.layouts = {
    -- ┌-----------─┐
    -- | [        ] |
    -- | [        ] |
    -- └------------┘
    {
        spoon.wm.builtins.full,
        spoon.wm.builtins.pip_bottom_right,
    },
    -- ┌-----------─┐
    -- | [   ][   ] |
    -- | [   ][   ] |
    -- └------------┘
    {
        spoon.wm.builtins.padded_left,
        spoon.wm.builtins.padded_right,
        spoon.wm.builtins.pip_bottom_right,
    },
    -- ┌-----------─┐
    -- |  [      ]  |
    -- |  [      ]  |
    -- └------------┘
    {
        spoon.wm.builtins.padded_center,
        spoon.wm.builtins.pip_bottom_right,
    },
    -- ┌-----------─┐
    -- |    [  ]    |
    -- |    [  ]    |
    -- └------------┘
    {
        spoon.wm.builtins.skinny,
        spoon.wm.builtins.pip_top_right,
    },
}

spoon.wm:init()
```

---

<div align="center">
  <img src=".github/wm.spoon.logo.png" alt="wm.spoon logo" height="50px">
</div>
