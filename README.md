![wm.spoon banner](.github/wm.spoon.png)

# wm.spoon

Window manager built on top of [Hammerspoon](https://www.hammerspoon.org/) -- the powerful automation framework for macOS.

## Installation

Download the latest [release] from the side panel, decompress the file, and double click the Spoon. 

Refer to the [official documentation](https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md) for more information on Spoons, and how to install them.

## Usage

There are two primary concepts of `wm.spoon`: **layouts** and **geometries**. To use `wm.spoon` one must first define a layouts (or many), which is a table of geometries. A geometry is a built-in utility of Hammerspoon, [hs.geometry](https://www.hammerspoon.org/docs/hs.geometry.html), that represents the height, width, and x-and-y positions of a rectangle.

The user defines an table of layouts on `config.layouts`, which are bound to `<prefix> + 1, 2, 3, ... n`; using these hotkeys one can cycle through window layouts.

Then, the user can cycle the position of a window between the geometries of this layout using `<prefix> + h`, and `<prefix> + l` by default.

After moving windows to their desired positions, the state can be saved using the default binding of `<prefix> + -`.

## Configuration

When initializing `wm.spoon`, the user is required to define their layouts, however, they also have the option to tweak key bindings along with a variety of other options.

A collection of pre-defined geometries can be found in `wm.builtins`.

```lua
local wm = require("wm")

wm.config.layouts = {
    {
        wm.builtins.padded_left,
        wm.builtins.padded_right,
    },
    {
        wm.builtins.padded_left,
        wm.builtins.padded_right,
        wm.builtins.pip_bottom_right,
    },
    {
        wm.builtins.padded_center,
        wm.builtins.pip_bottom_right,
    },
    {
        wm.builtins.skinny,
        wm.builtins.pip_top_right,
    },
}

wm:init()
```

## Releases

Releases are triggered on tag creation as defined by the `.github/workflows/release.yml` GitHub action.

```bash
git tag v0.1
git push origin v0.1
```

## Raison d'être

This is an opinionated window management system that adheres to the workflow that I find most intuitive. For several years I used the tiling window managers like i3wm, but did not find something that suited my needs on macOS. This is not intended to as powerful as a manager like that, nor is it a tiling window manager. Instead, this is the byproduct of me playing around with Hammerspoon in my spare time.

Feedback and contributions are welcome, however, drastic changes would likely be better suited as a fork.

---

<div align="center">
  <img src=".github/wm.spoon.logo.png" alt="wm.spoon logo" height="50px">
</div>
