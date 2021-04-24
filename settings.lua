dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/lib/mod_settings.lua")
dofile_once("data/scripts/perks/perk_list.lua")
function ModSettingsGuiCount() return 1 end
-- local MIGRATIONS = {}

local MOD_ID = "start_perks"
local SETTINGS_VERSION = 1
local DEFAULT = {
  boolean = false,
  number = 0,
  string = ""
}

local perk_settings = {}
for i, perk in ipairs(perk_list) do
  local setting = {
    perk_id = perk.id,
    key = table.concat{MOD_ID, ".perk_", perk.id},
    name = GameTextGet(perk.ui_name),
    desc = GameTextGet(perk.ui_description),
    icon = perk.ui_icon,
    scope = MOD_SETTING_SCOPE_NEW_GAME,
    hidden = false
  }

  if not perk.stackable then
    setting.type = "boolean"
  elseif perk.stackable_maximum ~= nil then
    setting.type = "number"
    setting.max = perk.stackable_maximum
  else
    setting.type = "string"
  end

  perk_settings[i] = setting
end

table.sort(
  perk_settings,
  function(a, b)
    return a.name < b.name
  end
)

function ModSettingsUpdate(init_scope)
  local version = ModSettingGet("start_perks._version")
  if version ~= SETTINGS_VERSION then
    ModSettingSet("start_perks._version", SETTINGS_VERSION)
    --[[
    for i = version or 1, SETTINGS_VERSION - 1 do
      if MIGRATIONS[i] then MIGRATIONS[i]() end
    end
    --]]
  end

  for _, setting in ipairs(perk_settings) do
    local default = DEFAULT[setting.type]
    ModSettingSetNextValue(setting.key, default, true)
    local next = ModSettingGetNextValue(setting.key)
    if type(next) ~= setting.type then
      next = default
      ModSettingSetNextValue(setting.key, next, false)
    end
    if setting.scope >= init_scope then
      ModSettingSet(setting.key, next)
    end
  end
end

---------- render perk_settings ----------

local NUM_SETTINGS = #perk_settings

local search_text = ""
local num_visible = NUM_SETTINGS

local widget_id = 0
local function get_id()
  widget_id = widget_id + 1
  return widget_id
end

function ModSettingsGui(gui, in_main_menu)
  widget_id = 0
  GuiIdPushString(gui, "top")
  GuiOptionsAdd(gui, GUI_OPTION.DrawActiveWidgetCursorOnBothSides)

  -- top row
  GuiLayoutBeginHorizontal(gui, 0, 0)
    -- clear search
    local clicked_clear_search =
      GuiButton(gui, get_id(), 0, 0, "Clear search")
    -- space
    GuiText(gui, 0, 0, "  ")
    -- reset all
    if GuiButton(gui, get_id(), 0, 0, "Reset all") then
      for _, setting in ipairs(perk_settings) do
        ModSettingSetNextValue(setting.key, DEFAULT[setting.type], false)
      end
    end
  GuiLayoutEnd(gui)

  -- search box
  local input = GuiTextInput(gui, get_id(), 0, 0, search_text, 130, 30)
  if clicked_clear_search then input = "" end
  if #input ~= #search_text then
    search_text = input
    if input == "" then
      num_visible = NUM_SETTINGS
      for _, setting in ipairs(perk_settings) do
        setting.hidden = false
      end
    else
      num_visible = 0
      input = input:lower()
      for _, setting in ipairs(perk_settings) do
        local matched = setting.name:lower():find(input, 0, true)
          or setting.perk_id:lower():find(input, 0, true)
          or setting.desc:lower():find(input, 0, true)
        if matched then
          setting.hidden = false
          num_visible = num_visible + 1
        else
          setting.hidden = true
        end
      end
    end
  end

  GuiOptionsRemove(gui, GUI_OPTION.DrawActiveWidgetCursorOnBothSides)
  GuiIdPop(gui)

  -- main area
  GuiLayoutBeginHorizontal(gui, 0, 0)
    -- icons and labels
    GuiIdPushString(gui, "labels")
    GuiText(gui, 0, 0, "     ") -- spacing
    GuiLayoutBeginVertical(gui, 0, 0)
      for id, setting in ipairs(perk_settings) do
        if setting.hidden then goto continue end
        local val = ModSettingGetNextValue(setting.key)
        local alpha = val == DEFAULT[setting.type] and 0.5 or 1

        GuiLayoutAddVerticalSpacing(gui, 2)
        GuiOptionsAddForNextWidget(gui, GUI_OPTION.Layout_InsertOutsideLeft)
        GuiImage(gui, id, -3, -2, setting.icon, alpha, 1, 0)
        GuiColorSetForNextWidget(gui, 1, 1, 1, alpha)
        GuiText(gui, 0, 0, setting.name)
        GuiTooltip(gui, setting.name, setting.desc)

        ::continue::
      end
    GuiLayoutEnd(gui)
    GuiText(gui, 0, 0, " ") -- spacing
    GuiIdPop(gui)

    -- right column (buttons)
    GuiLayoutBeginVertical(gui, 0, 0)
      for id, setting in ipairs(perk_settings) do
        if setting.hidden then goto continue end
        GuiLayoutAddVerticalSpacing(gui, 2)

        local value = ModSettingGetNextValue(setting.key)
        if type(value) ~= setting.type then
          value = DEFAULT[setting.type]
        end

        if setting.type == "boolean" then
          local text = value
            and GameTextGet("$option_on")
            or GameTextGet("$option_off")
          local clicked, r_clicked = GuiButton(gui, id, 0, 0, text)
          if clicked then
            ModSettingSetNextValue(setting.key, not value, false)
          elseif r_clicked then
            ModSettingSetNextValue(setting.key, false, false)
          end

        elseif setting.type == "number" then
          GuiLayoutAddVerticalSpacing(gui, 1.5)
          local next_value =
            GuiSlider(gui, id, -2, 0, "", value, 0, setting.max, 0, 1, " x$0 ", 64)
          GuiLayoutAddVerticalSpacing(gui, 1.5)
          if next_value ~= value then
            ModSettingSetNextValue(setting.key, next_value, false)
          end

        else -- setting.type == "string"
          local next_value = GuiTextInput(gui, id, 0, 0, value, 64, 10, "0123456789")
          if next_value ~= value then
            if next_value == "0" then next_value = "" end
            ModSettingSetNextValue(setting.key, next_value, false)
          end
        end

        ::continue::
      end
    GuiLayoutEnd(gui)
  GuiLayoutEnd(gui)

  -- prevent overlap
  for _ = 2, num_visible do
    GuiLayoutAddVerticalSpacing(gui, 2)
    GuiText(gui, 0, 0, " ")
  end
end
