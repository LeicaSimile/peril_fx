-- Author: LeicaSimile

local mod = get_mod("peril_fx")
local MoodSettings = require("scripts/settings/camera/mood/mood_settings")
local moods = MoodSettings.moods
local mood_status = MoodSettings.status
local WarpCharge = require("scripts/utilities/warp_charge")
local originals = {
    source_parameter_funcs = {
        mood = "warped",
        key = "source_parameter_funcs",
        value = moods["warped"].source_parameter_funcs,
    },
    particle_material_scalar_funcs = {
        mood = "warped_low_to_high",
        key = "particle_material_scalar_funcs",
        value = moods["warped_low_to_high"].particle_material_scalar_funcs,
    },
    critical_peril_vfx = {
        mood = "warped_critical",
        key = "particle_effects_looping",
        value = moods["warped_critical"].particle_effects_looping,
        toggle = "show_critical_peril_vfx",
    },
    high_peril_sfx = {
        mood = "warped_high_to_critical",
        key = "sound_start_event",
        value = moods["warped_high_to_critical"].sound_start_event,
        toggle = "play_high_peril_sfx",
    },
    critical_peril_sfx = {
        mood = "warped_critical",
        key = "sound_start_event",
        value = moods["warped_critical"].sound_start_event,
        toggle = "play_critical_peril_sfx",
    },
    warp_build_up_loop_start = {
        mood = "warped",
        key = "looping_sound_start_events",
        value = moods["warped"].looping_sound_start_events,
        toggle = "play_peril_build_up_sfx",
    },
}

local function set_sfx_intensity(wwise_world, source_id, player)
    local camera_handler = player.camera_handler
    local is_observing = camera_handler and camera_handler:is_observing()

    if is_observing then
        local observed_unit = camera_handler:camera_follow_unit()

        player = Managers.state.player_unit_spawn:owner(observed_unit)
    end

    local psyker_overload = 0
    local unit_data_extension = ScriptUnit.has_extension(player.player_unit, "unit_data_system")

    if unit_data_extension then
        local warp_charge_component = unit_data_extension:read_component("warp_charge")

        psyker_overload = warp_charge_component.current_percentage
    end

    WwiseWorld.set_source_parameter(wwise_world, source_id, "psyker_overload", psyker_overload)

    -- Use mod's SFX setting instead of base game peril intensity setting
    local options_peril_slider = mod:get("peril_sfx_intensity") or 100

    WwiseWorld.set_global_parameter(wwise_world, "options_peril_slider", options_peril_slider / 100)
end

local function set_vfx_intensity(world, particle_id, player, previous_values)
    local camera_handler = player.camera_handler
    local is_observing = camera_handler:is_observing()

    if is_observing then
        local observed_unit = camera_handler:camera_follow_unit()

        player = Managers.state.player_unit_spawn:owner(observed_unit)
    end

    local unit_data_extension = ScriptUnit.has_extension(player.player_unit, "unit_data_system")

    if unit_data_extension then
        local base_warp_charge_template = WarpCharge.archetype_warp_charge_template(player)
        local weapon_warp_charge_template = WarpCharge.weapon_warp_charge_template(player.player_unit)
        local dt = Managers.time:delta_time("gameplay")
        local warp_charge_component = unit_data_extension:read_component("warp_charge")
        local current_percent = warp_charge_component.current_percentage
        local base_low_threshold = base_warp_charge_template.low_threshold
        local low_threshold_modifier = weapon_warp_charge_template.low_threshold_modifier or 1
        local low_threshold = base_low_threshold * low_threshold_modifier
        local wanted_value = math.normalize_01(current_percent, low_threshold, 1)
        local last_value = previous_values.chaos_blend or 0
        local delta = wanted_value - last_value
        local length = math.min(math.abs(delta), dt)
        local dir = math.sign(delta)
        local current_value = last_value + dir * length

        World.set_particles_material_scalar(world, particle_id, "warp", "chaos_blend", current_value)

        previous_values.chaos_blend = current_value

        -- Use mod's VFX setting instead of base game peril intensity setting
        local options_peril_slider = mod:get("peril_vfx_intensity") or 100

        World.set_particles_material_scalar(world, particle_id, "warp", "options_peril_slider_vfx", options_peril_slider / 100)
    end
end

local function reset_mood_value(id, value)
    local mood = originals[id].mood
    local key = originals[id].key
    local new_value = value or originals[id].value
    moods[mood][key] = new_value
end

local function remove_mood_value(id)
    local mood = originals[id].mood
    local key = originals[id].key
    moods[mood][key] = nil
end

local function toggle_fx(orig_id, setting_id, enabled_value)
    if mod:get(setting_id) then
        reset_mood_value(orig_id, enabled_value)
    else
        remove_mood_value(orig_id)
    end
end

mod.on_enabled = function(initial_call)
    moods["warped_low_to_high"].particle_material_scalar_funcs = {set_vfx_intensity,}
    for orig_id, item in pairs(originals) do
        if item.toggle then
            toggle_fx(orig_id, item.toggle)
        end
    end
    toggle_fx("source_parameter_funcs", "play_peril_build_up_sfx", {set_sfx_intensity,})
end

mod.on_disabled = function(initial_call)
    for orig_id, _ in pairs(originals) do
        reset_mood_value(orig_id)
    end
end

local checkMoods = false
mod.on_setting_changed = function(setting_id)
    if setting_id == "show_critical_peril_vfx" then
        toggle_fx("critical_peril_vfx", setting_id)
    elseif setting_id == "play_high_peril_sfx" then
        toggle_fx("high_peril_sfx", setting_id)
    elseif setting_id == "play_critical_peril_sfx" then
        toggle_fx("critical_peril_sfx", setting_id)
    elseif setting_id == "play_peril_build_up_sfx" then
        toggle_fx("warp_build_up_loop_start", setting_id)
        toggle_fx("source_parameter_funcs", setting_id, {set_sfx_intensity,})
        checkMoods = true
    end
end

mod:hook_safe("PlayerUnitMoodExtension", "_add_mood", function(self, t, mood_type, reset_time)
    if mood_type == "warped" and not mod:get("play_peril_build_up_sfx") then
        -- Set peril intensity slider in place of disabled source_parameter_funcs
        local options_peril_slider = mod:get("peril_sfx_intensity") or 100
        WwiseWorld.set_global_parameter(self._world, "options_peril_slider", options_peril_slider / 100)
    end
end)

mod:hook("MoodHandler", "_update_active_moods", function(func, self, mood_data)
    if checkMoods then
        if mood_data.warped.status == mood_status.active then
            -- Make sure looping start/stop events are played if mod setting is changed while warped
            if mod:get("play_peril_build_up_sfx")  then
                -- Add warped to added_moods
                self._current_moods_status.warped = mood_status.inactive
            else
                -- Add warped to removing_moods
                mood_data.warped.status = mood_status.removing
            end
        end
        checkMoods = false
    end
    return func(self, mood_data)
end)
