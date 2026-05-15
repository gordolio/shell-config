-- Cmd+C in iTerm2: pass through, then scrub leading whitespace from the clipboard.
-- Symlinked to ~/.hammerspoon/init.lua via shell-config install.
--
-- The hotkey is enabled ONLY while iTerm2 is frontmost — otherwise a global
-- bind would intercept cmd+c in every app and rely on a synthesized re-fire,
-- which silently drops the copy if Accessibility perms or timing misbehave.

hs.allowAppleScript(true)

local CLEAN_SCRIPT = os.getenv("HOME") .. "/src/shell-config/bin/clean-clipboard.pl"


local copyHotkey = hs.hotkey.new({"cmd"}, "c", function()
  -- Re-fire cmd+c so iTerm2 actually performs the copy. Default delay (200ms)
  -- is more reliable than 0.
  hs.eventtap.keyStroke({"cmd"}, "c")

  hs.timer.doAfter(0.15, function()
    hs.execute(CLEAN_SCRIPT, true)
  end)
end)

hs.window.filter.new("iTerm2")
  :subscribe(hs.window.filter.windowFocused,   function() copyHotkey:enable()  end)
  :subscribe(hs.window.filter.windowUnfocused, function() copyHotkey:disable() end)
