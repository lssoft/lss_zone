# lss_zone_list.rb ver. 1.2.1 beta 30-Dec-13
# The file, which contains report generator implementation.
# It generates selected zones list for further saving
# it to an HTML file.

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		
		require 'lss_zone/lss_zone_list_template.rb'
		
		# This class adds 'List Zones' command to LSS Zone menu and toolbar.
		
		class LSS_Zone_List_Cmd
			def initialize
				lss_list_dial=LSS_Zone_List.new
				lss_zone_list_cmd=UI::Command.new($lsszoneStrings.GetString("List Zones")){
					lss_list_dial.list_dial
				}
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=13
					lss_zone_list_cmd.small_icon = "./tb_icons/list_24.png"
					lss_zone_list_cmd.large_icon = "./tb_icons/list_32.png"
				else
					lss_zone_list_cmd.small_icon = "./tb_icons/list_16.png"
					lss_zone_list_cmd.large_icon = "./tb_icons/list_24.png"
				end
				lss_zone_list_cmd.tooltip = $lsszoneStrings.GetString("Select zones, then click to generate a list of selected zones.")
				$lsszoneToolbar.add_item(lss_zone_list_cmd)
				$lsszoneMenu.add_item(lss_zone_list_cmd)
			end
		end #class LSS_Zone_List_Cmd
		
		# This class contains implementation of a dialog for building lists of selected zones.
		
		class LSS_Zone_List
			# Hash of settings, which are transfered between class and web-dialog.
			attr_accessor :settings_hash
			# Array of selected zone objects.
			attr_accessor :selected_zones
			# Array of zone attribute names aliases (for example 'floor_level' attribute name may have 'Floor Level' alias).
			# Report generator uses name aliases for report column headers.
			# In case of blank alias report generator uses attribute name as a column header.
			attr_accessor :name_aliases
			# Array of charts attached to selected zone list template.
			attr_accessor :charts_arr
			# Array of nested elements names
			attr_accessor :nested_elements_names
			
			# Initialize
			# - @query_string - string, which contains attribute names mentions prefixed by "@" sign
			# - @sort_by - attribute name, which has to be used for sorting of generated list of zones
			# - @sort_dir - sort direction (ascending/descending)
			# - @group_by - attribute name, which has to be used for grouping of generated list
			# - @list_name - list template name
			
			def initialize
				@model=Sketchup.active_model
				@selected_zones=nil
				@query_string=""
				@sort_by=""
				@sort_dir="ascending" #descending
				@group_by=""
				@list_name=""
				
				@settings_hash=Hash.new
				@name_aliases=Hash.new
				@charts_arr=Array.new
				# Child dialog uses this array for auto-suggest widget
				@nested_elements_names=Array.new
				
				# Stick dialog height setting. Added in ver. 1.2.1 13-Dec-13.
				@stick_height="true"
				
				# Dialog duplication prevention. Added in ver. 1.2.1 13-Dec-13.
				$lss_list_dial_is_active=false
			end
			
			# This method collects only zone objects from current selection set and
			# puts collected zone groups to @selected_zones array for further processing.
			
			def filter_selection
				@selected_zones=Array.new
				if @selection.length==0
					UI.messagebox($lsszoneStrings.GetString("It is necessary to select some zone objects before launching 'List' command."))
				else
					selected_groups=@selection.select{|ent| ent.is_a?(Sketchup::Group)}
					@selected_zones=selected_groups.select{|grp| not(grp.get_attribute("LSS_Zone_Entity", "number").nil?)}
				end
			end
			
			# This method is the first one to be called.
			# It filters selection, then collects data from selected zones, then creates 'List Zones' dialog
			
			def list_dial
				@selection=@model.selection
				self.filter_selection
				return if @selected_zones.length==0
				i=1
				tot_cnt=@selected_zones.length
				progr_char="|"; rest_char="_"; scale_coeff=1
				progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
				@collected_data=Array.new
				@selected_zones.each{|zone_entity|
					attr_hash=Hash.new
					attr_dict=zone_entity.attribute_dictionary("LSS_Zone_Entity")
					attr_dict.each_key{|key|
						attr_hash[key]=attr_dict[key]
					}
					# Read information about nested elements. Added in ver. 1.1.2 10-Nov-13.
					zone_entity.entities.each{|elt|
						elt_type=elt.get_attribute("LSS_Zone_Element","type")
						if elt_type=="wall" or elt_type=="floor" or elt_type=="ceiling"
							elt_faces_arr=elt.entities.to_a.select{|ent| ent.is_a?(Sketchup::Face)}
							elt_faces_arr.each{|elt_face|
								if elt_face.material
									material=elt_face.material.name.to_s
								else
									material=""
								end
								area=elt_face.area
								key=elt_type+"_elements"
								@nested_elements_names<<key if @nested_elements_names.include?(key)==false
								if attr_hash[key].nil?
									val=Hash.new
									val[material]=area
									attr_hash[key]=val
								else
									val=attr_hash[key]
									old_area=val[material]
									if old_area
										new_area=old_area+area
										val[material]=new_area
									else
										val[material]=area
									end
									attr_hash[key]=val
								end
							}
						else
							if elt_type
								if elt_type.include?("opening")
									op_faces_arr=elt.entities.to_a.select{|ent| ent.is_a?(Sketchup::Face)}
									op_face=op_faces_arr[0]
									area=op_face.area
									key="openings"
									@nested_elements_names<<key if @nested_elements_names.include?(key)==false
									if attr_hash[key].nil?
										val=Array.new
										op_name=elt_type
										val<<[op_name, area]
									else
										val=attr_hash[key]
										op_name=elt_type
										val<<[op_name, area]
									end
									attr_hash[key]=val
								end
							else
								elt_name=nil
								elt_name=elt.name if elt.respond_to?("name")
								if elt_name.nil? or elt_name==""
									if elt.respond_to?("definition")
										elt_definition=elt.definition
										elt_name=elt_definition.name
									end
								end
								
								# Ignore component instance, which represents zone's internal point.
								# Added in ver. 1.2.0 (28-Nov-13).
								elt_name=nil if elt_name=="lss_zone_int_pt"
								
								if elt_name
									key="nested_elements"
									@nested_elements_names<<key if @nested_elements_names.include?(key)==false
									if attr_hash[key].nil?
										val=Hash.new
										val[elt_name]=1
										attr_hash[key]=val
									else
										val=attr_hash[key]
										old_cnt=val[elt_name]
										if old_cnt
											new_cnt=old_cnt+1
											val[elt_name]=new_cnt
										else
											val[elt_name]=1
										end
										attr_hash[key]=val
									end
								end
							end
						end
					}
					@collected_data<<attr_hash
					progr_bar.update(i)
					i+=1
					Sketchup.status_text=$lsszoneStrings.GetString("Collecting data: ") + progr_bar.progr_string
				}
				self.create_list_dial
				Sketchup.status_text=$lsszoneStrings.GetString("Data collection complete.")
				
			end
			
			# This method iterates through @collected_data array and generates @query_result array
			# according to @query_string content and @sort_by, @group_by settings.
			
			def run_query
				if @query_string.nil? or @query_string==""
					@query_result=Array.new
					@sort_by=""
					@group_by=""
					self.settings2hash
					return
				end
				
				# Select fields
				i=1
				tot_cnt=@collected_data.length
				progr_char="|"; rest_char="_"; scale_coeff=1
				progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
				js_command = "set_progress_state()"
				@zone_list_dial.execute_script(js_command) if js_command
				count_fields=0
				selected_fields=Array.new
				@collected_data.each{|record|
					new_record=Hash.new
					record.each_key{|key|
						if key!=""
							if @query_string.include?(key)
								new_record[key]=record[key]
								count_fields+=1
							end
						end
					}
					selected_fields<<new_record
					progr_bar.update(i)
					i+=1
					Sketchup.status_text=$lsszoneStrings.GetString("Selecting fields: ") + progr_bar.progr_string
				}
				Sketchup.status_text=$lsszoneStrings.GetString("Selection complete.")
				js_command = "set_default_state()"
				@zone_list_dial.execute_script(js_command) if js_command
				if count_fields==0
					@query_result=Array.new
					@sort_by=""
					@group_by=""
					self.settings2hash
					return
				end
				
				# Sort
				if @sort_by.nil?
					@sort_by=""
				end
				if @sort_by!=""
					if @sort_dir=="ascending"
						begin
							sorted_result=selected_fields.sort { |x,y| x[@sort_by] <=> y[@sort_by] }
						rescue
							sorted_result=Array.new(selected_fields)
						end
					else
						begin
							sorted_result=selected_fields.sort { |x,y| y[@sort_by] <=> x[@sort_by] }
						rescue
							sorted_result=Array.new(selected_fields)
						end
					end
				else
					sorted_result=Array.new(selected_fields)
				end
				
				# Group
				if @group_by.nil?
					@group_by=""
				end
				if @group_by!=""
					grp_by_values=Array.new
					sorted_result.each{|record|
						grp_by_values<<record[@group_by]
					}
					grp_by_values.uniq!
					@query_result=Array.new
					i=1
					tot_cnt=grp_by_values.length
					progr_char="|"; rest_char="_"; scale_coeff=1
					progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
					js_command = "set_progress_state()"
					grp_by_values.each{|grp_val|
						grp_arr=sorted_result.select{|record| record[@group_by]==grp_val}
						new_record=Hash.new
						grp_arr.each{|grp_rec|
							grp_rec.each_key{|key|
								if key==@group_by
									new_record[key]=grp_rec[key]
								else
									if new_record[key].nil?
										new_record[key]=grp_rec[key]
										# Added in ver. 1.0.2 beta 15-Oct-13.
										if key=="floor_level"
											value=grp_rec[key]
											dist_str=Sketchup.format_length(value.to_f).to_s
											value=dist_str
											new_record[key]=value
										end
									else
										# Handling of different grouping cases. Added in ver. 1.0.1 beta 08-Oct-13
										value_type=Sketchup.read_default("LSS Zone Data Types", key)
										case value_type
											when "distance"
												if key!="floor_level"
													new_record[key]=new_record[key].to_f+grp_rec[key].to_f
												else
													value=grp_rec[key]
													dist_str=Sketchup.format_length(value.to_f).to_s
													value=dist_str
													new_record[key]+="; " + value if (new_record[key].include?(value))==false
												end
											when "area"
												new_record[key]+=grp_rec[key]
											when "volume"
												new_record[key]+=grp_rec[key]
											when "string"
												new_record[key]+="; " + grp_rec[key].to_s if (new_record[key].include?(grp_rec[key].to_s))==false
											when "boolean"
												new_record[key]="..."
											else
												new_record[key]+=grp_rec[key]
										end
									end
								end
							}
						}
						@query_result<<new_record
						progr_bar.update(i)
						i+=1
						Sketchup.status_text=$lsszoneStrings.GetString("Grouping: ") + progr_bar.progr_string
					}
					Sketchup.status_text=$lsszoneStrings.GetString("Grouping complete.")
					js_command = "set_default_state()"
					@zone_list_dial.execute_script(js_command) if js_command
				else
					@query_result=Array.new(sorted_result)
				end
				
				# Format Data
				i=1
				tot_cnt=@query_result.length
				progr_char="|"; rest_char="_"; scale_coeff=1
				progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
				js_command = "set_progress_state()"
				@zone_list_dial.execute_script(js_command) if js_command
				@query_result.each{|record|
					record.each_key{|key|
						value=record[key]
						value_type=Sketchup.read_default("LSS Zone Data Types", key)
						case value_type
							when "distance"
								dist_str=Sketchup.format_length(value.to_f).to_s
								value=dist_str
								# Unformat back "floor_level". Added 15-Oct-13.
								if key=="floor_level"
									if @group_by!=""
										value=record[key]
									end
								end
							when "area"
								area_str=Sketchup.format_area(value.to_f).to_s
								# Supress square units patch added in ver. 1.1.1 06-Nov-13.
								options=Sketchup.active_model.options
								units_options=options["UnitsOptions"]
								supress_units=units_options["SuppressUnitsDisplay"]
								if supress_units
									if area_str.split(" ")[0]!="~"
										area_str=area_str.split(" ")[0]
									else
										area_str=area_str.split(" ")[1]
									end
								end
								value=area_str
							when "volume"
								vol_str=LSS_Math.new.format_volume(value)
								value=vol_str
							else
								if value.is_a?(Hash) or value.is_a?(Array)
									val_str=""
									if key.include?("wall") or key.include?("floor") or key.include?("ceiling")
										value.each_key{|nested_elt_key|
											elt_area=value[nested_elt_key]
											area_str=Sketchup.format_area(elt_area).to_s
											# Supress square units patch
											options=Sketchup.active_model.options
											units_options=options["UnitsOptions"]
											supress_units=units_options["SuppressUnitsDisplay"]
											if supress_units
												if area_str.split(" ")[0]!="~"
													area_str=area_str.split(" ")[0]
												else
													area_str=area_str.split(" ")[1]
												end
											end
											val_str+=nested_elt_key+": "+area_str+"\n"
										}
									else
										if key.include?("opening")
											value.each{|op_arr|
												elt_area=op_arr[1]
												area_str=Sketchup.format_area(elt_area).to_s
												# Supress square units patch
												options=Sketchup.active_model.options
												units_options=options["UnitsOptions"]
												supress_units=units_options["SuppressUnitsDisplay"]
												if supress_units
													if area_str.split(" ")[0]!="~"
														area_str=area_str.split(" ")[0]
													else
														area_str=area_str.split(" ")[1]
													end
												end
												val_str+=op_arr[0]+": "+area_str+"\n"
											}
										else
											value.each_key{|nested_elt_key|
												elt_cnt=value[nested_elt_key].to_s
												val_str+=nested_elt_key+": "+elt_cnt+"\n"
											}
										end
									end
									value=val_str
								end
						end
						record[key]=value
					}
					progr_bar.update(i)
					i+=1
					Sketchup.status_text=$lsszoneStrings.GetString("Formatting data: ") + progr_bar.progr_string
				}
				Sketchup.status_text=$lsszoneStrings.GetString("Formatting complete.")
				js_command = "set_default_state()"
				@zone_list_dial.execute_script(js_command) if js_command
			end
			
			# This method creates 'List Zones' dialog.
			
			def create_list_dial
				# Dialog duplication prevention. Added in ver. 1.2.1 13-Dec-13.
				return if $lss_list_dial_is_active
				$lss_list_dial_is_active=true
				
				self.read_defaults
			
				# Create the WebDialog instance
				@zone_list_dial = UI::WebDialog.new($lsszoneStrings.GetString("List Zones"), true, "LSS List Zones", 450, 500, 200, 200, true)
				@zone_list_dial.min_width=390
				
				# Attach an action callback
				@zone_list_dial.add_action_callback("get_data") do |web_dialog,action_name|
					view=Sketchup.active_model.active_view
					if action_name=="get_settings" # From Ruby to web-dialog
						self.send_settings2dlg
						view.invalidate
					end
					if action_name=="apply_settings"
						self.generate_list
					end
					if action_name=="get_presets"
						self.send_presets2dlg
					end
					if action_name=="get_fields"
						self.send_fields2dlg(@zone_list_dial)
					end
					if action_name=="get_name_aliases"
						self.send_name_aliases2dlg(@zone_list_dial)
					end
					if action_name=="get_charts"
						self.send_charts2dlg(@zone_list_dial)
					end
					if action_name=="get_zones_data"
						self.send_zones_data2dlg(@zone_list_dial)
					end
					if action_name.split(",")[0]=="select_preset"
						@list_name=action_name.split(",")[1]
						self.settings2hash
						self.read_template_from_file
					end
					if action_name.split(",")[0]=="edit_preset"
						@list_name=action_name.split(",")[1]
						self.edit_preset
					end
					if action_name.split(",")[0]=="delete_preset"
						@list_name=action_name.split(",")[1]
						self.delete_preset
					end
					if action_name=="add_preset"
						self.add_preset
					end
					if action_name=="cancel"
						@zone_list_dial.close
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
						end
						# Handle stick height setting change
						if key=="stick_height"
							LSS_Zone_Utils.new.adjust_dial_size(@zone_list_dial, @cont_height, @cont_width, @d_width, @d_height, @dial_y, @scr_height) if val=="true"
						end
						self.hash2settings
					end
					# Content size block start
					if action_name.split(",")[0]=="content_size"
						@cont_width=action_name.split(",")[1].to_i
						@cont_height=action_name.split(",")[2].to_i
					end
					if action_name.split(",")[0]=="visible_size"
						@visible_width=action_name.split(",")[1].to_i
						@visible_height=action_name.split(",")[2].to_i
					end
					if action_name.split(",")[0]=="dial_xy"
						@dial_x=action_name.split(",")[1].to_i
						@dial_y=action_name.split(",")[2].to_i
					end
					if action_name.split(",")[0]=="screen_size"
						@scr_width=action_name.split(",")[1].to_i
						@scr_height=action_name.split(",")[2].to_i
					end
					if action_name.split(",")[0]=="hdr_ftr_height"
						@hdr_ftr_height=action_name.split(",")[1].to_i
					end
					if action_name=="init_dial_d_size"
						js_command="send_visible_size()"
						@zone_list_dial.execute_script(js_command) if js_command
						@init_width=@visible_width
						@init_height=@visible_height
						@zone_list_dial.set_size(@init_width, @init_height)
						js_command="send_visible_size()"
						@zone_list_dial.execute_script(js_command) if js_command
						@d_height=@init_height-@visible_height + @hdr_ftr_height
						@d_width=@init_width-@visible_width
						win_width=@init_width+@d_width
						win_height=@init_height+@d_height
						@zone_list_dial.set_size(win_width, win_height)
					end
					if action_name=="adjust_dial_size"
						if @stick_height=="true"
							LSS_Zone_Utils.new.adjust_dial_size(@zone_list_dial, @cont_height, @cont_width, @d_width, @d_height, @dial_y, @scr_height)
						end
					end
					# Content size block end
					
					# Dialog style handling. Added in ver. 1.2.1 26-Dec-13.
					if action_name=="get_dial_style"
						dial_style=Sketchup.read_default("LSS Zone Defaults", "dial_style", "standard")
						js_command="get_dial_style('" + dial_style + "')"
						@zone_list_dial.execute_script(js_command) if js_command
					end
				end
				resource_dir=LSS_Dirs.new.resource_path
				dial_path="#{resource_dir}/lss_zone/lss_zone_list.html"
				@zone_list_dial.set_file(dial_path)
				@zone_list_dial.show()
				@zone_list_dial.set_on_close{
					$lss_list_dial_is_active=false
					self.write_defaults
				}
			end
			
			# This method reads list template from a file located at "#{resource_dir}/list_presets/" with a name equal to @preset_file_name
			# Method parses file content and puts obtained information to:
			# - @settings_hash
			# - @name_aliases hash
			# - @charts_arr array
			# Method recognises object inside file content when it preceeded by <"object name"> 'tag-line'. Closing 'tag-line' in a
			# file tells that object section is finished.
			# There are two types of objects for now:
			# - chart
			# - name alias
			# Method interprets other lines inside a list template file as settings.
			# Setting line format is 'setting name'='setting value'
			# Method fills out @settings_hash using 'setting name' as a key and 'setting value' as a value after processing setting line
			# of list template file.
			
			def read_template_from_file
				return if @list_name.nil? or @list_name==""
				@preset_file_name=@list_names[@list_name]
				if @preset_file_name.nil?
					@preset_file_name=@list_names[@list_names.keys.first]
				end
				resource_dir=LSS_Dirs.new.resource_path
				presets_dir="#{resource_dir}/list_presets/"
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=14
					preset_file=File.open((presets_dir+@preset_file_name).force_encoding("UTF-8"), "r")
				else
					preset_file=File.open((presets_dir+@preset_file_name), "r")
				end
				obj_block=false
				@name_aliases=Hash.new
				@charts_arr=Array.new
				while (line = preset_file.gets)
					if line.include?("<") and line.include?("</")==false
						obj_block=true
						obj_name=line.gsub(/[<>\n]/, "")
						case obj_name
							when "chart"
							chart_hash=Hash.new
						end
					end
					if line.include?("</")
						obj_block=false
						case obj_name
							when "chart"
							@charts_arr<<chart_hash
						end
					end
					if obj_block and line.include?("<")==false
						key_val=line.split("=")
						key_val[1]=key_val[1].gsub("\n", "") if key_val[1]
						case obj_name
							when "name_aliases"
								@name_aliases[key_val[0]]=key_val[1]
							when "chart"
								chart_hash[key_val[0]]=key_val[1]
						end
					end
					if obj_block==false and line.include?("</")==false
						key_val=line.split("=")
						key_val[1]=key_val[1].gsub("\n", "") if key_val[1]
						@settings_hash[key_val[0]]=[key_val[1], "string"] if key_val[1]
					end
				end
				preset_file.close
				self.hash2settings
			end
			
			# This method deletes preset with name equals to @list_name.
			# List name is stored inside a file in a line, which starts with "list_name=".
			# Method iterates through all files stored in "#{resource_dir}/list_presets/"
			# and searches for a file which has the same contents after "list_name=" as @list_name value does,
			# then deletes such file in case of its presense.
			# This method is called after clicking 'delete preset' button of 'List Zones' dialog.
			
			def delete_preset
				resource_dir=LSS_Dirs.new.resource_path
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=14
					presets_dir=("#{resource_dir}/list_presets/").force_encoding("UTF-8")
				else
					presets_dir="#{resource_dir}/list_presets/"
				end
				file2del_name=nil
				Dir.foreach(presets_dir){|preset_file_name|
					if preset_file_name!="." and preset_file_name!=".."
						begin
							if su_ver.split(".")[0].to_i>=14
								preset_file=File.open((presets_dir+preset_file_name).force_encoding("UTF-8"), "r")
							else
								preset_file=File.open((presets_dir+preset_file_name), "r")
							end
							while (line = preset_file.gets)
								key_val=line.split("=")
								if key_val[1]
									key_val[1]=key_val[1].gsub("\n", "")
									if key_val[0]=="list_name"
										if key_val[1].include?(@list_name)
											file2del_name=preset_file_name
											break
										end
									end
								end
							end
							preset_file.close
						rescue
							puts preset_file_name.inspect
						end
						break if file2del_name
					end
				}
				if su_ver.split(".")[0].to_i>=14
					File.delete((presets_dir+file2del_name).force_encoding("UTF-8")) if file2del_name
				else
					File.delete(presets_dir+file2del_name) if file2del_name
				end
				@list_name=""
				@preset_file_name=""
				self.refresh
			end
			
			# Create instance of LSS_Zone_List_Template, which has implementation of 'List Template' dialog.
			# This method is called after clicking 'edit' button of 'List Zones' dialog.
			
			def edit_preset
				template_inst=LSS_Zone_List_Template.new
				self.read_template_from_file
				template_inst.settings_hash=@settings_hash
				template_inst.parent=self
				template_inst.create_web_dial
			end
			
			# This method adds new list preset. First of all it iterates through files in "#{resource_dir}/list_presets/" directory
			# in order to find out the minimum file number, which is not yet in use, then creates new file with 'lst'
			# extension and 'list_<file number>' file name.
			# Initial preset name is also automatically generated ("New List Template <file number>") and method
			# puts this name to a newly created file after "list_name=".
			# Immideately after creation of a new list template file this method calls #edit_preset method, so
			# it is possible to assign a meaningful name to a new template and adjust query string and other list settings.
			
			def add_preset
				@query_string=""
				@sort_by=""
				@sort_dir="ascending" #descending
				@group_by=""
				@list_name=""
				self.settings2hash
				
				resource_dir=LSS_Dirs.new.resource_path
				presets_dir="#{resource_dir}/list_presets/"
				file_exist=true
				file_no=0
				su_ver=Sketchup.version
				while file_exist
					file_no_str=file_no.to_s
					file_no_str="0"+file_no_str if file_no_str.length<2
					file_no_str="0"+file_no_str if file_no_str.length<3
					new_file_name="list_"+file_no_str+".lst"
					@preset_file_name=new_file_name
					full_name=presets_dir+new_file_name
					if su_ver.split(".")[0].to_i>=14
						full_name=full_name.force_encoding("UTF-8")
					end
					file_exist=File.exist?(full_name)
					if file_exist==false
						new_preset=File.new(full_name, "w")
						const_part=$lsszoneStrings.GetString("New List Template")
						@list_name="#{const_part} #{file_no_str}"
						new_preset.puts("list_name="+@list_name)
						new_preset.close
						@preset_file_name=new_file_name
					end
					file_no+=1
				end
				self.refresh
				self.edit_preset
			end
			
			# This method iterates through all files stored in "#{resource_dir}/list_presets/" directory and
			# reads preset name from each file and put it into @list_names hash.
			# Then it iterates through @list_names hash and send each obtained name to a web-dialog.
			# All names get to an array of preset names which is a sorce of values for preset name selector
			# (drop-down list of names) of web-dialog.
			
			def send_presets2dlg
				@list_names=Hash.new
				resource_dir=LSS_Dirs.new.resource_path
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=14
					presets_dir=("#{resource_dir}/list_presets/").force_encoding("UTF-8")
				else
					presets_dir="#{resource_dir}/list_presets/"
				end
				Dir.foreach(presets_dir){|preset_file_name|
					if preset_file_name!="." and preset_file_name!=".."
						begin
							if su_ver.split(".")[0].to_i>=14
								preset_file=File.open((presets_dir+preset_file_name).force_encoding("UTF-8"), "r")
							else
								preset_file=File.open((presets_dir+preset_file_name), "r")
							end
							while (line = preset_file.gets)
								key_val=line.split("=")
								key_val[1]=key_val[1].gsub("\n", "")
								if key_val[0]=="list_name"
									@list_names[key_val[1]]=preset_file_name
									if @list_name=="" or @list_name.nil?
										@list_name=key_val[1]
									end
									break
								end
							end
							preset_file.close
						rescue
							puts preset_file_name.inspect
						end
					end
				}
				if @list_names.length>0
					js_command = "clear_presets()"
					@zone_list_dial.execute_script(js_command) if js_command
					@list_names.each_key{|list_name|
						js_command = "get_preset('" + list_name + "')" if list_name
						@zone_list_dial.execute_script(js_command) if js_command
					}
				end
				self.read_template_from_file
			end
			
			# This method sends field names, which were found in a @query_string to a web-dialog, which was passed as an argument.
			# 'List Template' dialog uses an array of attribute names as a sorce of values for selectors:
			# - sort by drop-down list
			# - group by drop-down list
			
			def send_fields2dlg(dial)
				if @query_string.nil? or @query_string==""
					self.read_template_from_file
				end
				field_names=@query_string.gsub("@", "").split(" ")
				js_command="clear_fields()"
				dial.execute_script(js_command)
				field_names.each{|field_name|
					js_command = "get_field_name('" + field_name + "')"
					dial.execute_script(js_command)
				}
			end
			
			# This method runs query to generate @query_result, then iterates through @query_result
			# and sends data record-by-record to a given dialog.
			
			def send_zones_data2dlg(dial)
				if @query_string.nil? or @query_string==""
					js_command="clear_records()"
					dial.execute_script(js_command)
					return
				end
				field_names=@query_string.gsub("@", "").split(" ")
				self.run_query
				js_command="clear_records()"
				dial.execute_script(js_command)
				i=1
				tot_cnt=@query_result.length
				progr_char="|"; rest_char="_"; scale_coeff=1
				progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
				js_command = "set_progress_state()"
				dial.execute_script(js_command) if js_command
				@query_result.each{|record|
					js_command = "clear_key_val()"
					dial.execute_script(js_command) if js_command
					field_names.each{|field_name|
						escaped_val=record[field_name].to_s.gsub(/\n/, "\\n")
						js_command = "get_key_val('" + "#{field_name}|#{escaped_val}" + "')" if escaped_val
						dial.execute_script(js_command) if js_command
					}
					js_command = "add_record()"
					dial.execute_script(js_command) if js_command
					progr_bar.update(i)
					i+=1
					Sketchup.status_text=$lsszoneStrings.GetString("Sending data: ") + progr_bar.progr_string
				}
				Sketchup.status_text=$lsszoneStrings.GetString("Data sent.")
				js_command = "set_default_state()"
				dial.execute_script(js_command) if js_command
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method performs batch sending of settings to a web-dialog by iterating through a @settings_hash.
			
			def send_settings2dlg
				self.settings2hash
				@settings_hash.each_key{|key|
					if @settings_hash[key][1]=="distance"
						dist_str=Sketchup.format_length(@settings_hash[key][0].to_f).to_s
						setting_pair_str= key.to_s + "|" + dist_str.gsub("'", "*") # Patch to solve js errors problem with feet and inches
					else
						setting_pair_str= key.to_s + "|" + @settings_hash[key][0].to_s
					end
					js_command = "get_setting('" + setting_pair_str + "')" if setting_pair_str
					@zone_list_dial.execute_script(js_command) if js_command
				}
			end
			
			# This method iterates through @name_aliases hash and sends attribute name aliases to a given dialog.
			
			def send_name_aliases2dlg(dial)
				js_command="clear_name_aliases()"
				dial.execute_script(js_command) if js_command
				@name_aliases.each_key{|key|
					name_alias_str= key.to_s + "|" + @name_aliases[key]
					js_command = "get_name_alias('" + name_alias_str + "')" if name_alias_str
					dial.execute_script(js_command) if js_command
				}
			end
			
			# This method sends information about charts from @charts_arr array to a given web-dialog.
			
			def send_charts2dlg(dial)
				js_command="clear_charts()"
				dial.execute_script(js_command) if js_command
				@charts_arr.each{|chart_hash|
					chart_name=chart_hash["chart_name"]
					data_field=chart_hash["data_field"]
					legend_field=chart_hash["legend_field"]
					chart_str= chart_name + "," + data_field + "," + legend_field
					js_command = "get_chart('" + chart_str + "')"
					dial.execute_script(js_command)
				}
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method populates @settings_hash with all adjustable parameters (class instance variables)
			# for further batch processing (for example for sending settings to a web-dialog or for writing
			# defaults using 'Sketchup.write_default'.
			
			def settings2hash
				@settings_hash["list_name"]=[@list_name, "string"]
				@settings_hash["sort_by"]=[@sort_by, "string"]
				@settings_hash["group_by"]=[@group_by, "string"]
				@settings_hash["sort_dir"]=[@sort_dir, "string"]
				@settings_hash["query_string"]=[@query_string, "string"]
				
				# Stick dialog height setting. Added in ver. 1.2.1 13-Dec-13.
				@settings_hash["stick_height"]=[@stick_height, "boolean"]
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method reads values from @settings_hash and sets values of corresponding instance variables.
			
			def hash2settings
				return if @settings_hash.keys.length==0
				@list_name=@settings_hash["list_name"][0]
				@sort_by=@settings_hash["sort_by"][0]
				@group_by=@settings_hash["group_by"][0]
				@sort_dir=@settings_hash["sort_dir"][0]
				@query_string=@settings_hash["query_string"][0]
				
				# Stick dialog height setting. Added in ver. 1.2.1 13-Dec-13.
				@stick_height=@settings_hash["stick_height"][0]
			end
			
			def write_defaults
				self.settings2hash
				Sketchup.write_default("LSS Zone List Defaults", "stick_height", @settings_hash["stick_height"][0].to_s)
			end
			
			def read_defaults
				default_value=Sketchup.read_default("LSS Zone List Defaults", "stick_height", "true")
				@settings_hash["stick_height"]=[default_value, "boolean"]
				@stick_height=default_value
			end
			
			# This method refreshes 'List Zones' dialog by performing custom initialization of it.
			
			def refresh
				js_command = "custom_init()"
				@zone_list_dial.execute_script(js_command) if js_command
			end
			
			# This method saves list template to a corresponding list template file.
			
			def save_template
				resource_dir=LSS_Dirs.new.resource_path
				presets_dir="#{resource_dir}/list_presets/"
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=14
					preset_file=File.open((presets_dir+@preset_file_name).force_encoding("UTF-8"), "w")
				else
					preset_file=File.open((presets_dir+@preset_file_name), "w")
				end
				@settings_hash.each_key{|key|
					if @settings_hash[key][0]
						str=key+"="+@settings_hash[key][0]
					else
						str=key+"="
					end
					preset_file.puts(str)
				}
				if @name_aliases.length>0
					preset_file.puts("<name_aliases>")
					@name_aliases.each_key{|key|
						if @name_aliases[key]
							str=key+"="+@name_aliases[key]
						else
							str=key+"="
						end
						preset_file.puts(str)
					}
					preset_file.puts("</name_aliases>")
				end
				if @charts_arr.length>0
					@charts_arr.each{|chart_hash|
						preset_file.puts("<chart>")
						chart_hash.each_key{|key|
							if chart_hash[key]
								str=key+"="+chart_hash[key]
							else
								str=key+"="
							end
							preset_file.puts(str)
						}
						preset_file.puts("</chart>")
					}
				end
				preset_file.close
			end
			
			# This method asks to specify an HTML file name to store a list using 'UI.savepanel' method, which
			# displays standard OS 'Save File' dialog.
			# Then method creates a file with specified name and opens it for writing.
			# Then method runs query and builds a simple table, which contains query results (ie zones list).
			
			def generate_list
				title=$lsszoneStrings.GetString("Save List of Zones to HTML File")
				resource_dir=LSS_Dirs.new.resource_path
				default_dir="#{resource_dir}/generated_lists"
				default_name=$lsszoneStrings.GetString("zones_list.html")
				list_path=UI.savepanel(title, default_dir, default_name)
				return if list_path.nil?
				ext_str=list_path.split(".")[1]
				if ext_str.nil? or ext_str==""
					list_path+=".html"
				else
					if ext_str!="html"
						list_path=list_path.split(".")[0]+".html"
					end
				end
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=14
					list_file=File.open(list_path.force_encoding("UTF-8"), "w")
				else
					list_file=File.open(list_path, "w")
				end
				list_file.puts("<html>")
					list_file.puts("<head>")
						list_file.puts("<title>#{@list_name}</title>")
						list_file.puts("<meta http-equiv='Content-Type' content='text/html; charset=UTF-8'>")
						list_file.puts("<style type='text/css'>")
								list_file.puts(".list_table")
								list_file.puts("{")
									list_file.puts("border: 1px solid black;")
									list_file.puts("width: 100%;")
									list_file.puts("border-collapse: collapse;")
								list_file.puts("}")
								list_file.puts(".value_cell")
								list_file.puts("{")
									list_file.puts("border: 1px solid black;")
								list_file.puts("}")
								list_file.puts(".header_cell")
								list_file.puts("{")
									list_file.puts("border: 1px solid black;")
									list_file.puts("background: silver;")
								list_file.puts("}")
						list_file.puts("</style>")
					list_file.puts("</head>")
					list_file.puts("<body>")
						list_file.puts("<table class='list_table'>")
							list_file.puts("<caption>")
								list_file.puts(@list_name)
							list_file.puts("</caption>")
							field_names=@query_string.gsub("@", "").split(" ").compact
							list_file.puts("<tr>")
								field_names.each{|field_name|
									list_file.puts("<th class='header_cell'>")
										col_name=@name_aliases[field_name]
										if col_name
											list_file.puts(col_name)
										else
											list_file.puts(field_name)
										end
									list_file.puts("</th>")
								}
							list_file.puts("</tr>")
							self.run_query
							i=1
							tot_cnt=@query_result.length
							progr_char="|"; rest_char="_"; scale_coeff=1
							progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
							js_command = "set_progress_state()"
							@zone_list_dial.execute_script(js_command) if js_command
							@query_result.each{|record|
								list_file.puts("<tr>")
								field_names.each{|field_name|
									list_file.puts("<td class='value_cell'>")
										val=record[field_name]
										list_file.puts(val)
									list_file.puts("</td>")
								}
								list_file.puts("</tr>")
								progr_bar.update(i)
								i+=1
								Sketchup.status_text=$lsszoneStrings.GetString("Saving to a file: ") + progr_bar.progr_string
							}
							Sketchup.status_text=$lsszoneStrings.GetString("Saving complete.")
							js_command = "set_default_state()"
							@zone_list_dial.execute_script(js_command) if js_command
						list_file.puts("</table>")
					list_file.puts("</body>")
				list_file.puts("</html>")
				list_file.close
				status = UI.openURL(list_path)
			end
		end #class LSS_Zone_List

		if( not file_loaded?("lss_zone_list.rb") )
			LSS_Zone_List_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_list.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	