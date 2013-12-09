# lss_zone_filter.rb ver. 1.2.1 beta 09-Dec-13
# The file, which contains 'Filter' dialog implementation

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		
		# This class adds "Filter" command to LSS Zone menu and to LSS Zone toolbar.
		
		class LSS_Zone_Filter_Cmd
			def initialize
				lss_zone_filter_cmd=UI::Command.new($lsszoneStrings.GetString("Filter")){
					lss_zone_filter=LSS_Zone_Filter.new
					lss_zone_filter.activate
				}
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=13
					lss_zone_filter_cmd.small_icon = "./tb_icons/filter_24.png"
					lss_zone_filter_cmd.large_icon = "./tb_icons/filter_32.png"
				else
					lss_zone_filter_cmd.small_icon = "./tb_icons/filter_16.png"
					lss_zone_filter_cmd.large_icon = "./tb_icons/filter_24.png"
				end
				lss_zone_filter_cmd.tooltip = $lsszoneStrings.GetString("Select zones, then click to display 'Filter Zones' dialog.")
				$lsszoneToolbar.add_item(lss_zone_filter_cmd)
				$lsszoneMenu.add_item(lss_zone_filter_cmd)
			end
		end #class LSS_Zone_Filter_Cmd
		
		# This class contains implementation of 'Filter' dialog.
		
		class LSS_Zone_Filter
			attr_accessor :category
			def initialize
				@model=Sketchup.active_model
				@selection=@model.selection
				@settings_hash=Hash.new
				@zoom_selection="true"
				@names_arr=nil # Array of collected zone names to place in 'autosuggest' widget
				
				# Hash, which contains states of roll groups states (folded/unfolded).
				# Added in ver. 1.2.1 06-Dec-13.
				@dialog_rolls_hash=Hash.new
				@dialog_rolls_hash["geom_tbody"]="-"
				@dialog_rolls_hash["trace_cont_tbody"]="-"
				@dialog_rolls_hash["mat_tbody"]="-"
				
				# Stick dialog height setting. Added in ver. 1.2.1 09-Dec-13.
				@stick_height="false"
			end

			# This method collects only zone objects from current selection set and
			# puts collected zone groups to @zones_arr for further processing.
			
			def selection_filter
				@zones_arr=Array.new
				selected_groups=@selection.select{|ent| ent.is_a?(Sketchup::Group)}
				@zones_arr=selected_groups.select{|grp| not(grp.get_attribute("LSS_Zone_Entity", "number").nil?)}
			end
			
			# This method reads attributes from 'etalon zone' first, then iterates through
			# all zones stored in @zones_arr and checks if each attribute is the same as 'etalon zone' has, then
			# assigns "..." value to an attribute if no or leaves the initial value of an attribute if yes.
			# So all common attributes have the same value, which 'etalon zone' has and all uncommon ones
			# have "..." value.
			# This method also counts how many zones actually present in a current selection set and
			# stores zones count for each zone type individually in @zone_types_cnt hash.
			
			def obtain_common_settings
				@names_arr=Array.new
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
				
				@area=etalon_zone.get_attribute("LSS_Zone_Entity", "area").to_f
				@perimeter=etalon_zone.get_attribute("LSS_Zone_Entity", "perimeter").to_f
				@volume=etalon_zone.get_attribute("LSS_Zone_Entity", "volume").to_f
				
				i=1; tot_cnt=@zones_arr.length
				progr_char="|"; rest_char="_"; scale_coeff=1
				progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
				@zones_arr.each{|zone_obj|
					zone_name=zone_obj.get_attribute("LSS_Zone_Entity", "name").to_s
					if @names_arr.include?(zone_name)==false
						@names_arr<<zone_name
					end
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
					
					@area="..." if zone_obj.get_attribute("LSS_Zone_Entity", "area").to_f!=@area.to_f
					@perimeter="..." if zone_obj.get_attribute("LSS_Zone_Entity", "area").to_f!=@perimeter.to_f
					@volume="..." if zone_obj.get_attribute("LSS_Zone_Entity", "area").to_f!=@volume.to_f
					@floor_area="..." if zone_obj.get_attribute("LSS_Zone_Entity", "floor_area").to_s!=@floor_area.to_s
					@ceiling_area="..." if zone_obj.get_attribute("LSS_Zone_Entity", "ceiling_area").to_s!=@ceiling_area.to_s
					@wall_area="..." if zone_obj.get_attribute("LSS_Zone_Entity", "wall_area").to_s!=@wall_area.to_s
					
					if zone_obj.get_attribute("LSS_Zone_Entity", "zone_type")=="box"
						@floors_count="..." if zone_obj.get_attribute("LSS_Zone_Entity", "floors_count").to_s!=@floors_count.to_s
					end
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
			
			# This method activates 'Filter' dialog in case if it is not already active:
			# - reads defaults
			# - filters selection (collects zone objects from current selection set)
			# - obtains settings, which are common to zone objects in a selection set
			# - creates 'Filter' dialog
			
			def activate
				return if $filter_dial_is_active # This check prevents dialog duplication.
				self.read_defaults
				self.selection_filter
				self.obtain_common_settings
				self.create_web_dial
				@conditions_hash=Hash.new
				$filter_dial_is_active=true
			end
			
			# This method refreshes data inside 'Filter' dialog. Usually it is called by selection observer
			# after detecting changes of current selection.
			# It is also called from 'Filter' dialog itself after filter condition changes.
			
			def refresh
				@filter_dialog.close
				lss_zone_filter=LSS_Zone_Filter.new
				lss_zone_filter.activate
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method populates @settings_hash with all adjustable parameters (class instance variables)
			# for further batch processing (for example for sending settings to a web-dialog or for writing
			# defaults using 'Sketchup.write_default').
			
			def settings2hash
				@settings_hash["number"]=[@number, "string"]
				@settings_hash["name"]=[@name, "string"]
				@settings_hash["height"]=[@height, "distance"]
				@settings_hash["floor_number"]=[@floor_number, "string"]
				@settings_hash["category"]=[@category, "string"]
				@settings_hash["zoom_selection"]=[@zoom_selection, "boolean"]
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
				
				@settings_hash["filter_list_content"]=[@filter_list_content, "string"]
				@settings_hash["rebuild_on_apply"]=[@rebuild_on_apply, "boolean"]
				
				@settings_hash["zone_type"]=[@zone_type, "string"]
				@settings_hash["floors_count"]=[@floors_count, "integer"]
				
				# Stick dialog height setting. Added in ver. 1.2.1 09-Dec-13.
				@settings_hash["stick_height"]=[@stick_height, "boolean"]
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and a web-dialog.
			# This method reads values from @settings_hash and sets values of corresponding instance variables.
			
			def hash2settings
				return if @settings_hash.keys.length==0
				@number=@settings_hash["number"][0]
				@name=@settings_hash["name"][0]
				@height=@settings_hash["height"][0]
				@floor_number=@settings_hash["floor_number"][0]
				@category=@settings_hash["category"][0]
				
				@zoom_selection=@settings_hash["zoom_selection"][0]
				
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
				
				@filter_list_content=@settings_hash["filter_list_content"][0]
				@rebuild_on_apply=@settings_hash["rebuild_on_apply"][0]
				
				@zone_type=@settings_hash["zone_type"][0]
				@floors_count=@settings_hash["floors_count"][0]
				
				# Stick dialog height setting. Added in ver. 1.2.1 09-Dec-13.
				@stick_height=@settings_hash["stick_height"][0]
			end
			
			# This method creates 'Filter' web-dialog.
			# It also starts selection observer in order to refresh dialog's content in case if selection is changed
			# or cleared.
			# Selection observer terminates after dialog is closed.
			
			def create_web_dial
				
				# Create the WebDialog instance
				@filter_dialog = UI::WebDialog.new($lsszoneStrings.GetString("Filter Zones"), true, "LSS Zone Filter", 350, 500, 200, 200, true)
				@filter_dialog.max_width=450
				@filter_dialog.min_width=280
			
				# Attach an action callback
				@filter_dialog.add_action_callback("get_data") do |web_dialog,action_name|
					view=Sketchup.active_model.active_view
					if action_name=="apply_settings"
						
					end
					if action_name=="get_settings" # From Ruby to web-dialog
						self.send_settings2dlg
						view.invalidate
					end
					if action_name=="get_zones_cnt"
						cnt_str="cnt_type=total,"
						@zone_types_cnt.each_key{|key|
							cnt_str+=key+"="+@zone_types_cnt[key].to_s+","
						}
						cnt_str.chomp!(",")
						js_command = "get_zones_cnt('" + cnt_str + "')"
						@filter_dialog.execute_script(js_command)
					end
					if action_name=="get_materials"
						self.send_materials2dlg
					end
					if action_name=="get_categories"
						self.send_categories2dlg
					end
					if action_name=="get_names"
						self.send_names2dlg
					end
					if action_name=="refresh_data"
						self.refresh
					end
					if action_name.split(",")[0]=="obtain_setting" # From web-dialog
						key=action_name.split(",")[1]
						val=action_name.split(",")[2]
						if @settings_hash[key]
							case @settings_hash[key][1]
								when "distance"
								if val.include?("-")
									# Handle range value case
									val1=val.split("-")[0]
									dist1=Sketchup.parse_length(val1)
									if dist1.nil?
										dist1=Sketchup.parse_length(val1.gsub(".",","))
									end
									val2=val.split("-")[1]
									dist2=Sketchup.parse_length(val2)
									if dist2.nil?
										dist2=Sketchup.parse_length(val2.gsub(".",","))
									end
									dist=dist1.to_s+"-"+dist2.to_s
								else
									dist=Sketchup.parse_length(val)
									if dist.nil?
										dist=Sketchup.parse_length(val.gsub(".",","))
									end
								end
								@settings_hash[key][0]=dist
								when "integer"
								if val.include?("-")
									@settings_hash[key][0]=val
								else
									@settings_hash[key][0]=val.to_i
								end
								when "area"
								if val.include?("-")
									# Handle range value case
									val1=val.split("-")[0]
									area1=LSS_Math.new.parse_area(val1)
									if area1.nil?
										area1=LSS_Math.new.parse_area(val1.gsub(".",","))
									end
									val2=val.split("-")[1]
									area2=LSS_Math.new.parse_area(val2)
									if area2.nil?
										area2=LSS_Math.new.parse_area(val2.gsub(".",","))
									end
									area=area1.to_s+"-"+area2.to_s
								else
									area=LSS_Math.new.parse_area(val)
								end
								@settings_hash[key][0]=area
								when "volume"
								if val.include?("-")
									# Handle range value case
									val1=val.split("-")[0]
									volume1=LSS_Math.new.parse_volume(val1)
									if volume1.nil?
										volume1=LSS_Math.new.parse_volume(val1.gsub(".",","))
									end
									val2=val.split("-")[1]
									volume2=LSS_Math.new.parse_volume(val2)
									if volume2.nil?
										volume2=LSS_Math.new.parse_volume(val2.gsub(".",","))
									end
									volume=volume1.to_s+"-"+volume2.to_s
								else
									volume=LSS_Math.new.parse_volume(val)
								end
								@settings_hash[key][0]=volume
								else
								@settings_hash[key][0]=val
							end
							self.hash2settings
						end
						# Handle stick height setting change
						if key=="stick_height"
							self.adjust_dial_size if val=="true"
						end
						self.apply_filter
					end
					if action_name.split(",")[0]=="condition_change"
						cond_name=action_name.split(",")[1]
						cond_val=action_name.split(",")[2]
						@conditions_hash[cond_name]=cond_val
						self.apply_filter
					end
					# Obtain roll state from dialog. Added in ver. 1.2.1 05-Dec-13
					if action_name.split(",")[0]=="obtain_roll_state"
						roll_grp_name=action_name.split(",")[1]
						roll_state=action_name.split(",")[2]
						@dialog_rolls_hash[roll_grp_name]=roll_state
					end
					# Send roll states from ruby to web-dialog. Added in ver. 1.2.1 06-Dec-13
					if action_name=="get_roll_states"
						@dialog_rolls_hash.each_key{|roll_grp_name|
							roll_state=@dialog_rolls_hash[roll_grp_name]
							roll_pair_str= roll_grp_name.to_s + "|" + roll_state.to_s
							js_command = "set_roll_state('" + roll_pair_str + "')" if roll_pair_str
							@filter_dialog.execute_script(js_command) if js_command
						}
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
					if action_name=="init_dial_d_size"
						js_command="send_visible_size()"
						@filter_dialog.execute_script(js_command) if js_command
						@init_width=@visible_width
						@init_height=@visible_height
						@filter_dialog.set_size(@init_width, @init_height)
						js_command="send_visible_size()"
						@filter_dialog.execute_script(js_command) if js_command
						@d_height=@init_height-@visible_height
						@d_width=@init_width-@visible_width
						win_width=@init_width+@d_width
						win_height=@init_height+@d_height
						@filter_dialog.set_size(win_width, win_height)
					end
					if action_name=="adjust_dial_size"
						if @stick_height=="true"
							self.adjust_dial_size
						end
					end
					# Content size block end
					if action_name=="reset"
						@filter_dialog.close
						@selection.clear
						@selection.add(@zones_arr)
						lss_zone_filter=LSS_Zone_Filter.new
						lss_zone_filter.activate
					end
					if action_name=="close_dial"
						@filter_dialog.close
					end
				end
				resource_dir=LSS_Dirs.new.resource_path
				dial_path="#{resource_dir}/lss_zone/lss_zone_filter.html"
				@filter_dialog.set_file(dial_path)
				lss_zone_app_observer=LSS_Zone_App_Observer.new(@filter_dialog)
				Sketchup.add_observer(lss_zone_app_observer)
				@selection_observer=LSS_Zone_Selection_Observer.new(@filter_dialog)
				@selection.add_observer(@selection_observer)
				@filter_dialog.show()
				@filter_dialog.set_on_close{
					$filter_dial_is_active=false
					self.write_defaults
					@selection.remove_observer(@selection_observer)
					Sketchup.remove_observer(lss_zone_app_observer)
					Sketchup.active_model.select_tool(nil)
					@zones_arr=nil
				}
			end
			
			# This method adjusts the size of a dialog to fit its content. Added in ver. 1.2.1 09-Dec-13.
			def adjust_dial_size
				if @cont_height and @cont_width
					if @cont_height>0 and @cont_width>0
						win_width=@cont_width+@d_width
						win_height=@cont_height+@d_height
						chk_bottom_y=win_height+@dial_y
						bottom_offset=chk_bottom_y-@scr_height
						win_height-=bottom_offset if bottom_offset>0
						@filter_dialog.set_size(win_width, win_height)
					end
				end
			end
			
			# This method contains the main logic.
			# First of all it makes 'new_selection' array, which is actually a copy of @zones_arr
			# (array of initially selected zone objects).
			# Then it iterates through @zones_arr and removes any corresponding item from 'new_selection' array
			# in case if it doesn't meet filter conditions stored in @conditions_hash.
			# Then it clears selection and adds to selection what's left in 'new_selection' array.
			# Then it zooms to changed selection if @zoom_selection=="true".
			# Then it updates selected zones counter and sends counter values to the 'Filter' dialog.
			
			def apply_filter
				return if @zones_arr.nil?
				new_selection=Array.new(@zones_arr)
				@zones_arr.each{|zone_obj|
					@conditions_hash.each_key{|key|
						if @conditions_hash[key]=="true"
							zone_val_units=zone_obj.get_attribute("LSS_Zone_Entity", key)
							filter_val_units=@settings_hash[key][0]
							zone_val=self.format_value(key, zone_val_units)
							filter_val=self.format_value(key, filter_val_units)
							value_type=Sketchup.read_default("LSS Zone Data Types", key)
							if value_type=="distance" or value_type=="area" or value_type=="volume" or key=="floor_number" or key=="floors_count"
								if filter_val_units.to_s.include?("-")
									filter_val1=filter_val_units.split("-")[0].to_f
									filter_val2=filter_val_units.split("-")[1].to_f
									if (zone_val_units.to_f<filter_val1 and zone_val_units.to_f<filter_val2) or (zone_val_units.to_f>filter_val1 and zone_val_units.to_f>filter_val2)
										new_selection.delete(zone_obj)
									end
								else
									if zone_val!=filter_val
										new_selection.delete(zone_obj)
									end
								end
							else
								if key=="memo"
									if zone_val.include?(filter_val)==false
										new_selection.delete(zone_obj)
									end
								else
									if zone_val!=filter_val
										new_selection.delete(zone_obj)
									end
								end
							end
						end
					}
				}
				@selection.remove_observer(@selection_observer)
				@selection.clear
				@selection.add(new_selection)
				@selection.add_observer(@selection_observer)
				if @zoom_selection=="true"
					view=Sketchup.active_model.active_view
					view.zoom(@selection) if @selection.count>0
				end
				if @zones_arr.length>0
					show_tool=LSS_Show_Filter_Set_Tool.new(@zones_arr)
					Sketchup.active_model.select_tool(show_tool)
				end
				# Update selected zones counter
				@zone_types_cnt=Hash.new
				@zone_types_cnt["room"]=0; @zone_types_cnt["box"]=0; @zone_types_cnt["flat"]=0
				cnt_str="cnt_type=selected,"
				@selection.each{|zone_obj|
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
				}
				@zone_types_cnt.each_key{|key|
					cnt_str+=key+"="+@zone_types_cnt[key].to_s+","
				}
				cnt_str.chomp!(",")
				js_command = "get_zones_cnt('" + cnt_str + "')"
				@filter_dialog.execute_script(js_command)
			end
			
			def format_value(key, value)
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
						value=value.to_s
				end
				value
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method reads default values of settings using 'Sketchup.read_default'.
			
			def read_defaults
				@zoom_selection=Sketchup.read_default("LSS_Zone", "zoom_selection", "true")
				
				# Group states (folded/unfolded). Added in ver. 1.2.1 05-Dec-13
				@dialog_rolls_hash.each_key{|key|
					@dialog_rolls_hash[key]=Sketchup.read_default("LSS_Zone_Filter_Rolls", key, "-")
				}
				
				# Stick dialog height setting. Added in ver. 1.2.1 09-Dec-13.
				@stick_height=Sketchup.read_default("LSS_Zone_Filter_Dialog", "stick_height", "false")
				self.settings2hash
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method writes default values of settings using 'Sketchup.write_default'.
			
			def write_defaults
				Sketchup.write_default("LSS_Zone", "zoom_selection", @zoom_selection)
				
				# Group states (folded/unfolded). Added in ver. 1.2.1 05-Dec-13
				@dialog_rolls_hash.each_key{|key|
					Sketchup.write_default("LSS_Zone_Filter_Rolls", key, @dialog_rolls_hash[key])
				}
				
				# Stick dialog height setting. Added in ver. 1.2.1 09-Dec-13.
				Sketchup.write_default("LSS_Zone_Filter_Dialog", "stick_height", @stick_height)
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and a web-dialog.
			# This method performs batch sending of settings to a web-dialog by iterating through a @settings_hash.
			# Each value of @settings_hash is an array of two values:
			# 1. value itself
			# 2. value type
			# So #send_settings2dlg method uses 'value_type' to format representation of a value in a web-dialog.
			# The point is that all dimensional data in Sketchup is stored in decimal inches, so it is necessary
			# to format length, area and volume values in order to represent a value as a string 
			# in a model-specific format.
			
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
					@filter_dialog.execute_script(js_command) if js_command
				}
			end
			
			# This method sends material names, which are present in an active model
			# to a web-dialog.
			# It helps to populate material selectors (drop-down lists) with material names in a web-dialog.
			
			def send_materials2dlg
				# Send list of materials from an active model to a web-dialog
				js_command = "clear_mats_arr()"
				@filter_dialog.execute_script(js_command) if js_command
				@materials=@model.materials
				@materials.each{|mat|
					col_obj=mat.color
					col_arr=[col_obj.red, col_obj.green, col_obj.blue]
					col=col_arr.join(",")
					mat_str= mat.name + "|" + col
					js_command = "get_material('" + mat_str + "')"
					@filter_dialog.execute_script(js_command) if js_command
				}
				js_command = "build_mat_list()"
				@filter_dialog.execute_script(js_command) if js_command
			end
			
			# This method sends category names, which are present in a current model to a web-dialog.
			# All categories are stored in an active model's attribute dictionary called 'LSS Zone Categories',
			# since each time, when new category is created its name instantly adds to the mentioned above
			# dictionary.
			# So method iterates through this dictionary and sends its keys to a web-dialog.
			# There is an 'auto-suggest' widget in a dialog, which uses an array of category names
			# for more comfortable filling out of a 'Category' field.
			
			def send_categories2dlg
				# Send list of categories from an active model to a web-dialog
				js_command = "clear_cats_arr()"
				@filter_dialog.execute_script(js_command) if js_command
				categories=@model.attribute_dictionary("LSS Zone Categories")
				if categories
					categories.each_key{|cat|
						js_command = "get_category('" + cat + "')"
						@filter_dialog.execute_script(js_command) if js_command
					}
					js_command = "bind_categories()"
					@filter_dialog.execute_script(js_command) if js_command
				else
					if @category
						js_command = "get_category('" + @category + "')"
						@filter_dialog.execute_script(js_command) if js_command
						js_command = "bind_categories()"
						@filter_dialog.execute_script(js_command) if js_command
					else
						@category="#Default"
						js_command = "get_category('" + @category + "')"
						@filter_dialog.execute_script(js_command) if js_command
						js_command = "bind_categories()"
						@filter_dialog.execute_script(js_command) if js_command
					end
				end
			end
			
			# This method sends collected list of names to a web-dialog.
			# 'Name' field has an 'auto-suggest' widget, which helps to pick certain name
			# from suggestion list instead of typing it.
			
			def send_names2dlg
				# Send collected list of names to a web-dialog. Added in ver. 1.1.0 beta 27-Oct-13.
				js_command = "clear_names_arr()"
				@filter_dialog.execute_script(js_command) if js_command
				if @names_arr
					if @names_arr.length>0
						@names_arr.each{|name|
							js_command = "get_name('" + name + "')"
							@filter_dialog.execute_script(js_command) if js_command
						}
						js_command = "bind_names()"
						@filter_dialog.execute_script(js_command) if js_command
					end
				end
			end
		end #class LSS_Zone_Filter
		
		# This class contains implementation of a service tool, which performs no actions, but only
		# displays the initial selection set by showing red dotted bounding boxes of initially selected
		# zones.
		
		class LSS_Show_Filter_Set_Tool
		
			# Initializes array of initially selected zones
			
			def initialize(zones_arr)
				@zones_arr=zones_arr
			end
			
			# Perform checks of @zones_arr then call draw bounding boxes method of all zones, which are in @zones_arr.
			
			def draw(view)
				return if @zones_arr.nil?
				if @zones_arr.length>0
					self.draw_bnds(view)
				end
			end
			
			# Draw bounding boxes of all zones, which are in @zones_arr.
			
			def draw_bnds(view)
				pts_arr=Array.new
				@zones_arr.each{|zone|
					bnds=zone.bounds
					pt1=bnds.corner(0)
					pt2=bnds.corner(1)
					pts_arr<<view.screen_coords(pt1)
					pts_arr<<view.screen_coords(pt2)
					pt1=bnds.corner(1)
					pt2=bnds.corner(3)
					pts_arr<<view.screen_coords(pt1)
					pts_arr<<view.screen_coords(pt2)
					pt1=bnds.corner(3)
					pt2=bnds.corner(2)
					pts_arr<<view.screen_coords(pt1)
					pts_arr<<view.screen_coords(pt2)
					pt1=bnds.corner(2)
					pt2=bnds.corner(0)
					pts_arr<<view.screen_coords(pt1)
					pts_arr<<view.screen_coords(pt2)
					pt1=bnds.corner(4)
					pt2=bnds.corner(5)
					pts_arr<<view.screen_coords(pt1)
					pts_arr<<view.screen_coords(pt2)
					pt1=bnds.corner(5)
					pt2=bnds.corner(7)
					pts_arr<<view.screen_coords(pt1)
					pts_arr<<view.screen_coords(pt2)
					pt1=bnds.corner(7)
					pt2=bnds.corner(6)
					pts_arr<<view.screen_coords(pt1)
					pts_arr<<view.screen_coords(pt2)
					pt1=bnds.corner(6)
					pt2=bnds.corner(4)
					pts_arr<<view.screen_coords(pt1)
					pts_arr<<view.screen_coords(pt2)
					pt1=bnds.corner(0)
					pt2=bnds.corner(4)
					pts_arr<<view.screen_coords(pt1)
					pts_arr<<view.screen_coords(pt2)
					pt1=bnds.corner(1)
					pt2=bnds.corner(5)
					pts_arr<<view.screen_coords(pt1)
					pts_arr<<view.screen_coords(pt2)
					pt1=bnds.corner(3)
					pt2=bnds.corner(7)
					pts_arr<<view.screen_coords(pt1)
					pts_arr<<view.screen_coords(pt2)
					pt1=bnds.corner(2)
					pt2=bnds.corner(6)
					pts_arr<<view.screen_coords(pt1)
					pts_arr<<view.screen_coords(pt2)
				}
				view.line_stipple="."
				view.drawing_color="red"
				view.draw2d(GL_LINES, pts_arr)
			end
			
			def deactivate(view)
				@zones_arr=nil
				view.invalidate
			end
			
			# This method displays custom content within 'Instructor'
			
			def getInstructorContentDirectory
				locale=Sketchup.get_locale 
				dir_path="../../../../Plugins/lss_zone/Resources/#{locale}/help/filter/"
				return dir_path
			end
		end #class LSS_Show_Filter_Set_Tool

		if( not file_loaded?("lss_zone_filter.rb") )
			LSS_Zone_Filter_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_filter.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	