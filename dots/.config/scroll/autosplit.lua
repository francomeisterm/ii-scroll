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

-- Dwindle-ish close (11/22): Scroll's fit modes give a closed window's space to
-- all its siblings proportionally (fit_children in sway/tree/arrange.c). Dwindle
-- gives it to the neighbour it was split from instead. view_unmap runs before the
-- container is removed, so grow that neighbour now and let the normal fit pass
-- remove the closing window. set_size rescales every other sibling uniformly
-- (fit_arrange_fractions), so the neighbour is set to (n + c) / (total + c): after
-- the closing window goes and Scroll normalizes, the neighbour holds n + c and
-- the rest keep their sizes.

local function index_of(list, item)
  for i, v in ipairs(list) do
    if v == item then return i end
  end
  return nil
end

-- The window it was split from: the one before it (new windows go after the
-- focused one), or the one after when it's first.
local function neighbour(list, i)
  return list[i - 1] or list[i + 1]
end

local function first_view_container(c)
  local kids = scroll.container_get_children(c)
  if kids and #kids > 0 then return kids[1] end
  return c
end

local function give_space(siblings, closing, getter, axis)
  local i = index_of(siblings, closing)
  if not i or #siblings < 2 then return end
  local n = neighbour(siblings, i)
  local total = 0
  for _, s in ipairs(siblings) do total = total + (getter(s) or 0) end
  local fc, fn = getter(closing) or 0, getter(n) or 0
  if total <= 0 or fc <= 0 then return end
  local target = (axis == "h") and first_view_container(n) or n
  scroll.command(target, string.format("set_size %s %.6f", axis, (fn + fc) / (total + fc)))
end

local function rebalance(view, _)
  if not view then return end
  local c = scroll.view_get_container(view)
  if not c or scroll.container_get_floating(c) then return end
  local ws = scroll.container_get_workspace(c)
  if not ws then return end
  local mode = scroll.workspace_get_mode(ws)
  if not mode or mode.fit ~= "fitsplit" then return end
  local col = scroll.container_get_parent(c)
  if not col then return end
  local rows = scroll.container_get_children(col) or {}
  if #rows > 1 then
    -- Stacked in a column: the window above/below takes its height.
    give_space(rows, c, scroll.container_get_height_fraction, "v")
  else
    -- Alone in its column: the column beside it takes its width.
    give_space(scroll.workspace_get_tiling(ws) or {}, col,
      scroll.container_get_width_fraction, "h")
  end
end

scroll.add_callback("view_unmap", rebalance, nil)
