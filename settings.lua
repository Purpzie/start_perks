dofile_once("data/scripts/lib/mod_settings.lua")
dofile_once("data/scripts/perks/perk_list.lua")

local mod_id = "start_perks"
local settings = {}

local DEFAULT_VALUE = {
  string = "",
  number = 0,
  boolean = false
}

-- read perk list
for i, perk in ipairs(perk_list) do
  local setting = {
    key = table.concat{mod_id, ".perk_", perk.id},
    name = GameTextGet(perk.ui_name),
    desc = GameTextGet(perk.ui_description),
    scope = MOD_SETTING_SCOPE_NEW_GAME
  }

  if not perk.stackable then
    setting.type = "boolean"
  elseif perk.stackable_maximum ~= nil then
    setting.type = "number"
    setting.max = perk.stackable_maximum
  else
    setting.type = "string"
  end

  settings[i] = setting
end

-- sort alphabetically
table.sort(
  settings,
  function(a, b)
    return a.name < b.name
  end
)

function ModSettingsUpdate(init_scope)
  --[[
  local migrations = {}
  local version = ModSettingGet("start_perks.settings_version")
  if migrations[version] then
    migrations[version]()
  end
  --]]

  ModSettingSet("start_perks.settings_version", 1)

  for _, setting in ipairs(settings) do
    -- set if unset
    ModSettingSetNextValue(setting.key, DEFAULT_VALUE[setting.type], true)
    -- update
    if setting.scope >= init_scope then
      ModSettingSet(setting.key, ModSettingGetNextValue(setting.key))
    end
  end
end

function ModSettingsGuiCount()
  return 1
end

---------- render settings ----------

local id = 0
local function get_id()
  id = id + 1
  return id
end

function ModSettingsGui(gui, in_main_menu)
  id = 0

  -- reset button
  do
    GuiColorSetForNextWidget(gui, 0.5, 1, 1, 1)
    local clicked = GuiButton(gui, get_id(), 0, 0, "Clear all")
    GuiTooltip(gui, "Reset all perks.", "")

    if clicked then
      for _, setting in ipairs(settings) do
        ModSettingRemove(setting.key)
      end
    end
  end

  GuiLayoutBeginHorizontal(gui, 0, 0)

  -- left side
  GuiLayoutBeginVertical(gui, 0, 0)

  -- perk names
  for _, setting in ipairs(settings) do
    local spacing = setting.type == "string"
    if spacing then GuiLayoutAddVerticalSpacing(gui, 1) end

    -- dim if unset
    local next = ModSettingGetNextValue(setting.key)
    if not next or next == 0 or next == "" then
      GuiOptionsAddForNextWidget(gui, GUI_OPTION.DrawSemiTransparent)
    end

    GuiText(gui, 0, 0, setting.name)
    GuiTooltip(gui, setting.name, setting.desc)
    if spacing then GuiLayoutAddVerticalSpacing(gui, 1) end
  end

  GuiLayoutEnd(gui)

  -- right side
  GuiLayoutBeginVertical(gui, 0, 0)

  for _, setting in ipairs(settings) do
    local value = ModSettingGetNextValue(setting.key)
    if type(value) ~= setting.type then
      value = DEFAULT_VALUE[setting.type]
    end

    if setting.type == "boolean" then
      local text = GameTextGet(value and "$option_on" or "$option_off")
      local clicked, right_clicked = GuiButton(gui, get_id(), 0, 0, text)
      if clicked then
        ModSettingSetNextValue(setting.key, not value, false)
      elseif right_clicked then
        ModSettingSetNextValue(setting.key, false, false)
      end

    elseif setting.type == "number" then
      GuiLayoutAddVerticalSpacing(gui, 1.5)
      local next_value =
        GuiSlider(gui, get_id(), -2, 0, "", value, 0, setting.max, 0, 1, " x$0 ", 64)
      GuiLayoutAddVerticalSpacing(gui, 1.5)
      if value ~= next_value then
        ModSettingSetNextValue(setting.key, next_value, false)
      end

    else -- setting.type == "string"
      GuiLayoutAddVerticalSpacing(gui, 1)
      local next_value = GuiTextInput(gui, get_id(), 0, 0, value, 64, 10, "0123456789")
      GuiLayoutAddVerticalSpacing(gui, 1)
      if next_value ~= value then
        if next_value == "0" then next_value = "" end
        ModSettingSetNextValue(setting.key, next_value, false)
      end
    end
  end

  GuiLayoutEnd(gui)
  GuiLayoutEnd(gui)

  -- prevent mod from covering settings of other mods
  for _, setting in ipairs(settings) do
    local spacing = setting.type == "string"
    if spacing then GuiLayoutAddVerticalSpacing(gui, 1) end
    GuiText(gui, 0, 0, " ")
    if spacing then GuiLayoutAddVerticalSpacing(gui, 1) end
  end
end
