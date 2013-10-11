# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# lss_zone_help.rb ver. 1.0.0 beta 30-Sep-13
# The file whith the script, which launches help system.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
	
		class LSS_Zone_Help_Cmd
			def initialize
				lss_zone_help_cmd=UI::Command.new($lsszoneStrings.GetString("Help")){
					resource_dir=LSS_Dirs.new.resource_path
					help_index_path="#{resource_dir}/help/index.html"
					status=UI.openURL(help_index_path)
				}
				lss_zone_help_cmd.small_icon = "./tb_icons/help_24.png"
				lss_zone_help_cmd.large_icon = "./tb_icons/help_32.png"
				lss_zone_help_cmd.tooltip = $lsszoneStrings.GetString("Click to view extension's Help System.")
				$lsszoneToolbar.add_separator
				$lsszoneMenu.add_separator
				$lsszoneToolbar.add_item(lss_zone_help_cmd)
				$lsszoneMenu.add_item(lss_zone_help_cmd)
			end

		end #class LSS_Zone_Help_Cmd

		if( not file_loaded?("lss_zone_help.rb") )
			LSS_Zone_Help_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_help.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	