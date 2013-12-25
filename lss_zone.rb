# lss_zone.rb ver. 1.2.1 alpha 25-Dec-13
# This extension allows to create "zone-objects" or just "zones" in an active model. Each created zone
# may store geometric (area, perimeter, height, volume) and other (name, number, category etc) properties.
# It is possible to display any of above properties by turning on labels of "Zones" and what is more
# important it is possible to list all or selected zones in a window.

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		require 'sketchup.rb'
		require 'extensions.rb'
		require 'LangHandler.rb'

		$lsszoneStrings = LanguageHandler.new("lss_zone.strings")
		ext_name=$lsszoneStrings.GetString("LSS Zone")
		zone_ext = SketchupExtension.new(ext_name, "lss_zone/lss_zone_loader.rb")

		zone_ext.description=$lsszoneStrings.GetString("This extension allows to create 'zone-objects' or just 'zones' in an active model. Each created zone may store geometric and other properties.")
		zone_ext.copyright="(c)2013, Links' System Software"
		zone_ext.version="1.2.1 alpha 25-Dec-13"
		zone_ext.creator="Links' System Software"
		Sketchup.register_extension(zone_ext, true)
	end #module LSS_Zone_Extension
end #module LSS_Extensions