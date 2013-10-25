# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# lss_zone_recalc.rb ver. 1.1.0 beta 25-Oct-13
# The file, which contains created zone(s) refreshing implementation

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		#loads class wich contains Zone Entity
		require 'lss_zone/lss_zone_entity.rb'

		class LSS_Zone_Recalc_Cmd
			def initialize
				lss_zone_recalc=LSS_Zone_Recalc_Tool.new
				lss_zone_recalc_cmd=UI::Command.new($lsszoneStrings.GetString("Recalculate")){
					Sketchup.active_model.select_tool(lss_zone_recalc)
					lss_zone_recalc.process_selection
				}
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=13
					lss_zone_recalc_cmd.small_icon = "./tb_icons/recalc_24.png"
					lss_zone_recalc_cmd.large_icon = "./tb_icons/recalc_32.png"
				else
					lss_zone_recalc_cmd.small_icon = "./tb_icons/recalc_16.png"
					lss_zone_recalc_cmd.large_icon = "./tb_icons/recalc_24.png"
				end
				lss_zone_recalc_cmd.tooltip = $lsszoneStrings.GetString("Select zones, then click to recalculate.")
				lss_zone_recalc_cmd.menu_text=$lsszoneStrings.GetString("Recalculate")
				$lsszoneToolbar.add_item(lss_zone_recalc_cmd)
				$lsszoneMenu.add_item(lss_zone_recalc_cmd)
			end
		end #class LSS_Zone_Recalc_Cmd
		
		# This class contains implementation of a tool, which refreshes quantitave attributes of selected zones
		# in order to make them corresponded to an actual geometry of a zone an its internal elements.
		
		class LSS_Zone_Recalc_Tool
			def initialize
				@model=Sketchup.active_model
				@selection=@model.selection
			end
			
			def process_selection(stand_alone=true)
				if @selection.length==0
					UI.messagebox($lsszoneStrings.GetString("It is necessary to select some zone objects before launching 'Recalculate' command."))
				else
					@model.start_operation($lsszoneStrings.GetString("Recalculate Zone(s)"), true) if stand_alone
					# If stand_alone==false, then method is called from another @model.start_operation
						i=1; tot_cnt=@selection.length
						progr_char="|"; rest_char="_"; scale_coeff=1
						progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
						@selection.each{|ent|
							if ent.is_a?(Sketchup::Group)
								number=ent.get_attribute("LSS_Zone_Entity", "number")
								if number
									# Set the second optional parameter to 'false' so 'recalc' method does not perform '@model.start_operation'
									self.recalc(ent, false)
								end
							end
							progr_bar.update(i)
							i+=1
							Sketchup.status_text=$lsszoneStrings.GetString("Recalculating attributes: ") + progr_bar.progr_string
						}
						Sketchup.status_text=$lsszoneStrings.GetString("Recalculation complete.")
					@model.commit_operation if stand_alone
					# If stand_alone==false, then method is called from another @model.start_operation
					Sketchup.active_model.select_tool(nil)
				end
			end
			
			def recalc(zone_group, stand_alone=true)
				@zone_group=zone_group
				@number=@zone_group.get_attribute("LSS_Zone_Entity", "number")
				@name=@zone_group.get_attribute("LSS_Zone_Entity", "name")
				@floor_level=@zone_group.get_attribute("LSS_Zone_Entity", "floor_level")
				@floor_number=@zone_group.get_attribute("LSS_Zone_Entity", "floor_number")
				@category=@zone_group.get_attribute("LSS_Zone_Entity", "category")
				@memo=@zone_group.get_attribute("LSS_Zone_Entity", "memo")
				@floor_material=@zone_group.get_attribute("LSS_Zone_Entity", "floor_material")
				@ceiling_material=@zone_group.get_attribute("LSS_Zone_Entity", "ceiling_material")
				@wall_material=@zone_group.get_attribute("LSS_Zone_Entity", "wall_material")
				@floor_refno=@zone_group.get_attribute("LSS_Zone_Entity", "floor_refno")
				@ceiling_refno=@zone_group.get_attribute("LSS_Zone_Entity", "ceiling_refno")
				@wall_refno=@zone_group.get_attribute("LSS_Zone_Entity", "wall_refno")
				
				@labels_arr=Array.new
				zone_attr_dicts=@zone_group.attribute_dictionaries
				zone_attr_dicts.each{|dict|
					if dict.name.split(":")[0]=="zone_label"
						preset_name=dict["preset_name"]
						label_template=dict["label_template"]
						label_layer=dict["label_layer"]
						@labels_arr<<[preset_name, label_template, label_layer]
					end
				}
				
				@area=0; @perimeter=0
				@floor_area=0; @ceiling_area=0; @wall_area=0
				@zone_group.entities.each{|ent|
					ent_type=ent.get_attribute("LSS_Zone_Element", "type")
					case ent_type
						when "area"
							ent.entities.each{|elt|
								if elt.is_a?(Sketchup::Face)
									@area+=elt.area
									elt.edges.each{|edg|
										@perimeter+=edg.length
									}
								end
							}
						when "floor"
							ent.entities.each{|elt|
								if elt.is_a?(Sketchup::Face)
									@floor_area+=elt.area
								end
							}
						when "ceiling"
							ent.entities.each{|elt|
								if elt.is_a?(Sketchup::Face)
									@ceiling_area+=elt.area
								end
							}
						when "wall"
							ent.entities.each{|elt|
								if elt.is_a?(Sketchup::Face)
									@wall_area+=elt.area
								end
							}
						when "volume"
							@volume=ent.volume
							bnds=ent.bounds
							@height=bnds.max.z-bnds.min.z
					end
				}
				
				# Read openings
				@openings_arr=Array.new
				ops_groups_arr=Array.new
				@zone_group.entities.each{|grp|
					op_type=grp.get_attribute("LSS_Zone_Element", "type")
					if op_type
						if op_type.include?("opening")
							ops_groups_arr<<grp
						end
					end
				}
				@wall_ext_ops_area=0
				@wall_int_ops_area=0
				@floor_ext_ops_area=0
				@floor_int_ops_area=0
				@ceiling_ext_ops_area=0
				@ceiling_int_ops_area=0
				ops_groups_arr.each{|op_grp|
					op_type=op_grp.get_attribute("LSS_Zone_Element", "type")
					is_internal=op_grp.get_attribute("LSS_Zone_Element", "is_internal")
					op_face=op_grp.entities.select{|ent| (ent.is_a?(Sketchup::Face))}[0]
					if op_face
						opening_area=op_face.area
						case op_type
							when "wall_opening"
							@wall_area-=opening_area
							if is_internal
								@wall_int_ops_area+=opening_area
							else
								@wall_ext_ops_area+=opening_area
							end
							when "floor_opening"
							@floor_area-=opening_area
							if is_internal
								@floor_int_ops_area+=opening_area
							else
								@floor_ext_ops_area+=opening_area
							end
							when "ceiling_opening"
							@ceiling_area-=opening_area
							if is_internal
								@ceiling_int_ops_area+=opening_area
							else
								@ceiling_ext_ops_area+=opening_area
							end
						end
					end
				}
				
				@model.start_operation($lsszoneStrings.GetString("Recalculate Zone's Attributes"), true) if stand_alone
				# If stand_alone==false, then method is called from another @model.start_operation
					@zone_group.set_attribute("LSS_Zone_Entity", "area", @area)
					@zone_group.set_attribute("LSS_Zone_Entity", "perimeter", @perimeter)
					@zone_group.set_attribute("LSS_Zone_Entity", "height", @height)
					@zone_group.set_attribute("LSS_Zone_Entity", "volume", @volume)
					
					@zone_group.set_attribute("LSS_Zone_Entity", "floor_area", @floor_area)
					@zone_group.set_attribute("LSS_Zone_Entity", "ceiling_area", @ceiling_area)
					@zone_group.set_attribute("LSS_Zone_Entity", "wall_area", @wall_area)
					
					@zone_group.set_attribute("LSS_Zone_Entity", "wall_int_ops_area", @wall_int_ops_area)
					@zone_group.set_attribute("LSS_Zone_Entity", "wall_ext_ops_area", @wall_ext_ops_area)
					@zone_group.set_attribute("LSS_Zone_Entity", "floor_int_ops_area", @floor_int_ops_area)
					@zone_group.set_attribute("LSS_Zone_Entity", "floor_ext_ops_area", @floor_ext_ops_area)
					@zone_group.set_attribute("LSS_Zone_Entity", "ceiling_int_ops_area", @ceiling_int_ops_area)
					@zone_group.set_attribute("LSS_Zone_Entity", "ceiling_ext_ops_area", @ceiling_ext_ops_area)

					# Clear previous labels
					labels2erase=@zone_group.entities.select{|label| (label.get_attribute("LSS_Zone_Entity", "label_name"))}
					@zone_group.entities.erase_entities(labels2erase)
					# Re-attach labels in order to refresh calculated values
					layer_names=Array.new
					layers=@model.layers
					layers.each{|layer|
						layer_names<<layer.name
					}
					@labels_arr.each{|label|
						preset_name=label[0]
						label_template=label[1]
						label_layer=label[2]
						attr_dict=@zone_group.attribute_dictionary("LSS_Zone_Entity")
						label_txt="#{label_template}"
						attr_dict.each_key{|key|
							attr_name="@#{key}"
							value=attr_dict[key]
							value_type=Sketchup.read_default("LSS Zone Data Types", key)
							case value_type
								when "distance"
									dist_str=Sketchup.format_length(value.to_f).to_s
									value=dist_str
								when "area"
									area_str=Sketchup.format_area(value.to_f).to_s
									value=area_str
								when "volume"
									vol_str=LSS_Math.new.format_volume(value)
									value=vol_str
								else
									
							end
							label_txt.gsub!(attr_name, value.to_s)
						}
						txt_pos=@zone_group.bounds.center
						label_obj=@zone_group.entities.add_text(label_txt, txt_pos)
						if layer_names.include?(label_layer)==false
							layers.add(label_layer)
						end
						label_obj.layer=label_layer
						label_obj.set_attribute("LSS_Zone_Entity", "label_name", preset_name)
						dict_name="zone_label: "+preset_name
						@zone_group.set_attribute(dict_name, "preset_name", preset_name)
						@zone_group.set_attribute(dict_name, "label_template", label_template)
						@zone_group.set_attribute(dict_name, "label_layer", label_layer)
					}
				@model.commit_operation if stand_alone
				# If stand_alone==false, then method is called from another @model.start_operation
				
				#Return created zone group
				@zone_group
			end
			
			
		end #class LSS_Zone_Recalc_Tool

		if( not file_loaded?("lss_zone_recalc.rb") )
			LSS_Zone_Recalc_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_recalc.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	