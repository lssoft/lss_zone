# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# lss_zone_props.rb ver. 1.1.0 beta 25-Oct-13
# The file, which contains 'Zone Properties' dialog implementation

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		#loads class wich contains Zone Entity
		require 'lss_zone/lss_zone_entity.rb'

		class LSS_Zone_Props_Cmd
			def initialize
				lss_zone_props_cmd=UI::Command.new($lsszoneStrings.GetString("View/Edit Properties")){
					lss_zone_props=LSS_Zone_Props.new
					lss_zone_props.activate
				}
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=13
					lss_zone_props_cmd.small_icon = "./tb_icons/props_24.png"
					lss_zone_props_cmd.large_icon = "./tb_icons/props_32.png"
				else
					lss_zone_props_cmd.small_icon = "./tb_icons/props_16.png"
					lss_zone_props_cmd.large_icon = "./tb_icons/props_24.png"
				end
				lss_zone_props_cmd.tooltip = $lsszoneStrings.GetString("Select zones, then click to view/edit their properties.")
				$lsszoneToolbar.add_item(lss_zone_props_cmd)
				$lsszoneMenu.add_item(lss_zone_props_cmd)
			end
		end #class LSS_Zone_Props_Cmd
		
		# This class contains implementation of 'Properties' dialog.
		
		class LSS_Zone_Props
			attr_accessor :category
			def initialize
				@model=Sketchup.active_model
				@selection=@model.selection
				@settings_hash=Hash.new
				@props_list_content="zone_only" # Alternative properties list representation is 'all'
				@all_props=Hash.new
				@dicts2erase=Array.new
				@attrs2erase=Array.new
				@dict_new_names=Hash.new
				@new_attrs=Array.new
				@rebuild_on_apply="true"
				@zone_types_cnt=Hash.new
			end
			
			def selection_filter
				@zones_arr=Array.new
				selected_groups=@selection.select{|ent| ent.is_a?(Sketchup::Group)}
				@zones_arr=selected_groups.select{|grp| not(grp.get_attribute("LSS_Zone_Entity", "number").nil?)}
			end
			
			def obtain_common_settings
				@zone_types_cnt=Hash.new
				if @zones_arr.length==0
					return
				end
				@zone_types_cnt["room"]=0; @zone_types_cnt["box"]=0; @zone_types_cnt["flat"]=0
				etalon_zone=@zones_arr.first
				@number=etalon_zone.get_attribute("LSS_Zone_Entity", "number")
				@name=etalon_zone.get_attribute("LSS_Zone_Entity", "name")
				@height=etalon_zone.get_attribute("LSS_Zone_Entity", "height")
				@floor_number=etalon_zone.get_attribute("LSS_Zone_Entity", "floor_number")
				@category=etalon_zone.get_attribute("LSS_Zone_Entity", "category")
				
				@floor_level=etalon_zone.get_attribute("LSS_Zone_Entity", "floor_level")
				@memo=etalon_zone.get_attribute("LSS_Zone_Entity", "memo")
				@floor_material=etalon_zone.get_attribute("LSS_Zone_Entity", "floor_material")
				@wall_material=etalon_zone.get_attribute("LSS_Zone_Entity", "wall_material")
				@ceiling_material=etalon_zone.get_attribute("LSS_Zone_Entity", "ceiling_material")
				
				@floor_area=etalon_zone.get_attribute("LSS_Zone_Entity", "floor_area")
				@wall_area=etalon_zone.get_attribute("LSS_Zone_Entity", "wall_area")
				@ceiling_area=etalon_zone.get_attribute("LSS_Zone_Entity", "ceiling_area")
				@floor_refno=etalon_zone.get_attribute("LSS_Zone_Entity", "floor_refno")
				@wall_refno=etalon_zone.get_attribute("LSS_Zone_Entity", "wall_refno")
				@ceiling_refno=etalon_zone.get_attribute("LSS_Zone_Entity", "ceiling_refno")
				
				@zone_type=etalon_zone.get_attribute("LSS_Zone_Entity", "zone_type")
				@floors_count=etalon_zone.get_attribute("LSS_Zone_Entity", "floors_count")
				
				@area=0; @perimeter=0; @volume=0
				i=1; tot_cnt=@zones_arr.length
				progr_char="|"; rest_char="_"; scale_coeff=1
				progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
				@zones_arr.each{|zone_obj|
					@number="..." if zone_obj.get_attribute("LSS_Zone_Entity", "number").to_s!=@number.to_s
					@name="..." if zone_obj.get_attribute("LSS_Zone_Entity", "name").to_s!=@name.to_s
					@height="..." if zone_obj.get_attribute("LSS_Zone_Entity", "height").to_s!=@height.to_s
					@floor_number="..." if zone_obj.get_attribute("LSS_Zone_Entity", "floor_number").to_s!=@floor_number.to_s
					@category="..." if zone_obj.get_attribute("LSS_Zone_Entity", "category").to_s!=@category.to_s
					@floor_level="..." if zone_obj.get_attribute("LSS_Zone_Entity", "floor_level").to_s!=@floor_level.to_s
					@memo="..." if zone_obj.get_attribute("LSS_Zone_Entity", "memo").to_s!=@memo
					@floor_material="..." if zone_obj.get_attribute("LSS_Zone_Entity", "floor_material").to_s!=@floor_material
					@wall_material="..." if zone_obj.get_attribute("LSS_Zone_Entity", "wall_material").to_s!=@wall_material
					@ceiling_material="..." if zone_obj.get_attribute("LSS_Zone_Entity", "ceiling_material").to_s!=@ceiling_material
					
					@floor_refno="..." if zone_obj.get_attribute("LSS_Zone_Entity", "floor_refno").to_s!=@floor_refno
					@wall_refno="..." if zone_obj.get_attribute("LSS_Zone_Entity", "wall_refno").to_s!=@wall_refno
					@ceiling_refno="..." if zone_obj.get_attribute("LSS_Zone_Entity", "ceiling_refno").to_s!=@ceiling_refno
					
					@zone_type="..." if zone_obj.get_attribute("LSS_Zone_Entity", "zone_type").to_s!=@zone_type
					# Sum geometry properties
					@area+=zone_obj.get_attribute("LSS_Zone_Entity", "area").to_f
					@perimeter+=zone_obj.get_attribute("LSS_Zone_Entity", "perimeter").to_f
					# Condition added ver. 1.0.1 beta 09-Oct-13
					if zone_obj.get_attribute("LSS_Zone_Entity", "zone_type")!="flat"
						@volume+=zone_obj.get_attribute("LSS_Zone_Entity", "volume").to_f
					end
					# Condition added ver. 1.0.1 beta 09-Oct-13
					if zone_obj.get_attribute("LSS_Zone_Entity", "zone_type")=="room"
						@floor_area="..." if zone_obj.get_attribute("LSS_Zone_Entity", "floor_area").to_s!=@floor_area.to_s
						@ceiling_area="..." if zone_obj.get_attribute("LSS_Zone_Entity", "ceiling_area").to_s!=@ceiling_area.to_s
						@wall_area="..." if zone_obj.get_attribute("LSS_Zone_Entity", "wall_area").to_s!=@wall_area.to_s
					end
					if zone_obj.get_attribute("LSS_Zone_Entity", "zone_type")=="box"
						@floors_count="..." if zone_obj.get_attribute("LSS_Zone_Entity", "floors_count").to_s!=@floors_count.to_s
					end
					# Zones' types count. Added in ver. 1.1.0 21-Oct-13.
					case zone_obj.get_attribute("LSS_Zone_Entity", "zone_type")
						when "room"
						@zone_types_cnt["room"]+=1
						when "box"
						@zone_types_cnt["box"]+=1
						when "flat"
						@zone_types_cnt["flat"]+=1
						else # Treat 'nil' as a 'room' type
						@zone_types_cnt["room"]+=1
					end
					progr_bar.update(i)
					i+=1
					Sketchup.status_text=$lsszoneStrings.GetString("Reading attributes: ") + progr_bar.progr_string
				}
				Sketchup.status_text=$lsszoneStrings.GetString("Attributes reading complete.")
				self.settings2hash
			end
			
			def activate
				return if $props_dial_is_active
				self.read_defaults
				if @props_list_content=="zone_only"
					self.selection_filter
					self.obtain_common_settings
					self.create_web_dial
				else
					self.selection_filter
					self.create_web_dial
					self.read_all_attributes
				end
				@dicts2erase=Array.new
				@attrs2erase=Array.new
				@dict_new_names=Hash.new
				@new_attrs=Array.new
				$props_dial_is_active=true
			end
			
			def refresh
				if @props_list_content=="zone_only"
					self.selection_filter
					self.obtain_common_settings
				else
					self.selection_filter
					self.read_all_attributes
				end
				@dicts2erase=Array.new
				@attrs2erase=Array.new
				@dict_new_names=Hash.new
				@new_attrs=Array.new
			end
			
			def settings2hash
				@settings_hash["number"]=[@number, "string"]
				@settings_hash["name"]=[@name, "string"]
				@settings_hash["height"]=[@height, "distance"]
				@settings_hash["floor_number"]=[@floor_number, "string"]
				@settings_hash["category"]=[@category, "string"]
				# Part of settings without defaults
				@settings_hash["area"]=[@area, "area"]
				@settings_hash["perimeter"]=[@perimeter, "distance"]
				@settings_hash["volume"]=[@volume, "volume"]
				@settings_hash["floor_level"]=[@floor_level, "distance"]
				@settings_hash["memo"]=[@memo, "string"]
				@settings_hash["floor_material"]=[@floor_material, "string"]
				@settings_hash["wall_material"]=[@wall_material, "string"]
				@settings_hash["ceiling_material"]=[@ceiling_material, "string"]
				
				@settings_hash["floor_area"]=[@floor_area, "area"]
				@settings_hash["wall_area"]=[@wall_area, "area"]
				@settings_hash["ceiling_area"]=[@ceiling_area, "area"]
				@settings_hash["floor_refno"]=[@floor_refno, "string"]
				@settings_hash["wall_refno"]=[@wall_refno, "string"]
				@settings_hash["ceiling_refno"]=[@ceiling_refno, "string"]
				
				@settings_hash["props_list_content"]=[@props_list_content, "string"]
				@settings_hash["rebuild_on_apply"]=[@rebuild_on_apply, "boolean"]
				
				@settings_hash["zone_type"]=[@zone_type, "string"]
				@settings_hash["floors_count"]=[@floors_count, "integer"]
			end
			
			def hash2settings
				return if @settings_hash.keys.length==0
				@number=@settings_hash["number"][0]
				@name=@settings_hash["name"][0]
				@height=@settings_hash["height"][0]
				@floor_number=@settings_hash["floor_number"][0]
				@category=@settings_hash["category"][0]
				
				@area=@settings_hash["area"][0]
				@perimeter=@settings_hash["perimeter"][0]
				@volume=@settings_hash["volume"][0]
				
				@floor_level=@settings_hash["floor_level"][0]
				@memo=@settings_hash["memo"][0]
				@floor_material=@settings_hash["floor_material"][0]
				@wall_material=@settings_hash["wall_material"][0]
				@ceiling_material=@settings_hash["ceiling_material"][0]
				
				@floor_area=@settings_hash["floor_area"][0]
				@wall_area=@settings_hash["wall_area"][0]
				@ceiling_area=@settings_hash["ceiling_area"][0]
				@floor_refno=@settings_hash["floor_refno"][0]
				@wall_refno=@settings_hash["wall_refno"][0]
				@ceiling_refno=@settings_hash["ceiling_refno"][0]
				
				@props_list_content=@settings_hash["props_list_content"][0]
				@rebuild_on_apply=@settings_hash["rebuild_on_apply"][0]
				
				@zone_type=@settings_hash["zone_type"][0]
				@floors_count=@settings_hash["floors_count"][0]
			end
			
			# This method sets new attributes to all selected zones (or maybe other objects in case if @props_list_content=="all").
			# Then it performs zones rebuilding in case if @rebuild_on_apply=="true"
			def batch_props_apply
				@model.start_operation($lsszoneStrings.GetString("Adjust Properties of the Zone(s)"), true)
					lss_zone_rebuild=LSS_Zone_Rebuild_Tool.new
					i=1; tot_cnt=@zones_arr.length
					progr_char="|"; rest_char="_"; scale_coeff=1
					progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
					js_command = "set_progress_state()"
					@props_dialog.execute_script(js_command)
					
					# Erase attributes if some attributes were erased in a dialog
					if @attrs2erase.length>0
						@selection.each{|ent|
							if ent
								@attrs2erase.each{|dict_attr_pair|
									dict_name=dict_attr_pair[0]
									attr_name=dict_attr_pair[1]
									if ent.attribute_dictionaries[dict_name]
										if ent.get_attribute(dict_name, attr_name)
											ent.delete_attribute(dict_name, attr_name)
										end
									end
								}
							end
						}
						# Now clear @all_props from erased keys
						@all_props.each_key{|dict_name|
							dict_hash=@all_props[dict_name]
							@attrs2erase.each{|dict_attr_pair|
								dict_n=dict_attr_pair[0]
								attr_n=dict_attr_pair[1]
								if dict_name==dict_n
									dict_hash.delete(attr_n)
									@all_props[dict_name]=dict_hash
								end
							}
						}
					end
					
					# Erase dictionaries if some dictionaries were erased in a dialog
					if @dicts2erase.length>0
						@selection.each{|ent|
							if ent
								@dicts2erase.each{|dict_name|
									if ent.attribute_dictionaries[dict_name]
										ent.delete_attribute(dict_name)
									end
								}
							end
						}
						# Now clear @all_props from erased dictionaries
						@dicts2erase.each{|dict_name|
							@all_props.delete(dict_name)
						}
					end
					
					if @props_list_content=="all"
						@selection.each{|ent|
							@all_props.each_key{|dict_name|
								if @dicts2erase.include?(dict_name)==false
									dict=@all_props[dict_name]
									if ent.attribute_dictionaries.nil?
										if @dict_new_names[dict_name]
											new_dict_name=@dict_new_names[dict_name] # Grab new name from a hash, since it might be changed in a dialog
											dict.each_key{|key|
												val=dict[key]
												if val
													if val.to_s!="..." and val.to_s!=""
														ent.set_attribute(new_dict_name, key, val) # Use new_dict_name in setting of an attribute
													end
												end
											}
										end
									else
										if ent.attribute_dictionaries[dict_name]
											dict.each_key{|key|
												val=dict[key]
												if val
													if val.to_s!="..." and val.to_s!=""
														ent.set_attribute(dict_name, key, val)
														puts "#{key}: #{val}"
													end
												end
											}
											# Refresh links graph if any
											if dict_name=="LSS_Zone_Graph"
												refresh_graph=LSS_Zone_Refresh_Graph.new
												refresh_graph.refresh_graph(ent)
											end
										else
											# Handle case when new dictionary was added in a dialog
											# so entity most probably does not have such attr-dict
											# and it is necessary to add it
											if @dict_new_names[dict_name] # Ensure that it is a brand new dictionary
												new_dict_name=@dict_new_names[dict_name] # Grab new name from a hash, since it might be changed in a dialog
												dict.each_key{|key|
													val=dict[key]
													if val
														if val.to_s!="..." and val.to_s!=""
															ent.set_attribute(new_dict_name, key, val) # Use new_dict_name in setting of an attribute
														end
													end
												}
												# Refresh links graph if any
												if dict_name=="LSS_Zone_Graph"
													refresh_graph=LSS_Zone_Refresh_Graph.new
													refresh_graph.refresh_graph(ent)
												end
											end
										end
									end
								end
							}
							progr_bar.update(i)
							i+=1
							Sketchup.status_text=$lsszoneStrings.GetString("Applying new properties: ") + progr_bar.progr_string
						}
					else
						@zones_arr.each{|zone_obj|
							if (zone_obj.transformation.identity?)==false
								is_selected=true if @selection.include?(zone_obj)
								if @rebuild_on_apply=="true"
									lss_zone_rebuild.recalc_floor_level=true
									lss_zone_rebuild.recalc_height=true
									zone_obj=lss_zone_rebuild.rebuild(zone_obj)
								end
								@selection.add(zone_obj) if is_selected
								number=zone_obj.get_attribute("LSS_Zone_Entity", "number")
								name=zone_obj.get_attribute("LSS_Zone_Entity", "name")
								area=zone_obj.get_attribute("LSS_Zone_Entity", "area")
								puts("#{$lsszoneStrings.GetString("Transformed zone was rebuilded")} #{number}, #{name}, #{Sketchup.format_area(area.to_f)}")
							end
							zone_obj.set_attribute("LSS_Zone_Entity", "name", @name) if @name and @name.to_s!="..."
							zone_obj.set_attribute("LSS_Zone_Entity", "number", @number) if @number and @number.to_s!="..."
							zone_obj.set_attribute("LSS_Zone_Entity", "height", @height) if @height and @height!="..."
							zone_obj.set_attribute("LSS_Zone_Entity", "floor_number", @floor_number) if @floor_number and @floor_number.to_s!="..."
							zone_obj.set_attribute("LSS_Zone_Entity", "category", @category) if @category and @category.to_s!="..."
							zone_obj.set_attribute("LSS_Zone_Entity", "floor_level", @floor_level) if @floor_level and @floor_level.to_s!="..."
							zone_obj.set_attribute("LSS_Zone_Entity", "memo", @memo) if @memo and @memo.to_s!="..."
							zone_obj.set_attribute("LSS_Zone_Entity", "floor_material", @floor_material) if @floor_material and @floor_material.to_s!="..."
							zone_obj.set_attribute("LSS_Zone_Entity", "wall_material", @wall_material) if @wall_material and @wall_material.to_s!="..."
							zone_obj.set_attribute("LSS_Zone_Entity", "ceiling_material", @ceiling_material) if @ceiling_material and @ceiling_material.to_s!="..."
							zone_obj.set_attribute("LSS_Zone_Entity", "floor_refno", @floor_refno) if @floor_refno and @floor_refno.to_s!="..."
							zone_obj.set_attribute("LSS_Zone_Entity", "wall_refno", @wall_refno) if @wall_refno and @wall_refno.to_s!="..."
							zone_obj.set_attribute("LSS_Zone_Entity", "ceiling_refno", @ceiling_refno) if @ceiling_refno and @ceiling_refno.to_s!="..."
							zone_obj.set_attribute("LSS_Zone_Entity", "floors_count", @floors_count) if @floors_count and @floors_count.to_s!="..."
							progr_bar.update(i)
							i+=1
							Sketchup.status_text=$lsszoneStrings.GetString("Applying new properties: ") + progr_bar.progr_string
						}
					end
					Sketchup.status_text=$lsszoneStrings.GetString("New properties applying complete.")
					js_command = "set_default_state()"
					@props_dialog.execute_script(js_command)
					if @rebuild_on_apply=="true"
						# Enforce entered @floor_level value processing instead of recalculating it
						# using face points z coordinate and zone group transformation.
						lss_zone_rebuild.recalc_floor_level=false
						lss_zone_rebuild.recalc_height=false
						# Set parameter to 'false' so 'process_selection' method does not perform '@model.start_operation'
						lss_zone_rebuild.process_selection(false)
					end
				@model.commit_operation
				js_command="refresh_data()"
				@props_dialog.execute_script(js_command)
			end
			
			def create_web_dial
				
				# Create the WebDialog instance
				@props_dialog = UI::WebDialog.new($lsszoneStrings.GetString("Properties"), true, "LSS Zone Properties", 350, 500, 200, 200, true)
				@props_dialog.max_width=450
				@props_dialog.min_width=280
			
				# Attach an action callback
				@props_dialog.add_action_callback("get_data") do |web_dialog,action_name|
					view=Sketchup.active_model.active_view
					if action_name=="apply_settings"
						self.hash2settings
						@selection.remove_observer(@selection_observer)
						self.batch_props_apply
						@selection.add_observer(@selection_observer)
						@dicts2erase=Array.new
						@attrs2erase=Array.new
						@dict_new_names=Hash.new
						@new_attrs=Array.new
					end
					if action_name=="get_settings" # From Ruby to web-dialog
						self.send_settings2dlg
						js_command = "switch_content_view('" + @props_list_content + "')"
						@props_dialog.execute_script(js_command) if js_command
						view.invalidate
					end
					if action_name=="get_zones_cnt"
						cnt_str=""
						@zone_types_cnt.each_key{|key|
							cnt_str+=key+"="+@zone_types_cnt[key].to_s+","
						}
						cnt_str.chomp!(",")
						js_command = "get_zones_cnt('" + cnt_str + "')"
						@props_dialog.execute_script(js_command)
					end
					if action_name=="get_materials"
						self.send_materials2dlg
					end
					if action_name=="refresh_data"
						self.refresh
					end
					if action_name=="get_categories"
						self.send_categories2dlg
					end
					if action_name.split(",")[0]=="obtain_prop" # From web-dialog
						dict_name=action_name.split(",")[1]
						key=action_name.split(",")[2]
						val=action_name.split(",")[3]
						if @settings_hash[key]
							case @settings_hash[key][1]
								when "distance"
								dist=Sketchup.parse_length(val)
								if dist.nil?
									dist=Sketchup.parse_length(val.gsub(".",","))
								end
								val=dist
								when "integer"
								val=val.to_i
							end
							# Process category setting individually
							if key=="category"
								if val
									if val!="" and val!="#"
										if val[0, 1]!="#"
											val="#"+val
										end
										cat_is_new=self.cat_is_new?(val)
										if cat_is_new
											self.add_new_category(val)
										end
									else
										val=$lsszoneStrings.GetString("#Default")
									end
								end
							end
						end
						dict_hash=@all_props[dict_name]
						dict_hash[key]=val
						@all_props[dict_name]=dict_hash
					end
					if action_name.split(",")[0]=="obtain_setting" # From web-dialog
						key=action_name.split(",")[1]
						val=action_name.split(",")[2]
						if @settings_hash[key]
							case @settings_hash[key][1]
								when "distance"
								dist=Sketchup.parse_length(val)
								if dist.nil?
									dist=Sketchup.parse_length(val.gsub(".",","))
								end
								@settings_hash[key][0]=dist
								when "integer"
								@settings_hash[key][0]=val.to_i
								else
								@settings_hash[key][0]=val
							end
							# Process category setting individually
							if key=="category"
								if val
									if val!="" and val!="#"
										if val[0, 1]!="#"
											val="#"+val
										end
										@settings_hash[key][0]=val
										cat_is_new=self.cat_is_new?(val)
										if cat_is_new
											self.add_new_category(val)
										end
									else
										@settings_hash[key][0]=$lsszoneStrings.GetString("#Default")
									end
								end
							end
							self.hash2settings
							# Process properties list representation type
							if key=="props_list_content"
								if val=="all"
									self.read_all_attributes
								else
									self.selection_filter
									self.obtain_common_settings
									self.send_settings2dlg
								end
								js_command = "switch_content_view('" + val + "')" if val
								@props_dialog.execute_script(js_command) if js_command
							end
						end
					end
					if action_name.split(",")[0]=="erase_dict"
						dict_name=action_name.split(",")[1]
						@dicts2erase<<dict_name
					end
					if action_name.split(",")[0]=="erase_attr"
						dict_name=action_name.split(",")[1]
						attr_name=action_name.split(",")[2]
						@attrs2erase<<[dict_name, attr_name]
					end
					if action_name.split(",")[0]=="add_new_dict"
						dict_name=action_name.split(",")[1]
						dict_hash=Hash.new
						@all_props[dict_name]=dict_hash # Just to initialize new dictionary
						@dict_new_names[dict_name]=dict_name
					end
					if action_name.split(",")[0]=="dict_name_change"
						dict_name=action_name.split(",")[1]
						new_dict_name=action_name.split(",")[2]
						@dict_new_names[dict_name]=new_dict_name
					end
					if action_name.split(",")[0]=="add_new_attr"
						dict_name=action_name.split(",")[1]
						prop_name=action_name.split(",")[2]
						@new_attrs<<dict_name+","+prop_name
					end
					if action_name.split(",")[0]=="change_attr_name"
						dict_name=action_name.split(",")[1]
						prop_name=action_name.split(",")[2]			# Old property name
						new_prop_name=action_name.split(",")[3]		# New property name grabbed from input field
						val=action_name.split(",")[4]				# Value of this property
						dict_hash=@all_props[dict_name]
						dict_hash.delete(prop_name) 				# Erase key with previous attribute name
						dict_hash[new_prop_name]=val				# Add key with new attribute name
						@all_props[dict_name]=dict_hash				# Store updated dictionary in dictionaries hash
					end
					if action_name=="reset"
						@props_dialog.close
						lss_zone_props=LSS_Zone_Props.new
						lss_zone_props.activate
					end
				end
				resource_dir=LSS_Dirs.new.resource_path
				dial_path="#{resource_dir}/lss_zone/lss_zone_props.html"
				@props_dialog.set_file(dial_path)
				lss_zone_app_observer=LSS_Zone_App_Observer.new(@props_dialog)
				Sketchup.add_observer(lss_zone_app_observer)
				@selection_observer=LSS_Zone_Selection_Observer.new(@props_dialog)
				@selection.add_observer(@selection_observer)
				@props_dialog.show()
				@props_dialog.set_on_close{
					Sketchup.active_model.select_tool(nil)
					@selection.remove_observer(@selection_observer)
					$props_dial_is_active=false
					Sketchup.remove_observer(lss_zone_app_observer)
					self.write_defaults
				}
			end
			
			# This method works when @props_list_content=="all"
			def read_all_attributes
				# Clear properties
				js_command = "clear_dicts()"
				@props_dialog.execute_script(js_command) if js_command
				# Making a complete list of dictionaries
				attr_dicts_arr=Array.new
				@selection.each{|ent|
					if ent.respond_to?("attribute_dictionaries")
						dicts=ent.attribute_dictionaries
						if dicts
							dicts.each{|dict|
								if attr_dicts_arr.include?(dict.name)==false
									attr_dicts_arr<<dict.name
								end
							}
						end
					end
				}

				attr_dicts_arr.sort { |x,y| x <=> y }
				@all_props=Hash.new
				attr_dicts_arr.each{|dict_name|
					props_hash=Hash.new
					js_command = "add_dict('" + dict_name + "')" if dict_name
					@props_dialog.execute_script(js_command) if js_command
					@selection.each{|ent|
						if ent.respond_to?("attribute_dictionaries")
							dicts=ent.attribute_dictionaries
							if dicts
								dict=dicts[dict_name]
								if dict
									dict.each_key{|key|
										if props_hash[key].nil?
											props_hash[key]=dict[key]
										else
											if props_hash[key].to_s!="..."
												if props_hash[key].to_s!=dict[key].to_s
													props_hash[key]="..."
												end
											end
										end
									}
								end
							end
						end
					}
					if props_hash.length>0
						props_arr=Array.new
						props_hash.each_key{|key|
							props_arr<<[key, props_hash[key]]
						}
						props_arr.sort! { |x,y| x[0] <=> y[0] }
						props_arr.each{|key_val|
							key=key_val[0]
							val=key_val[1]
							value=props_hash[key]
							value_type=Sketchup.read_default("LSS Zone Data Types", key)
							case value_type
								when "distance"
									if value.to_s!="..."
										dist_str=Sketchup.format_length(value.to_f).to_s
										value=dist_str.gsub("'", "*") # Patch to solve js errors problem with feet and inches
									end
								when "area"
									if value.to_s!="..."
										area_str=Sketchup.format_area(value.to_f).to_s
										value=area_str
									end
								when "volume"
									if value.to_s!="..."
										vol_str=LSS_Math.new.format_volume(value)
										value=vol_str
									end
								else
									
							end
							if key=="label_template"
								value=value.gsub(/\n/, "\\n")
							end
							setting_pair_str= key.to_s + "|" + value.to_s
							key_val_str=dict_name+"|"+setting_pair_str
							js_command = "add_prop('" + key_val_str + "')"
							@props_dialog.execute_script(js_command) if js_command
						}
						@all_props[dict_name]=props_hash
					end
				}
				js_command = "list_all_props()"
				@props_dialog.execute_script(js_command) if js_command
			end
			
			def read_defaults
				@props_list_content=Sketchup.read_default("LSS_Zone", "props_list_content", "zone_only") # Alternative representation is 'all'
				@rebuild_on_apply=Sketchup.read_default("LSS_Zone", "rebuild_on_apply", "true")
			end
			
			def write_defaults
				Sketchup.write_default("LSS_Zone", "props_list_content", @props_list_content)
				Sketchup.write_default("LSS_Zone", "rebuild_on_apply", @rebuild_on_apply)
			end
			
			def send_settings2dlg
				self.settings2hash
				@settings_hash.each_key{|key|
					value=@settings_hash[key][0]
					value_type=Sketchup.read_default("LSS Zone Data Types", key)
					case value_type
						when "distance"
							if value.to_s!="..."
								dist_str=Sketchup.format_length(value.to_f).to_s
								value=dist_str.gsub("'", "*") # Patch to solve js errors problem with feet and inches
							end
						when "area"
							if value.to_s!="..."
								area_str=Sketchup.format_area(value.to_f).to_s
								value=area_str
							end
						when "volume"
							if value.to_s!="..."
								vol_str=LSS_Math.new.format_volume(value)
								value=vol_str
							end
						else
							
					end
					setting_pair_str= key.to_s + "|" + value.to_s
					js_command = "get_setting('" + setting_pair_str + "')" if setting_pair_str
					@props_dialog.execute_script(js_command) if js_command
				}
			end
			
			def send_materials2dlg
				# Send list of materials from an active model to a web-dialog
				js_command = "clear_mats_arr()"
				@props_dialog.execute_script(js_command) if js_command
				@materials=@model.materials
				@materials.each{|mat|
					col_obj=mat.color
					col_arr=[col_obj.red, col_obj.green, col_obj.blue]
					col=col_arr.join(",")
					mat_str= mat.name + "|" + col
					js_command = "get_material('" + mat_str + "')"
					@props_dialog.execute_script(js_command) if js_command
				}
				js_command = "build_mat_list()"
				@props_dialog.execute_script(js_command) if js_command
			end
			
			def send_categories2dlg
				# Send list of categories from an active model to a web-dialog
				js_command = "clear_cats_arr()"
				@props_dialog.execute_script(js_command) if js_command
				categories=@model.attribute_dictionary("LSS Zone Categories")
				if categories
					categories.each_key{|cat|
						js_command = "get_category('" + cat + "')"
						@props_dialog.execute_script(js_command) if js_command
					}
					js_command = "bind_categories()"
					@props_dialog.execute_script(js_command) if js_command
				else
					if @category
						js_command = "get_category('" + @category + "')"
						@props_dialog.execute_script(js_command) if js_command
						js_command = "bind_categories()"
						@props_dialog.execute_script(js_command) if js_command
					else
						@category="#Default"
						js_command = "get_category('" + @category + "')"
						@props_dialog.execute_script(js_command) if js_command
						js_command = "bind_categories()"
						@props_dialog.execute_script(js_command) if js_command
					end
				end
			end
			
			def cat_is_new?(chk_cat)
				cat_is_new=true
				categories=@model.attribute_dictionary("LSS Zone Categories")
				if categories
					categories.each_key{|cat|
						if cat==chk_cat
							cat_is_new=false
							break
						end
					}
				end
				cat_is_new
			end
			
			def add_new_category(new_category_name)
				return if new_category_name.nil?
				return if new_category_name==""
				@category=new_category_name
				@materials=@model.materials
				if @materials[@category]
					category_material=@materials[@category]
					@model.set_attribute("LSS Zone Categories", @category, true)
				else
					category_material=@materials.add(@category)
					last_hue=@model.get_attribute("LSS_Zone", "last_category_hue", 0)
					new_hue=last_hue+101
					new_hue=new_hue-360 if new_hue>=360
					col=LSS_Color.new.hsv2rgb(new_hue, 0.8, 1.0)
					category_material.color=col
					category_material.alpha=0.2
					@model.set_attribute("LSS_Zone", "last_category_hue", new_hue)
					@model.set_attribute("LSS Zone Categories", @category, true)
				end
				self.settings2hash
				js_command = "clear_cats_arr()"
				@props_dialog.execute_script(js_command) if js_command
				categories=@model.attribute_dictionary("LSS Zone Categories")
				if categories
					categories.each_key{|cat|
						js_command = "get_category('" + cat + "')"
						@props_dialog.execute_script(js_command) if js_command
					}
					js_command = "re_bind_categories()"
					@props_dialog.execute_script(js_command) if js_command
				end
			end
			
		end #class LSS_Zone_Props_Tool

		if( not file_loaded?("lss_zone_props.rb") )
			LSS_Zone_Props_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_props.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	