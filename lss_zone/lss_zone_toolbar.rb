# lss_zone_toolbar.rb ver. 1.1.2 beta 09-Nov-13
# File where extension's toolbar and menu entry initialization take place.

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
	
		# This class initializes LSS Zone Toolbar
		
		class LSS_Zone_Toolbar
			def initialize
			  $lsszoneToolbar = UI::Toolbar.new($lsszoneStrings.GetString("LSS Zone"))
			  $lsszoneMenu = UI.menu("Plugins").add_submenu($lsszoneStrings.GetString("LSS Zone"))
			end
		end #class LSS_Zone_Toolbar
		
		if( not file_loaded?("lss_zone_toolbar.rb") )
			lsszone_toolbar=LSS_Zone_Toolbar.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_toolbar.rb")	
	end #module LSS_Zone_Extension
end #module LSS_Extensions