# lss_zone_layers.rb ver. 1.1.2 beta 08-Nov-13
# The script, which contains a class, wich makes layers to store all necessary zone elements in an active model

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		
		# This is a service class, which provides access to layers for zone object and for all its internal elements.
		
		class LSS_Zone_Layers
			attr_accessor :lss_zone_layer
			attr_accessor :area_layer
			attr_accessor :wall_layer
			attr_accessor :floor_layer
			attr_accessor :ceiling_layer
			attr_accessor :volume_layer
			attr_accessor :openings_layer
			
			# Initialize layers. Initialization will return 'nil' values in case if there is no layers structure in an active model.
			def initialize
				@model = Sketchup.active_model
				@layers = @model.layers
				@lss_zone_layer=@layers[$lsszoneStrings.GetString("LSS Zone")]
				@area_layer=@layers[$lsszoneStrings.GetString("LSS Zone Area")]
				@wall_layer=@layers[$lsszoneStrings.GetString("LSS Zone Wall")]
				@floor_layer=@layers[$lsszoneStrings.GetString("LSS Zone Floor")]
				@ceiling_layer=@layers[$lsszoneStrings.GetString("LSS Zone Ceiling")]
				@volume_layer=@layers[$lsszoneStrings.GetString("LSS Zone Volume")]
				@openings_layer=@layers[$lsszoneStrings.GetString("LSS Zone Openings")]
			end
			
			# Method which creates layers structure
			def create_layers
				area_exist=false; wall_exist=false; floor_exist=false; ceiling_exist=false; volume_exist=false; openings_exist=false
				area_exist=true if @layers[$lsszoneStrings.GetString("LSS Zone Area")]
				wall_exist=true if @layers[$lsszoneStrings.GetString("LSS Zone Wall")]
				floor_exist=true if @layers[$lsszoneStrings.GetString("LSS Zone Floor")]
				ceiling_exist=true if @layers[$lsszoneStrings.GetString("LSS Zone Ceiling")]
				volume_exist=true if @layers[$lsszoneStrings.GetString("LSS Zone Volume")]
				openings_exist=true if @layers[$lsszoneStrings.GetString("LSS Zone Openings")]
				
				@lss_zone_layer=@layers.add($lsszoneStrings.GetString("LSS Zone"))
				@area_layer=@layers.add($lsszoneStrings.GetString("LSS Zone Area"))
				@wall_layer=@layers.add($lsszoneStrings.GetString("LSS Zone Wall"))
				@floor_layer=@layers.add($lsszoneStrings.GetString("LSS Zone Floor"))
				@ceiling_layer=@layers.add($lsszoneStrings.GetString("LSS Zone Ceiling"))
				@volume_layer=@layers.add($lsszoneStrings.GetString("LSS Zone Volume"))
				@openings_layer=@layers.add($lsszoneStrings.GetString("LSS Zone Openings"))
				# @area_layer.visible=false
				@wall_layer.visible=false if wall_exist==false
				@floor_layer.visible=false if floor_exist==false
				@ceiling_layer.visible=false if ceiling_exist==false
				@volume_layer.visible=false if volume_exist==false
				@openings_layer.visible=false if openings_exist==false
			end
		end #class LSS_Zone_Layers
	end #module LSS_Zone_Extension
end #module LSS_Extensions	