dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/lib/mod_settings.lua")
dofile_once("data/scripts/perks/perk_list.lua")
dofile_once("mods/start_perks/files/migrations.lua")
function ModSettingsGuiCount() return 1 end

local MOD_ID = "start_perks"
local SETTINGS_VERSION = #MIGRATIONS + 1
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
    for i = version or 1, SETTINGS_VERSION - 1 do
      MIGRATIONS[i]()
    end
  end

  for _, setting in ipairs(perk_settings) do
    local default = DEFAULT[setting.type]
    ModSettingSetNextValue(setting.key, default, true)
    if setting.scope >= init_scope then
      local next = ModSettingGetNextValue(setting.key)
      ModSettingSet(setting.key, next)
    end
  end
end

---------- render perk_settings ----------

local NUM_SETTINGS = #perk_settings
local ID_RESET = NUM_SETTINGS + 1
local ID_SEARCH = NUM_SETTINGS + 2
local ID_SEARCH_CLEAR = NUM_SETTINGS + 3

local search_text = ""
local num_visible = NUM_SETTINGS

function ModSettingsGui(gui, in_main_menu)
  GuiOptionsAdd(gui, GUI_OPTION.DrawActiveWidgetCursorOnBothSides)
  GuiLayoutBeginHorizontal(gui, 0, 0)
    -- clear search
    local clicked_clear_search =
      GuiButton(gui, ID_SEARCH_CLEAR, 0, 0, "Clear search")
    -- space
    GuiText(gui, 0, 0, "  ")
    -- reset all
    if GuiButton(gui, ID_RESET, 0, 0, "Reset all") then
      for _, setting in ipairs(perk_settings) do
        ModSettingSetNextValue(setting.key, DEFAULT[setting.type], false)
      end
    end
  GuiLayoutEnd(gui)

  -- search
  local input = GuiTextInput(gui, ID_SEARCH, 0, 0, search_text, 130, 30)
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

  GuiOptionsClear(gui)
  GuiLayoutBeginHorizontal(gui, 0, 0)
    -- icons and labels
    GuiText(gui, 0, 0, "     ") -- space for icons
    GuiLayoutBeginVertical(gui, 0, 0)
      for _, setting in ipairs(perk_settings) do
        if setting.hidden then goto continue end
        local val = ModSettingGetNextValue(setting.key)
        local alpha = val == DEFAULT[setting.type] and 0.5 or 1

        GuiLayoutAddVerticalSpacing(gui, 2)
        GuiOptionsAddForNextWidget(gui, GUI_OPTION.Hack_AllowDuplicateIds)
        GuiOptionsAddForNextWidget(gui, GUI_OPTION.Layout_InsertOutsideLeft)
        GuiImage(gui, 0, -3, -2, setting.icon, alpha, 1, 0)
        GuiColorSetForNextWidget(gui, 1, 1, 1, alpha)
        GuiText(gui, 0, 0, setting.name)
        GuiTooltip(gui, setting.name, setting.desc)

        ::continue::
      end
    GuiLayoutEnd(gui)

    -- spacing
    GuiText(gui, 0, 0, " ")

    -- right column (buttons)
    GuiLayoutBeginVertical(gui, 0, 0)
      for id, setting in ipairs(perk_settings) do
        if setting.hidden then goto continue end
        local value = ModSettingGetNextValue(setting.key)
        if type(value) ~= setting.type then
          value = DEFAULT[setting.type]
        end

        GuiLayoutAddVerticalSpacing(gui, 2)
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
    GuiText(gui, 0, 0, " ")
    GuiLayoutAddVerticalSpacing(gui, 2)
  end
end
