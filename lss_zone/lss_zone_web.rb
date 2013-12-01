# lss_zone_web.rb ver. 1.2.0 beta 01-Dec-13
# The script, which loads extension's official web-page in a default browser.

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		
		# This class adds "Visit Extension's Web Page" to LSS Zone toolbar and LSS Zone submenu.
		# It also adds "About" command to LSS Zone submenu.
		
		class LSS_Zone_Web_Cmd
			def initialize
				
				# Add Visit Extension's Web Page command
				lss_zone_web_cmd=UI::Command.new($lsszoneStrings.GetString("Visit Extension's Web Page")){
					lss_zone_url="http://sites.google.com/site/lssoft2011/home/lss-zone"
					status=UI.openURL(lss_zone_url)
				}
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=13
					lss_zone_web_cmd.small_icon = "./tb_icons/web_24.png"
					lss_zone_web_cmd.large_icon = "./tb_icons/web_32.png"
				else
					lss_zone_web_cmd.small_icon = "./tb_icons/web_16.png"
					lss_zone_web_cmd.large_icon = "./tb_icons/web_24.png"
				end
				
				lss_zone_web_cmd.tooltip = $lsszoneStrings.GetString("Click to visit extension's official web-page.")
				$lsszoneToolbar.add_item(lss_zone_web_cmd)
				$lsszoneMenu.add_item(lss_zone_web_cmd)
				
				# Add 'About' dialog
				lss_zone_about_cmd=UI::Command.new($lsszoneStrings.GetString("About")){
					about_str=""
					about_str+="LSS Zone ver. 1.2.0 beta (01-Dec-13)\n\n"
					about_str+="E-mail1: designer@ls-software.ru\n"
					about_str+="E-mail2: kirill2007_77@mail.ru\n"
					about_str+="web-site: http://sites.google.com/site/lssoft2011/\n"
					about_str+="(C) Links System Software 2013"
					about_str+="\n\n Third Party Components\n\n"
					about_str+="Auto-suggest control, version 2.4, October 10th 2009.\n"
					about_str+="(c) 2007-2009 Dmitriy Khudorozhkov (dmitrykhudorozhkov@yahoo.com)\n"
					about_str+="\n Raphael 2.1.0 - JavaScript Vector Library\n"
					about_str+="Copyright © 2008-2012 Dmitry Baranovskiy (http://raphaeljs.com)\n"
					about_str+="Copyright © 2008-2012 Sencha Labs (http://sencha.com)\n"
					about_str+="Licensed under the MIT (http://raphaeljs.com/license.html) license.\n"
					UI.messagebox(about_str,MB_MULTILINE,"LSS Zone")
				}
				$lsszoneMenu.add_item(lss_zone_about_cmd)
			end

		end #class LSS_Zone_Web_Cmd

		if( not file_loaded?("lss_zone_web.rb") )
			LSS_Zone_Web_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_web.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	