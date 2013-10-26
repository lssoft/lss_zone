# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# lss_zone_layers_cmd.rb ver. 1.0.2 beta 15-Oct-13
# The script, which contains a class, wich contains 'Zone Layers' toolbar implementation


# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		
		# This class contains 'Zone Layers' toolbar implementation
		
		class LSS_Zone_Layers_Cmd
			def initialize
				zone_layers_toolbar=UI::Toolbar.new($lsszoneStrings.GetString("Zone Layers"))
				zone_layers_cmd=UI::Command.new($lsszoneStrings.GetString("Zone Layers Toolbar")){
					if zone_layers_toolbar.visible?
						zone_layers_toolbar.hide
					else
						zone_layers_toolbar.show
					end
				}
				zone_layers_cmd.set_validation_proc {
					if zone_layers_toolbar.visible?
						MF_CHECKED
					else
						MF_UNCHECKED
					end
				}
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=13
					zone_layers_cmd.small_icon = "./tb_icons/layers_24.png"
					zone_layers_cmd.large_icon = "./tb_icons/layers_32.png"
				else
					zone_layers_cmd.small_icon = "./tb_icons/layers_16.png"
					zone_layers_cmd.large_icon = "./tb_icons/layers_24.png"
				end
				zone_layers_cmd.tooltip = $lsszoneStrings.GetString("Click to toggle 'Zone Layers' toolbar visibility.")
				$lsszoneToolbar.add_item(zone_layers_cmd)
				layers_submenu=$lsszoneMenu.add_submenu($lsszoneStrings.GetString("Zone Layers"))
				layers_submenu.add_item(zone_layers_cmd)
				layers_submenu.add_separator
				
				# Commands of 'Zone Layers' toolbar and submenu
				# Main Layer command
				zone_layer_cmd=UI::Command.new($lsszoneStrings.GetString("Main Layer")){
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.lss_zone_layer # Condition added in ver. 1.0.2 beta 15-Oct-13.
						if zone_layers.lss_zone_layer.visible?
							zone_layers.lss_zone_layer.visible=false
						else
							zone_layers.lss_zone_layer.visible=true
						end
					else
						warn_str=$lsszoneStrings.GetString("There are no 'LSS Zone' layers in an active model.")
						warn_str+="\n"+$lsszoneStrings.GetString("Would you like to create 'LSS Zone' layers?")
						res=UI.messagebox(warn_str, MB_YESNO)
						if res==6
							zone_layers.create_layers
							if zone_layers.lss_zone_layer.visible?
								zone_layers.lss_zone_layer.visible=false
							else
								zone_layers.lss_zone_layer.visible=true
							end
						end
					end
				}
				zone_layer_cmd.set_validation_proc {
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.lss_zone_layer
						if zone_layers.lss_zone_layer.visible?
							MF_CHECKED
						else
							MF_UNCHECKED
						end
					else
						MF_UNCHECKED
					end
				}
				if su_ver.split(".")[0].to_i>=13
					zone_layer_cmd.small_icon = "./tb_icons/layers/lss_zone_24.png"
					zone_layer_cmd.large_icon = "./tb_icons/layers/lss_zone_32.png"
				else
					zone_layer_cmd.small_icon = "./tb_icons/layers/lss_zone_16.png"
					zone_layer_cmd.large_icon = "./tb_icons/layers/lss_zone_24.png"
				end
				zone_layer_cmd.tooltip = $lsszoneStrings.GetString("Click to toggle main zone layer visibility.")
				zone_layers_toolbar.add_item(zone_layer_cmd)
				layers_submenu.add_item(zone_layer_cmd)
				
				# Area Layer command
				area_layer_cmd=UI::Command.new($lsszoneStrings.GetString("Area Layer")){
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.lss_zone_layer # Condition added in ver. 1.0.2 beta 15-Oct-13.
						if zone_layers.area_layer.visible?
							zone_layers.area_layer.visible=false
						else
							zone_layers.area_layer.visible=true
						end
					else
						warn_str=$lsszoneStrings.GetString("There are no 'LSS Zone' layers in an active model.")
						warn_str+="\n"+$lsszoneStrings.GetString("Would you like to create 'LSS Zone' layers?")
						res=UI.messagebox(warn_str, MB_YESNO)
						if res==6
							zone_layers.create_layers
							if zone_layers.area_layer.visible?
								zone_layers.area_layer.visible=false
							else
								zone_layers.area_layer.visible=true
							end
						end
					end
				}
				area_layer_cmd.set_validation_proc {
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.area_layer
						if zone_layers.area_layer.visible?
							MF_CHECKED
						else
							MF_UNCHECKED
						end
					else
						MF_UNCHECKED
					end
				}
				if su_ver.split(".")[0].to_i>=13
					area_layer_cmd.small_icon = "./tb_icons/layers/area_24.png"
					area_layer_cmd.large_icon = "./tb_icons/layers/area_32.png"
				else
					area_layer_cmd.small_icon = "./tb_icons/layers/area_16.png"
					area_layer_cmd.large_icon = "./tb_icons/layers/area_24.png"
				end
				area_layer_cmd.tooltip = $lsszoneStrings.GetString("Click to toggle area layer visibility.")
				zone_layers_toolbar.add_item(area_layer_cmd)
				layers_submenu.add_item(area_layer_cmd)
				
				# Ceiling Layer command
				ceiling_layer_cmd=UI::Command.new($lsszoneStrings.GetString("Ceiling Layer")){
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.lss_zone_layer # Condition added in ver. 1.0.2 beta 15-Oct-13.
						if zone_layers.ceiling_layer.visible?
							zone_layers.ceiling_layer.visible=false
						else
							zone_layers.ceiling_layer.visible=true
						end
					else
						warn_str=$lsszoneStrings.GetString("There are no 'LSS Zone' layers in an active model.")
						warn_str+="\n"+$lsszoneStrings.GetString("Would you like to create 'LSS Zone' layers?")
						res=UI.messagebox(warn_str, MB_YESNO)
						if res==6
							zone_layers.create_layers
							if zone_layers.ceiling_layer.visible?
								zone_layers.ceiling_layer.visible=false
							else
								zone_layers.ceiling_layer.visible=true
							end
						end
					end
				}
				ceiling_layer_cmd.set_validation_proc {
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.ceiling_layer
						if zone_layers.ceiling_layer.visible?
							MF_CHECKED
						else
							MF_UNCHECKED
						end
					else
						MF_UNCHECKED
					end
				}
				if su_ver.split(".")[0].to_i>=13
					ceiling_layer_cmd.small_icon = "./tb_icons/layers/ceiling_24.png"
					ceiling_layer_cmd.large_icon = "./tb_icons/layers/ceiling_32.png"
				else
					ceiling_layer_cmd.small_icon = "./tb_icons/layers/ceiling_16.png"
					ceiling_layer_cmd.large_icon = "./tb_icons/layers/ceiling_24.png"
				end
				ceiling_layer_cmd.tooltip = $lsszoneStrings.GetString("Click to toggle ceiling layer visibility.")
				zone_layers_toolbar.add_item(ceiling_layer_cmd)
				layers_submenu.add_item(ceiling_layer_cmd)
				
				# Walls Layer command
				walls_layer_cmd=UI::Command.new($lsszoneStrings.GetString("Walls Layer")){
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.lss_zone_layer # Condition added in ver. 1.0.2 beta 15-Oct-13.
						if zone_layers.wall_layer.visible?
							zone_layers.wall_layer.visible=false
						else
							zone_layers.wall_layer.visible=true
						end
					else
						warn_str=$lsszoneStrings.GetString("There are no 'LSS Zone' layers in an active model.")
						warn_str+="\n"+$lsszoneStrings.GetString("Would you like to create 'LSS Zone' layers?")
						res=UI.messagebox(warn_str, MB_YESNO)
						if res==6
							zone_layers.create_layers
							if zone_layers.wall_layer.visible?
								zone_layers.wall_layer.visible=false
							else
								zone_layers.wall_layer.visible=true
							end
						end
					end
				}
				walls_layer_cmd.set_validation_proc {
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.wall_layer
						if zone_layers.wall_layer.visible?
							MF_CHECKED
						else
							MF_UNCHECKED
						end
					else
						MF_UNCHECKED
					end
				}
				if su_ver.split(".")[0].to_i>=13
					walls_layer_cmd.small_icon = "./tb_icons/layers/walls_24.png"
					walls_layer_cmd.large_icon = "./tb_icons/layers/walls_32.png"
				else
					walls_layer_cmd.small_icon = "./tb_icons/layers/walls_16.png"
					walls_layer_cmd.large_icon = "./tb_icons/layers/walls_24.png"
				end
				walls_layer_cmd.tooltip = $lsszoneStrings.GetString("Click to toggle walls layer visibility.")
				zone_layers_toolbar.add_item(walls_layer_cmd)
				layers_submenu.add_item(walls_layer_cmd)
				
				# Floor Layer command
				floor_layer_cmd=UI::Command.new($lsszoneStrings.GetString("Floor Layer")){
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.floor_layer # Condition added in ver. 1.0.2 beta 15-Oct-13.
						if zone_layers.floor_layer.visible?
							zone_layers.floor_layer.visible=false
						else
							zone_layers.floor_layer.visible=true
						end
					else
						warn_str=$lsszoneStrings.GetString("There are no 'LSS Zone' layers in an active model.")
						warn_str+="\n"+$lsszoneStrings.GetString("Would you like to create 'LSS Zone' layers?")
						res=UI.messagebox(warn_str, MB_YESNO)
						if res==6
							zone_layers.create_layers
							if zone_layers.floor_layer.visible?
								zone_layers.floor_layer.visible=false
							else
								zone_layers.floor_layer.visible=true
							end
						end
					end
				}
				floor_layer_cmd.set_validation_proc {
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.floor_layer
						if zone_layers.floor_layer.visible?
							MF_CHECKED
						else
							MF_UNCHECKED
						end
					else
						MF_UNCHECKED
					end
				}
				if su_ver.split(".")[0].to_i>=13
					floor_layer_cmd.small_icon = "./tb_icons/layers/floor_24.png"
					floor_layer_cmd.large_icon = "./tb_icons/layers/floor_32.png"
				else
					floor_layer_cmd.small_icon = "./tb_icons/layers/floor_16.png"
					floor_layer_cmd.large_icon = "./tb_icons/layers/floor_24.png"
				end
				floor_layer_cmd.tooltip = $lsszoneStrings.GetString("Click to toggle floor layer visibility.")
				zone_layers_toolbar.add_item(floor_layer_cmd)
				layers_submenu.add_item(floor_layer_cmd)
				
				# Volume Layer command
				volume_layer_cmd=UI::Command.new($lsszoneStrings.GetString("Volume Layer")){
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.volume_layer # Condition added in ver. 1.0.2 beta 15-Oct-13.
						if zone_layers.volume_layer.visible?
							zone_layers.volume_layer.visible=false
						else
							zone_layers.volume_layer.visible=true
						end
					else
						warn_str=$lsszoneStrings.GetString("There are no 'LSS Zone' layers in an active model.")
						warn_str+="\n"+$lsszoneStrings.GetString("Would you like to create 'LSS Zone' layers?")
						res=UI.messagebox(warn_str, MB_YESNO)
						if res==6
							zone_layers.create_layers
							if zone_layers.volume_layer.visible?
								zone_layers.volume_layer.visible=false
							else
								zone_layers.volume_layer.visible=true
							end
						end
					end
				}
				volume_layer_cmd.set_validation_proc {
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.volume_layer
						if zone_layers.volume_layer.visible?
							MF_CHECKED
						else
							MF_UNCHECKED
						end
					else
						MF_UNCHECKED
					end
				}
				if su_ver.split(".")[0].to_i>=13
					volume_layer_cmd.small_icon = "./tb_icons/layers/volume_24.png"
					volume_layer_cmd.large_icon = "./tb_icons/layers/volume_32.png"
				else
					volume_layer_cmd.small_icon = "./tb_icons/layers/volume_16.png"
					volume_layer_cmd.large_icon = "./tb_icons/layers/volume_24.png"
				end
				volume_layer_cmd.tooltip = $lsszoneStrings.GetString("Click to toggle volume layer visibility.")
				zone_layers_toolbar.add_item(volume_layer_cmd)
				layers_submenu.add_item(volume_layer_cmd)
				
				# Openings Layer command
				ops_layer_cmd=UI::Command.new($lsszoneStrings.GetString("Openings Layer")){
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.openings_layer # Condition added in ver. 1.0.2 beta 15-Oct-13.
						if zone_layers.openings_layer.visible?
							zone_layers.openings_layer.visible=false
						else
							zone_layers.openings_layer.visible=true
						end
					else
						warn_str=$lsszoneStrings.GetString("There are no 'LSS Zone' layers in an active model.")
						warn_str+="\n"+$lsszoneStrings.GetString("Would you like to create 'LSS Zone' layers?")
						res=UI.messagebox(warn_str, MB_YESNO)
						if res==6
							zone_layers.create_layers
							if zone_layers.openings_layer.visible?
								zone_layers.openings_layer.visible=false
							else
								zone_layers.openings_layer.visible=true
							end
						end
					end
				}
				ops_layer_cmd.set_validation_proc {
					model = Sketchup.active_model
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.openings_layer
						if zone_layers.openings_layer.visible?
							MF_CHECKED
						else
							MF_UNCHECKED
						end
					else
						MF_UNCHECKED
					end
				}
				if su_ver.split(".")[0].to_i>=13
					ops_layer_cmd.small_icon = "./tb_icons/layers/ops_24.png"
					ops_layer_cmd.large_icon = "./tb_icons/layers/ops_32.png"
				else
					ops_layer_cmd.small_icon = "./tb_icons/layers/ops_16.png"
					ops_layer_cmd.large_icon = "./tb_icons/layers/ops_24.png"
				end
				ops_layer_cmd.tooltip = $lsszoneStrings.GetString("Click to toggle openings layer visibility.")
				zone_layers_toolbar.add_item(ops_layer_cmd)
				layers_submenu.add_item(ops_layer_cmd)
				
				# Hide the Rest command
				hide_rest_cmd=UI::Command.new($lsszoneStrings.GetString("Hide the Rest")){
					model = Sketchup.active_model
					create_if_nil=true
					hidden_layers = model.attribute_dictionary("LSS Zone Hidden Layers", create_if_nil)
					layers = model.layers
					zone_layers=LSS_Zone_Layers.new
					if zone_layers.lss_zone_layer.nil? # Condition added in ver. 1.0.2 beta 26-Oct-13.
						warn_str=$lsszoneStrings.GetString("There are no 'LSS Zone' layers in an active model.")
						warn_str+="\n"+$lsszoneStrings.GetString("Would you like to create 'LSS Zone' layers?")
						res=UI.messagebox(warn_str, MB_YESNO)
						if res==6
							zone_layers.create_layers
						end
					end
					return if zone_layers.lss_zone_layer.nil?
					
					zone_related_layers=Array.new
					zone_related_layers<<zone_layers.lss_zone_layer
					zone_related_layers<<zone_layers.area_layer
					zone_related_layers<<zone_layers.wall_layer
					zone_related_layers<<zone_layers.floor_layer
					zone_related_layers<<zone_layers.ceiling_layer
					zone_related_layers<<zone_layers.volume_layer
					zone_related_layers<<zone_layers.openings_layer
					
					if hidden_layers.length==0
						i=1; tot_cnt=layers.length
						progr_char="|"; rest_char="_"; scale_coeff=1
						progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
						layers.each{|layer|
							if layer
								if (layer.deleted?)==false
									if zone_related_layers.include?(layer)==false
										if layer.visible?
											layer.visible=false
											hidden_layers[layer.name]=true if (layer.visible?)==false # Additional check added 26-Oct-13. The point is that active layer may not be invisible.
										end
									end
								end
							end
							progr_bar.update(i)
							i+=1
							Sketchup.status_text=$lsszoneStrings.GetString("Hiding layers: ") + progr_bar.progr_string
						}
						Sketchup.status_text=""
					else
						i=1; tot_cnt=hidden_layers.length
						progr_char="|"; rest_char="_"; scale_coeff=1
						progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
						hidden_layers.each_key{|layer_name|
							layer=layers[layer_name]
							if layer
								layer.visible=true if (layer.deleted?)==false
							end
							hidden_layers.delete_key(layer_name)
							progr_bar.update(i)
							i+=1
							Sketchup.status_text=$lsszoneStrings.GetString("Unhiding layers: ") + progr_bar.progr_string
						}
						Sketchup.status_text=""
					end
				}
				hide_rest_cmd.set_validation_proc {
					model = Sketchup.active_model
					layers = model.layers
					hidden_layers = model.attribute_dictionary("LSS Zone Hidden Layers")
					if hidden_layers
						if hidden_layers.length>0
							MF_CHECKED
						else
							MF_UNCHECKED
						end
					else
						MF_UNCHECKED
					end
				}
				if su_ver.split(".")[0].to_i>=13
					hide_rest_cmd.small_icon = "./tb_icons/layers/hide_rest_24.png"
					hide_rest_cmd.large_icon = "./tb_icons/layers/hide_rest_32.png"
				else
					hide_rest_cmd.small_icon = "./tb_icons/layers/hide_rest_16.png"
					hide_rest_cmd.large_icon = "./tb_icons/layers/hide_rest_24.png"
				end
				hide_rest_cmd.tooltip = $lsszoneStrings.GetString("Click to hide all layers except 'LSS Zone' related ones.")
				zone_layers_toolbar.add_separator
				zone_layers_toolbar.add_item(hide_rest_cmd)
				layers_submenu.add_separator
				layers_submenu.add_item(hide_rest_cmd)
			end

		end #class LSS_Zone_Layers_Cmd

		if( not file_loaded?("lss_zone_layers_cmd.rb") )
			LSS_Zone_Layers_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_layers_cmd.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	