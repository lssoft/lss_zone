# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# lss_zone_loader.rb ver. 1.0.0 beta 30-Sep-13

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension

		#initializes $lsszoneToolbar and $lsszoneMenu
		require 'lss_zone/lss_zone_toolbar.rb'
		
		#loads the script, which adds some utility classes
		require 'lss_zone/lss_zone_utils.rb'

		#loads the script, which adds 'LSS Zone' command to the menu and to the toolbar
		require 'lss_zone/lss_zone_tool.rb'
		
		#loads the script, which contains 'Link Openings' dialog implementation
		require 'lss_zone/lss_zone_link_ops.rb'
		
		#loads the script, which implements attaching labels with zone attributes to existing zone objects in an active model
		require 'lss_zone/lss_zone_labels.rb'
		
		#loads the script, which generates list of all or selected zones in an active model
		require 'lss_zone/lss_zone_list.rb'
		
		#loads the script, which recalculates calculated attributes of created zones
		require 'lss_zone/lss_zone_recalc.rb'
		
		#loads the script, which refreshes previously created zones (creates all geometry again "from scratch")
		require 'lss_zone/lss_zone_rebuild.rb'
		
		#loads the script, which contains 'Zone Properties' dialog implementation
		require 'lss_zone/lss_zone_props.rb'
		
		#loads the script, which launches help system
		require 'lss_zone/lss_zone_help.rb'
		
		#loads the script, which opens extension's official web-page
		require 'lss_zone/lss_zone_web.rb'
		
	end #module LSS_Zone_Extension
end #module LSS_Extensions