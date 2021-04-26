function ModSettingsGuiCount() return 1 end
dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/lib/mod_settings.lua")
dofile_once("data/scripts/perks/perk.lua")
dofile("data/scripts/perks/perk_list.lua")

local MOD_ID = "start_perks"
local SETTINGS_VERSION = 1
local DEFAULT = { boolean = false, number = 0, string = "" }

local perk_settings = {}
local dirty = false

function ModSettingsUpdate(init_scope)
  -- migrations can go here in the future
  local version = ModSettingGet(MOD_ID .. "._version")
  if version ~= SETTINGS_VERSION then
    ModSettingSet(MOD_ID .. "._version", SETTINGS_VERSION)
  end

  -- refresh perk list
  local hidden_states = {}
  for i, setting in ipairs(perk_settings) do
    hidden_states[setting.id] = setting.hidden
    perk_settings[i] = nil
  end
  for i, perk in ipairs(perk_list) do
    local setting = {
      id = perk.id,
      name = perk.ui_name,
      desc = perk.ui_description,
      icon = perk.ui_icon,
      key = table.concat{MOD_ID, ".perk_", perk.id},
      hidden = hidden_states[perk.id] or false
    }
    if not perk.stackable then
      setting.type = "boolean"
    elseif perk.stackable_maximum then
      setting.type = "number"
      setting.max = perk.stackable_maximum
    else
      setting.type = "string"
    end

    table.insert(perk_settings, setting)

    -- set to default if unset or incorrect type
    if type(ModSettingGetNextValue(setting.key)) ~= setting.type then
      ModSettingSetNextValue(setting.key, DEFAULT[setting.type], false)
    end
  end

  table.sort(perk_settings, function(a, b)
    return GameTextGetTranslatedOrNot(a.name)
      < GameTextGetTranslatedOrNot(b.name)
  end)

  -- update everything if in the correct scope
  if init_scope <= MOD_SETTING_SCOPE_NEW_GAME then
    dirty = false
    for _, setting in ipairs(perk_settings) do
      ModSettingSet(setting.key, ModSettingGetNextValue(setting.key))
    end
  end
end

---------- render ----------

local search_text = ""
function ModSettingsGui(gui, in_main_menu)
  if in_main_menu then
    GuiColorSetForNextWidget(gui, 1, 1, 1, 0.5)
    GuiText(gui, 0, 0, "If any modded perks are missing, you'll need to be ingame to configure them.")
  end

  local _id = 0
  local function id()
    _id = _id + 1
    return _id
  end

  -- top area
  GuiOptionsAdd(gui, GUI_OPTION.DrawActiveWidgetCursorOnBothSides)
  GuiLayoutBeginHorizontal(gui, 0, 0)
  local clicked_clear_search = GuiButton(gui, id(), 0, 0, "Clear search")
  GuiText(gui, 0, 0, "  ")
  local clicked_reset_all = GuiButton(gui, id(), 0, 0, "Reset all")
  if not in_main_menu and dirty then
    GuiColorSetForNextWidget(gui, 1, 1, 1, 0.5)
    GuiText(gui, 0, 0, "   (Perks will apply in a new game)")
  end
  GuiLayoutEnd(gui)
  local input = GuiTextInput(gui, id(), 0, 0, search_text, 130, 30)
  GuiOptionsRemove(gui, GUI_OPTION.DrawActiveWidgetCursorOnBothSides)

  if clicked_clear_search then
    input = ""
  elseif clicked_reset_all then
    for _, setting in ipairs(perk_settings) do
      ModSettingSetNextValue(setting.key, DEFAULT[setting.type], false)
    end
  end
  if input ~= search_text then
    search_text = input
    if input == "" then
      for _, setting in ipairs(perk_settings) do setting.hidden = false end
    else
      input = input:lower()
      for _, setting in ipairs(perk_settings) do
        setting.hidden = not ((
          GameTextGetTranslatedOrNot(setting.name):lower():find(input, 0, true)
            or setting.id:lower():find(input, 0, true)
            or GameTextGetTranslatedOrNot(setting.desc):lower():find(input, 0, true)
        ) and true or false)
      end
    end
  end

  -- begin main area
  GuiLayoutBeginHorizontal(gui, 0, 0)

  -- icons and labels (left)
  GuiText(gui, 0, 0, "     ") -- space for icons
  GuiLayoutBeginVertical(gui, 0, 0)
  for _, setting in ipairs(perk_settings) do
    if setting.hidden then goto continue end
    local value = ModSettingGetNextValue(setting.key)
    local alpha = value == DEFAULT[setting.type] and 0.5 or 1
    local name = GameTextGetTranslatedOrNot(setting.name)
    local desc = GameTextGetTranslatedOrNot(setting.desc)

    GuiLayoutAddVerticalSpacing(gui, 2)
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.Layout_InsertOutsideLeft)
    GuiImage(gui, id(), -3, -2, setting.icon, alpha, 1, 0)
    GuiColorSetForNextWidget(gui, 1, 1, 1, alpha)
    GuiText(gui, 0, 0, name)
    GuiTooltip(gui, name, desc)
    ::continue::
  end
  GuiLayoutEnd(gui)

  -- widgets (right)
  GuiText(gui, 0, 0, "  ") -- don't get too close to labels
  GuiLayoutBeginVertical(gui, 0, 0)
  for _, setting in ipairs(perk_settings) do
    if setting.hidden then goto continue end

    local value = ModSettingGetNextValue(setting.key)
    if type(value) ~= setting.type then
      value = DEFAULT[setting.type]
    end

    GuiLayoutAddVerticalSpacing(gui, 2)
    if setting.type == "boolean" then
      local text = value and GameTextGet("$option_on") or GameTextGet("$option_off")
      if GuiButton(gui, id(), 0, 0, text) then
        dirty = true
        ModSettingSetNextValue(setting.key, not value, false)
      end
    elseif setting.type == "number" then
      GuiLayoutAddVerticalSpacing(gui, 1.5)
      local next_value =
        GuiSlider(gui, id(), -2, 0, "", value, 0, setting.max, 0, 1, " x$0 ", 64)
      GuiLayoutAddVerticalSpacing(gui, 1.5)
      if next_value ~= value then
        dirty = true
        ModSettingSetNextValue(setting.key, next_value, false)
      end
    else -- setting.type == "string"
      local next_value = GuiTextInput(gui, id(), 0, 0, value, 64, 10, "0123456789")
      if next_value ~= value then
        dirty = true
        if tonumber(next_value) == 0 then next_value = "" end
        ModSettingSetNextValue(setting.key, next_value, false)
      end

    end
    ::continue::
  end
  GuiLayoutEnd(gui) -- end widgets
  GuiLayoutEnd(gui) -- end main area

  -- prevent overlap
  for _, setting in ipairs(perk_settings) do
    if not setting.hidden then
      GuiLayoutAddVerticalSpacing(gui, 2)
      GuiText(gui, 0, 0, " ")
    end
  end
end
