-- Author: LeicaSimile

local mod = get_mod("peril_fx")
local MoodSettings = require("scripts/settings/camera/mood/mood_settings")
local moods = MoodSettings.moods
local WarpCharge = require("scripts/utilities/warp_charge")
local orig_source_parameter_func = moods["warped"].source_parameter_funcs
local orig_particles_func = moods["warped_low_to_high"].particle_material_scalar_funcs
local orig_critical_peril_vfx = moods["warped_critical"].particle_effects_looping

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

local function toggle_critical_peril_vfx()
    if mod:get("show_critical_peril_vfx") then
        moods["warped_critical"].particle_effects_looping = orig_critical_peril_vfx
    else
        moods["warped_critical"].particle_effects_looping = nil
    end
end

mod.on_enabled = function (initial_call)
    moods["warped"].source_parameter_funcs = {set_sfx_intensity,}
    moods["warped_low_to_high"].particle_material_scalar_funcs = {set_vfx_intensity,}
    toggle_critical_peril_vfx()
end

mod.on_setting_changed = function (setting_id)
    if setting_id == "show_critical_peril_vfx" then
        toggle_critical_peril_vfx()
    end
end

mod.on_disabled = function (initial_call)
    moods["warped"].source_parameter_funcs = orig_source_parameter_func
    moods["warped_low_to_high"].particle_material_scalar_funcs = orig_particles_func
    moods["warped_critical"].particle_effects_looping = orig_critical_peril_vfx
end
