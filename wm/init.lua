-- Entry point for Hammerspoon when loading as a Spoon via hs.loadSpoon("wm")
-- Delegates to spoon.lua to keep a single implementation.

local resourcePath = hs and hs.spoons and hs.spoons.resourcePath
if resourcePath then
  return dofile(resourcePath("spoon.lua"))
else
  -- Fallback for direct require from source tree
  return dofile((... and (...):gsub("%.init$","") or ".") .. "/spoon.lua")
end

