# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# lss_zone_settings.rb ver. 1.0.0 beta 30-Sep-13
# The file, which contains 'Global Settings' dialog implementation

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		#loads class wich contains Zone Entity
		require 'lss_zone/lss_zone_entity.rb'

		class LSS_Zone_Settings_Cmd
			def initialize
				lss_zone_settings_cmd=UI::Command.new($lsszoneStrings.GetString("Global Settings")){
					
				}
				lss_zone_settings_cmd.small_icon = "./tb_icons/settings_24.png"
				lss_zone_settings_cmd.large_icon = "./tb_icons/settings_32.png"
				lss_zone_settings_cmd.tooltip = $lsszoneStrings.GetString("Click to adjust extension's global settings.")
				$lsszoneToolbar.add_item(lss_zone_settings_cmd)
				$lsszoneMenu.add_item(lss_zone_settings_cmd)
			end

		end #class LSS_Zone_Settings_Cmd

		if( not file_loaded?("lss_zone_settings.rb") )
			LSS_Zone_Settings_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_settings.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	