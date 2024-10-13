local mod = get_mod("peril_fx")

return {
	name = "Peril FX",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "peril_sfx_intensity",
				tooltip = "peril_sfx_intensity_description",
				type = "numeric",
				default_value = 100,
				range = {0, 100}
			},
			{
				setting_id = "peril_vfx_intensity",
				tooltip = "peril_vfx_intensity_description",
				type = "numeric",
				default_value = 100,
				range = {0, 100}
			},
			{
				setting_id = "show_critical_peril_vfx",
				tooltip = "show_critical_peril_vfx_description",
				type = "checkbox",
				default_value = true
			}
		}
	}
}
