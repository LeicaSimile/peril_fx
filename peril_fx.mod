return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`peril_fx` encountered an error loading the Darktide Mod Framework.")

		new_mod("peril_fx", {
			mod_script       = "peril_fx/scripts/mods/peril_fx/peril_fx",
			mod_data         = "peril_fx/scripts/mods/peril_fx/peril_fx_data",
			mod_localization = "peril_fx/scripts/mods/peril_fx/peril_fx_localization",
		})
	end,
	packages = {},
}
