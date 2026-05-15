-- Cmd+C in iTerm2: pass through, then scrub leading whitespace from the clipboard.
-- Symlinked to ~/.hammerspoon/init.lua via shell-config install.

local CLEAN_SCRIPT = os.getenv("HOME") .. "/src/shell-config/bin/clean-clipboard.pl"

hs.hotkey.bind({"cmd"}, "c", function()
  -- Synthesize a real cmd+c. hs.eventtap.keyStroke does not re-fire Hammerspoon hotkeys.
  hs.eventtap.keyStroke({"cmd"}, "c", 0)

  if hs.application.frontmostApplication():name() == "iTerm2" then
    -- Wait briefly for the OS to update the pasteboard, then scrub.
    hs.timer.doAfter(0.15, function()
      hs.execute(CLEAN_SCRIPT, true)
    end)
  end
end)
