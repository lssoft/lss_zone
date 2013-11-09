# lss_zone_loader.rb ver. 1.1.2 beta 08-Nov-13
# This file contains a script, which loads all available LSS Zone tools a commands.
# Order of lines in this file matters it is basically the same as an order of
# buttons in LSS Zone toolbar and an order of menu items in LSS Zone sub-menu.

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

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
		
		#loads the script, which contains 'Filter' dialog implementation. Added in ver. 1.1.0 20-Oct-13.
		require 'lss_zone/lss_zone_filter.rb'
		
		#loads the script, which contains 'Zone Layers' toolbar implementation. Added 08-Oct-13.
		require 'lss_zone/lss_zone_layers_cmd.rb'
		
		#loads the script, which launches help system
		require 'lss_zone/lss_zone_help.rb'
		
		#loads the script, which opens extension's official web-page
		require 'lss_zone/lss_zone_web.rb'
		
	end #module LSS_Zone_Extension
end #module LSS_Extensions