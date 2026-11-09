-- Dwindle-ish auto split for Scroll (11/9, enabled live + nested-tested 11/9 03:2x).
-- Every time a tiled window gets focus, set the workspace mode so the NEXT
-- window splits along the focused window's longer side:
--   wider than tall  -> horizontal (new column beside it)
--   taller than wide -> vertical   (stacks below it in the same column)
-- Works with layout_default_mode h fitsplit (new window halves the focused one).
-- Enable: add `lua ~/.config/scroll/autosplit.lua` to ~/.config/scroll/config.

local function apply(view, _)
  if not view then return end
  local c = scroll.view_get_container(view)
  if not c or scroll.container_get_floating(c) then return end
  local ws = scroll.container_get_workspace(c)
  if not ws then return end
  local w = scroll.container_get_width(c)
  local h = scroll.container_get_height(c)
  if not w or not h or w <= 0 or h <= 0 then return end
  scroll.workspace_set_mode(ws, { mode = (w >= h) and "horizontal" or "vertical" })
end

scroll.add_callback("view_focus", apply, nil)
