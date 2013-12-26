# lss_zone_tool.rb ver. 1.2.1 alpha 26-Dec-13
# The main file, which contains LSS Zone Tool implementation.

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		#loads class wich contains Zone Entity
		require 'lss_zone/lss_zone_entity.rb'
		
		# This class adds 'LSS Zone' command to LSS Zone toolbar and LSS Zone submenu.
		
		class LSS_Zone_Tool_Cmd
			def initialize
				@su_tools=Sketchup.active_model.tools
				@lss_zone_tool_observer=nil
				@lss_zone_tool_observer_state="disabled"
				
				lss_zone_cmd=UI::Command.new($lsszoneStrings.GetString("LSS Zone")){
					lss_zone_tool=LSS_Zone_Tool.new
					Sketchup.active_model.select_tool(lss_zone_tool)
				}
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=13
					lss_zone_cmd.small_icon = "./tb_icons/web_dial_24.png"
					lss_zone_cmd.large_icon = "./tb_icons/web_dial_32.png"
				else
					lss_zone_cmd.small_icon = "./tb_icons/web_dial_16.png"
					lss_zone_cmd.large_icon = "./tb_icons/web_dial_24.png"
				end
				lss_zone_cmd.tooltip = $lsszoneStrings.GetString("Click to launch LSS Zone dialog window.")
				lss_zone_cmd.menu_text=$lsszoneStrings.GetString("LSS Zone")
				$lsszoneToolbar.add_item(lss_zone_cmd)
				$lsszoneMenu.add_item(lss_zone_cmd)
			end
			
			def set_observer_state
				if @lss_zone_tool_observer_state=="disabled"
					@lss_zone_tool_observer=LSS_Zone_Tools_Observer.new
					@su_tools.add_observer(@lss_zone_tool_observer)
					@lss_zone_tool_observer_state="enabled"
				else
					@su_tools.remove_observer(@lss_zone_tool_observer) if @lss_zone_tool_observer
					@lss_zone_tool_observer_state="disabled"
				end
			end
		end #class LSS_Zone_Tool_Cmd
		
		# This class contains implementation of main extension's tool.
		# It displays 'LSS Zone' tool's dialog wich allows to draw new zone contour or pick a face, which represents
		# zone's contour, then set zone's attributes and finally generate new zone object in an active model.
		
		class LSS_Zone_Tool
			def initialize
				pick_face_path=Sketchup.find_support_file("pick_face_cur.png", "Plugins/lss_zone/cursors/")
				@pick_face_cur_id=UI.create_cursor(pick_face_path, 0, 0)
				draw_contour_path=Sketchup.find_support_file("draw_contour_cur.png", "Plugins/lss_zone/cursors/")
				@draw_contour_cur_id=UI.create_cursor(draw_contour_path, 0, 0)
				finish_contour_path=Sketchup.find_support_file("finish_contour_cur.png", "Plugins/lss_zone/cursors/")
				@finish_contour_cur_id=UI.create_cursor(finish_contour_path, 0, 0)
				specify_height_path=Sketchup.find_support_file("specify_height_cur.png", "Plugins/lss_zone/cursors/")
				@specify_height_cur_id=UI.create_cursor(specify_height_path, 0, 0)
				eye_dropper_path=Sketchup.find_support_file("eye_dropper_cur.png", "Plugins/lss_zone/cursors/")
				@eye_dropper_cur_id=UI.create_cursor(eye_dropper_path, 0, 24)
				over_obj_path=Sketchup.find_support_file("over_obj_cur.png", "Plugins/lss_zone/cursors/")
				@over_obj_cur_id=UI.create_cursor(over_obj_path, 0, 0)
				drag_obj_path=Sketchup.find_support_file("drag_obj_cur.png", "Plugins/lss_zone/cursors/")
				@drag_obj_cur_id=UI.create_cursor(drag_obj_path, 0, 0)
				cut_opening_path=Sketchup.find_support_file("cut_opening_cur.png", "Plugins/lss_zone/cursors/")
				@cut_opening_cur_id=UI.create_cursor(cut_opening_path, 0, 0)
				default_path=Sketchup.find_support_file("default_cur.png", "Plugins/lss_zone/cursors/")
				@default_cur_id=UI.create_cursor(default_path, 0, 0)
				pick_int_pt_path=Sketchup.find_support_file("pick_int_pt_cur.png", "Plugins/lss_zone/cursors/")
				@pick_int_pt_cur_id=UI.create_cursor(pick_int_pt_path, 13, 10)
				@pick_state=nil # Indicates cursor type while the tool is active
				
				# Identification
				@number="001"
				@name=$lsszoneStrings.GetString("Room")
				# Geometry
				@area=0
				@perimeter=0
				@height=0
				@volume=0
				# Additional
				@floor_level=0
				@floor_number=0
				@category=$lsszoneStrings.GetString("#Default")
				@memo=""
				# Nodal points
				@nodal_points=Array.new
				# Materials
				@floor_material=""
				@wall_material=""
				@ceiling_material=""
				# Elements' Areas
				@floor_area=0
				@wall_area=0
				@ceiling_area=0
				# Elements' Types
				@floor_refno=""
				@wall_refno=""
				@ceiling_refno=""
				# Zone type
				@zone_type="room"
				# Box type settings
				@floors_count=1
				
				@settings_hash=Hash.new
				
				@eye_dropper_type=nil		#types: floor, ceiling, wall
				@under_cur_mat=nil
				
				@selected_zone=nil
				@zone_under_cur=nil
				@opening_under_cur_ind=nil
				@over_pt_ind=nil
				@over_mid_pt_ind=nil
				@drag_state=false
				@over_first_pt=false
				@over_height_adj_pt=false
				
				@mid_points=Array.new
				
				@show_geom_summary=true
				
				# Openings
				@openings_arr=Array.new
				@new_opening=nil
				
				# Labels
				@labels_arr=nil
				
				# Internal parameters
				@ready4apply=false			# if true then it is possible to apply settings just by hitting "Enter"
				@last_state=nil				# restore last state after generating new zone object or after "Apply"
				
				# Drawing helpers
				@const_pts_arr=Array.new
				
				# Internal point check height
				@int_pt_chk_hgt=100.0
				
				# Handler to trace contour
				@trace_cont=nil
				
				sample_size=12.0
				pt1=Geom::Point3d.new(sample_size, sample_size, 0)
				pt2=Geom::Point3d.new(sample_size, -sample_size, 0)
				pt3=Geom::Point3d.new(-sample_size, -sample_size, 0)
				pt4=Geom::Point3d.new(-sample_size, sample_size, 0)
				# Array of points representing square (for material color sample)
				@square_pts=[pt1, pt2, pt3, pt4]
				
				@picked_floor_mat=nil
				@picked_wall_mat=nil
				
				# Hash, which contains states of roll groups states (folded/unfolded).
				# Added in ver. 1.2.1 05-Dec-13.
				@dialog_rolls_hash=Hash.new
				@dialog_rolls_hash["geom_group"]="-"
				@dialog_rolls_hash["trace_cont_group"]="-"
				@dialog_rolls_hash["mat_group"]="-"
				
				# Stick dialog height setting. Added in ver. 1.2.1 09-Dec-13.
				@stick_height="true"
			end
			
			# Set cursor to indicate current tool's state:
			# - 'pick_face' state allows to pick any face to use its contour as a contour of a future zone
			# - 'draw_contour' state allows to draw contour of a zone vertex-by-vertex
			# - 'pick_int_pt' state allows to pick an internal point inside a room (added in ver. 1.2.0, 13-Nov-13)
			# - 'specify_height' state allows to set zone's height
			# - 'eye_dropper' state allows to pick a material by single-clicking on a face in an active model
			# - 'over_obj' state becomes active when cursor is over nodal point of zone's contour or center point of a segment
			# or height adjustment point
			# - 'cut_opening' state allows to add new opening(s) to selected zone
			# - nil state allows to select any existing zone in an active model.
			
			def onSetCursor
				case @pick_state
					when "pick_face"
					UI.set_cursor(@pick_face_cur_id)
					when "draw_contour"
					if @over_first_pt
						UI.set_cursor(@finish_contour_cur_id)
					else
						UI.set_cursor(@draw_contour_cur_id)
					end
					# Added in ver. 1.2.0, 13-Nov-13.
					when "pick_int_pt"
					UI.set_cursor(@pick_int_pt_cur_id)
					when "specify_height"
					UI.set_cursor(@specify_height_cur_id)
					when "eye_dropper"
					UI.set_cursor(@eye_dropper_cur_id)
					when "over_obj"
					if @drag_state
						UI.set_cursor(@drag_obj_cur_id)
					else
						UI.set_cursor(@over_obj_cur_id)
					end
					when "cut_opening"
					UI.set_cursor(@cut_opening_cur_id)
					else
					UI.set_cursor(@default_cur_id)
				end
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method reads default values of settings using 'Sketchup.read_default'.
			
			def read_defaults
				@number=Sketchup.read_default("LSS_Zone", "number", "001")
				@name=Sketchup.read_default("LSS_Zone", "name", "Room")
				@height=Sketchup.read_default("LSS_Zone", "height", 0)
				@floor_number=Sketchup.read_default("LSS_Zone", "floor_number", "0")
				@category=Sketchup.read_default("LSS_Zone", "category", $lsszoneStrings.GetString("#Default"))
				@category=$lsszoneStrings.GetString("#Default") if @category.nil? or @category==""
				
				@floor_level=Sketchup.read_default("LSS_Zone", "floor_level", 0)
				
				@floor_material=Sketchup.read_default("LSS_Zone", "floor_material", "")
				@wall_material=Sketchup.read_default("LSS_Zone", "wall_material", "")
				@ceiling_material=Sketchup.read_default("LSS_Zone", "ceiling_material", "")
				@floor_refno=Sketchup.read_default("LSS_Zone", "floor_refno", "")
				@wall_refno=Sketchup.read_default("LSS_Zone", "wall_refno", "")
				@ceiling_refno=Sketchup.read_default("LSS_Zone", "ceiling_refno", "")
				
				@zone_type=Sketchup.read_default("LSS_Zone", "zone_type", "room")
				@floors_count=Sketchup.read_default("LSS_Zone", "floors_count", 1)
				
				# Stick dialog height setting. Added in ver. 1.2.1 09-Dec-13.
				@stick_height=Sketchup.read_default("LSS_Zone", "stick_height", "true")
				
				self.settings2hash
				
				# Group of dialog settings states (folded/unfolded). Added in ver. 1.2.1 06-Dec-13
				@dialog_rolls_hash.each_key{|key|
					@dialog_rolls_hash[key]=Sketchup.read_default("LSS_Zone_Tool_Dialog_Rolls", key, "-")
				}
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
				
				@settings_hash["zone_type"]=[@zone_type, "string"]
				@settings_hash["floors_count"]=[@floors_count, "integer"]
				
				# Store data types
				@settings_hash.each_key{|key|
					Sketchup.write_default("LSS Zone Data Types", key, @settings_hash[key][1])
				}
				
				# Store supplementary data types
				Sketchup.write_default("LSS Zone Data Types", "wall_ext_ops_area", "area")
				Sketchup.write_default("LSS Zone Data Types", "wall_int_ops_area", "area")
				Sketchup.write_default("LSS Zone Data Types", "floor_ext_ops_area", "area")
				Sketchup.write_default("LSS Zone Data Types", "floor_int_ops_area", "area")
				Sketchup.write_default("LSS Zone Data Types", "ceiling_ext_ops_area", "area")
				Sketchup.write_default("LSS Zone Data Types", "ceiling_int_ops_area", "area")
				
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
				
				@floor_level=@settings_hash["floor_level"][0]
				@memo=@settings_hash["memo"][0]
				@floor_material=@settings_hash["floor_material"][0]
				@wall_material=@settings_hash["wall_material"][0]
				@ceiling_material=@settings_hash["ceiling_material"][0]
				@floor_refno=@settings_hash["floor_refno"][0]
				@wall_refno=@settings_hash["wall_refno"][0]
				@ceiling_refno=@settings_hash["ceiling_refno"][0]
				
				@zone_type=@settings_hash["zone_type"][0]
				@floors_count=@settings_hash["floors_count"][0]
				
				# Stick dialog height setting. Added in ver. 1.2.1 09-Dec-13.
				@stick_height=@settings_hash["stick_height"][0]
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method writes default values of settings using 'Sketchup.write_default'.
			
			def write_defaults
				self.settings2hash
				@settings_hash.each_key{|key|
					Sketchup.write_default("LSS_Zone", key, @settings_hash[key][0].to_s)
				}
				
				# Trace contour settings
				Sketchup.write_default("LSS Zone Defaults", "int_pt_chk_hgt", @int_pt_chk_hgt)
				
				# Group of settings states (folded/unfolded). Added in ver. 1.2.1 06-Dec-13
				@dialog_rolls_hash.each_key{|key|
					Sketchup.write_default("LSS_Zone_Tool_Dialog_Rolls", key, @dialog_rolls_hash[key])
				}
			end
			
			# This method creates 'LSS Zone' web-dialog.
			
			def create_web_dial
				# Read defaults
				self.read_defaults
				
				# Create the WebDialog instance
				@zone_dialog = UI::WebDialog.new($lsszoneStrings.GetString("LSS Zone"), true, "LSS Zone", 350, 500, 200, 200, true)
				@zone_dialog.max_width=450
				@zone_dialog.min_width=210
			
				# Attach an action callback
				@zone_dialog.add_action_callback("get_data") do |web_dialog,action_name|
					view=Sketchup.active_model.active_view
					if action_name=="apply_settings"
						cat_is_new=self.cat_is_new?(@category)
						if cat_is_new
							self.add_new_category(@category)
						end
						self.create_zone_entity
						if @zone_entity
							if @selected_zone
								self.recreate_zone
							else
								@zone_entity.create_zone
								self.small_reset
								@pick_state=@last_state
								# Special case handling added in ver. 1.2.0 19-Nov-13.
								if @last_state=="pick_int_pt"
									@trace_cont=LSS_Zone_Trace_Cont.new
									@nodal_points=Array.new
									@trace_cont.int_pt_chk_hgt=@int_pt_chk_hgt
								end
								self.onSetCursor
								@last_state=nil
								self.increment_number
							end
						else
							UI.messagebox($lsszoneStrings.GetString("Draw zone or pick existing face before clicking 'Create'"))
						end
					end
					if action_name=="pick_face"
						self.small_reset
						@ip.clear
						@ip1.clear
						if( view )
							view.tooltip = nil
							view.invalidate
						end
						@pick_state="pick_face"
						self.onSetCursor
					end
					if action_name=="draw_contour"
						self.small_reset
						@ip.clear
						@ip1.clear
						if( view )
							view.tooltip = nil
							view.invalidate
						end
						
						@pick_state="draw_contour"
						self.onSetCursor
					end
					if action_name=="pick_int_pt"
						self.small_reset
						@ip.clear
						@ip1.clear
						if( view )
							view.tooltip = nil
							view.invalidate
						end
						@trace_cont=LSS_Zone_Trace_Cont.new
						self.set_trace_cont_defaults
						@nodal_points=Array.new
						@trace_cont.int_pt_chk_hgt=@int_pt_chk_hgt
						@pick_state="pick_int_pt"
						self.onSetCursor
						Sketchup.vcb_label=$lsszoneStrings.GetString("Check height: ")
						Sketchup.vcb_value=Sketchup.format_length(@int_pt_chk_hgt.to_f)
					end
					if action_name.split(",")[1]=="floor_eye_dropper"
						@pick_state="eye_dropper"
						self.onSetCursor
						@eye_dropper_type="floor"
						js_command = "press_eye_dropper_btn('" + @eye_dropper_type + "')" if @eye_dropper_type
						@zone_dialog.execute_script(js_command) if js_command
						# Unpress other buttons
						js_command = "unpress_eye_dropper_btn('" + "ceiling" + "')" if @eye_dropper_type
						@zone_dialog.execute_script(js_command) if js_command
						js_command = "unpress_eye_dropper_btn('" + "wall" + "')" if @eye_dropper_type
						@zone_dialog.execute_script(js_command) if js_command
					end
					if action_name.split(",")[1]=="ceiling_eye_dropper"
						@pick_state="eye_dropper"
						self.onSetCursor
						@eye_dropper_type="ceiling"
						js_command = "press_eye_dropper_btn('" + @eye_dropper_type + "')" if @eye_dropper_type
						@zone_dialog.execute_script(js_command) if js_command
						# Unpress other buttons
						js_command = "unpress_eye_dropper_btn('" + "floor" + "')" if @eye_dropper_type
						@zone_dialog.execute_script(js_command) if js_command
						js_command = "unpress_eye_dropper_btn('" + "wall" + "')" if @eye_dropper_type
						@zone_dialog.execute_script(js_command) if js_command
					end
					if action_name.split(",")[1]=="wall_eye_dropper"
						@pick_state="eye_dropper"
						self.onSetCursor
						@eye_dropper_type="wall"
						js_command = "press_eye_dropper_btn('" + @eye_dropper_type + "')" if @eye_dropper_type
						@zone_dialog.execute_script(js_command) if js_command
						# Unpress other buttons
						js_command = "unpress_eye_dropper_btn('" + "ceiling" + "')" if @eye_dropper_type
						@zone_dialog.execute_script(js_command) if js_command
						js_command = "unpress_eye_dropper_btn('" + "floor" + "')" if @eye_dropper_type
						@zone_dialog.execute_script(js_command) if js_command
					end
					if action_name=="cut_opening"
						@new_opening=nil
						@pick_state="cut_opening"
						self.onSetCursor
					end
					if action_name=="get_settings" # From Ruby to web-dialog
						self.send_settings2dlg
						view.invalidate
					end
					if action_name=="get_materials"
						self.send_materials2dlg
					end
					if action_name=="get_categories"
						self.send_categories2dlg
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
							# Change z coordinate of @nodal_points in case if @floor_level was changed
							if key=="floor_level"
								@nodal_points.each_index{|ind|
									pt=@nodal_points[ind]
									pt.z=Sketchup.parse_length(val.gsub(".",","))
									@nodal_points[ind]=pt
								}
							end
							# Recalculate @volume after @height change
							if key=="height"
								@height=@settings_hash[key][0]
								@volume=@area.to_f*@height.to_f
								@settings_hash["volume"]=@volume
								vol_str=LSS_Math.new.format_volume(@settings_hash[key][0].to_f)
								js_command = "refresh_volume('" + vol_str + "')"
								@zone_dialog.execute_script(js_command)
							end
							# Switch dialog view according to zone type
							if key=="zone_type"
								js_command = "zone_type_view('" + val + "')"
								@zone_dialog.execute_script(js_command)
								if val=="flat"
									@settings_hash["height"]=0
									@height=0
								end
							end
							
							# Handle stick height setting change
							if key=="stick_height"
								LSS_Zone_Utils.new.adjust_dial_size(@zone_dialog, @cont_height, @cont_width, @d_width, @d_height, @dial_y, @scr_height) if val=="true"
							end
						end
						self.hash2settings
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
							@zone_dialog.execute_script(js_command) if js_command
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
					if action_name.split(",")[0]=="hdr_ftr_height"
						@hdr_ftr_height=action_name.split(",")[1].to_i
					end
					if action_name=="init_dial_d_size"
						js_command="send_visible_size()"
						@zone_dialog.execute_script(js_command) if js_command
						@init_width=@visible_width
						@init_height=@visible_height
						@zone_dialog.set_size(@init_width, @init_height)
						js_command="send_visible_size()"
						@zone_dialog.execute_script(js_command) if js_command
						@d_height=@init_height-@visible_height + @hdr_ftr_height
						@d_width=@init_width-@visible_width
						win_width=@init_width+@d_width
						win_height=@init_height+@d_height
						@zone_dialog.set_size(win_width, win_height)
					end
					if action_name=="adjust_dial_size"
						if @stick_height=="true"
							LSS_Zone_Utils.new.adjust_dial_size(@zone_dialog, @cont_height, @cont_width, @d_width, @d_height, @dial_y, @scr_height)
						end
					end
					# Content size block end
					
					# Dialog style handling. Added in ver. 1.2.1 26-Dec-13.
					if action_name=="get_dial_style"
						dial_style=Sketchup.read_default("LSS Zone Defaults", "dial_style", "standard")
						js_command="get_dial_style('" + dial_style + "')"
						@zone_dialog.execute_script(js_command) if js_command
					end
					if action_name=="reset"
						view=Sketchup.active_model.active_view
						self.reset(view)
						view.invalidate
					end
					if action_name=="cancel_action"
						reason="dialog_cancel"
						self.onCancel(reason, view)
					end
				end
				resource_dir=LSS_Dirs.new.resource_path
				dial_path="#{resource_dir}/lss_zone/lss_zone.html"
				@zone_dialog.set_file(dial_path)
				@zone_dialog.show()
				@zone_dialog.set_on_close{
					self.write_defaults
					Sketchup.active_model.select_tool(nil)
				}
			end

			def set_trace_cont_defaults
				@int_pt_chk_hgt=Sketchup.read_default("LSS Zone Defaults","int_pt_chk_hgt", 100.0)
				@aperture_size=Sketchup.read_default("LSS Zone Defaults","aperture_size", 4.0)
				@trace_openings=Sketchup.read_default("LSS Zone Defaults","trace_openings", "true")
				@use_materials=Sketchup.read_default("LSS Zone Defaults","use_materials", "true")
				@min_wall_offset=Sketchup.read_default("LSS Zone Defaults","min_wall_offset", 12.0)
				@op_trace_offset=Sketchup.read_default("LSS Zone Defaults","op_trace_offset", 2.0)
				@trace_cont.int_pt_chk_hgt=@int_pt_chk_hgt
				@trace_cont.aperture_size=@aperture_size
				@trace_cont.trace_openings=@trace_openings
				@trace_cont.use_materials=@use_materials
				@trace_cont.min_wall_offset=@min_wall_offset
				@trace_cont.op_trace_offset=@op_trace_offset
				@trace_cont.room_height=@height if @zone_type=="room"
			end
			
			# This method checks if a category name passed as an argument is already present in an active model's
			# dictionary called 'LSS Zone Categories' and returns 'true' if no or 'false' if yes.
			# Usually this method is called after changing 'Category' field in 'LSS Zone' dialog and this
			# method helps to figure out if it is necessary to create new category or not.
			
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
			
			# This method creates new category with a name equals to a passed argument.
			# It also adds new material with the same name as new category name.
			# Method sets the color of new material automatically (it can be adjusted any time
			# later using native SU tools).
			
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
				@zone_dialog.execute_script(js_command) if js_command
				categories=@model.attribute_dictionary("LSS Zone Categories")
				if categories
					categories.each_key{|cat|
						js_command = "get_category('" + cat + "')"
						@zone_dialog.execute_script(js_command) if js_command
					}
					js_command = "re_bind_categories()"
					@zone_dialog.execute_script(js_command) if js_command
				end
			end
			
			# 'LSS Zone' tool activation takes place here:
			# - re-initialize parameters, which have to be fresh each time, when tool becomes active
			# - call web-dialog creation
			# - re-initialize arrays
			
			def activate
				@model=Sketchup.active_model
				@ip = Sketchup::InputPoint.new
				@ip1 = Sketchup::InputPoint.new
				@ip_prev = Sketchup::InputPoint.new
				self.create_web_dial
				
				@selection=@model.selection
				
				@nodal_points=Array.new
				@mid_points=Array.new
				
				# Openings
				@openings_arr=Array.new
				@new_opening=nil
				
				# Drawing helpers
				@const_pts_arr=Array.new
			end
			
			# This method creates new instance of LSS_Zone_Entity class, then passes
			# all necessary parameters using attribute accessors of created instance.
			
			def create_zone_entity
				return if @nodal_points.length<3
				@zone_entity=LSS_Zone_Entity.new
				@zone_entity.nodal_points=@nodal_points
				# Identification
				@zone_entity.number=@number
				@zone_entity.name=@name
				# Geometry
				@zone_entity.area=@area
				@zone_entity.perimeter=@perimeter
				@zone_entity.height=@height
				@zone_entity.volume=@volume
				# Additional
				@zone_entity.floor_level=@floor_level
				@zone_entity.floor_number=@floor_number
				@zone_entity.category=@category
				@zone_entity.memo=@memo
				# Materials
				@zone_entity.floor_material=@floor_material
				@zone_entity.wall_material=@wall_material
				@zone_entity.ceiling_material=@ceiling_material
				
				@zone_entity.floor_refno=@floor_refno
				@zone_entity.wall_refno=@wall_refno
				@zone_entity.ceiling_refno=@ceiling_refno
				# Labels
				@zone_entity.labels_arr=@labels_arr
				# Openings
				@zone_entity.openings_arr=@openings_arr
				
				@zone_entity.zone_type=@zone_type
				@zone_entity.floors_count=@floors_count
				
				# Internal point section (added in ver. 1.2.0 19-Nov-13)
				if @trace_cont or @int_pt_crds
					@zone_entity.int_pt_chk_hgt=@int_pt_chk_hgt
					@zone_entity.aperture_size=@aperture_size
					@zone_entity.trace_openings=@trace_openings
					@zone_entity.use_materials=@use_materials
					if @trace_cont.nil?
						@zone_entity.int_pt_crds=@int_pt_crds
					else
						@zone_entity.int_pt_crds=@trace_cont.int_pt.to_a.join("|")
					end
				end
			end
			
			# This method is a must have for each tool.
			# It helps to avoid graphics clipping while drawing something using tool's #draw method.
			
			def getExtents
				if @nodal_points.length>0
					bb=Sketchup.active_model.bounds
					@nodal_points.each{|pt|
						bb.add(pt)
					}
				end
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
				@category=$lsszoneStrings.GetString("#Default") if @category.nil? or @category=="" # Find out where @category becomes nil and get rid of this line
				self.settings2hash
				@settings_hash.each_key{|key|
					case @settings_hash[key][1]
						when "distance"
							dist_str=Sketchup.format_length(@settings_hash[key][0].to_f).to_s
							setting_pair_str= key.to_s + "|" + dist_str.gsub("'", "*") # Patch to solve js errors problem with feet and inches
						when "area"
							area_str=Sketchup.format_area(@settings_hash[key][0].to_f).to_s
							# Supress square units patch added in ver. 1.1.2 09-Nov-13.
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
							setting_pair_str= key.to_s + "|" + area_str.gsub("'", "*") # Patch to solve js errors problem with feet and inches
						when "volume"
							vol_str=LSS_Math.new.format_volume(@settings_hash[key][0].to_f)
							setting_pair_str= key.to_s + "|" + vol_str
						else
							setting_pair_str= key.to_s + "|" + @settings_hash[key][0].to_s
					end
					js_command = "get_setting('" + setting_pair_str + "')" if setting_pair_str
					@zone_dialog.execute_script(js_command) if js_command
				}
			end
			
			# This method sends material names, which are present in an active model
			# to a web-dialog.
			# It helps to populate material selectors (drop-down lists) with material names in a web-dialog.
			
			def send_materials2dlg
				# Send list of materials from an active model to a web-dialog
				js_command = "clear_mats_arr()"
				@zone_dialog.execute_script(js_command) if js_command
				@materials=@model.materials
				@materials.each{|mat|
					col_obj=mat.color
					col_arr=[col_obj.red, col_obj.green, col_obj.blue]
					col=col_arr.join(",")
					mat_str= mat.name + "|" + col
					js_command = "get_material('" + mat_str + "')"
					@zone_dialog.execute_script(js_command) if js_command
				}
				js_command = "build_mat_list()"
				@zone_dialog.execute_script(js_command) if js_command
			end
			
			# This method sends category names, which are present in a current model to a web-dialog.
			# All categories are stored in an active model's attribute dictionary called 'LSS Zone Categories',
			# since each time, when new category is created its name instantly gets to the mentioned above
			# dictionary.
			# So method iterates through this dictionary and sends its keys to a web-dialog.
			# There is an 'auto-suggest' widget in a dialog, which uses an array of category names
			# for more comfortable filling out of a 'Category' field.
			
			def send_categories2dlg
				# Send list of categories from an active model to a web-dialog
				js_command = "clear_cats_arr()"
				@zone_dialog.execute_script(js_command) if js_command
				categories=@model.attribute_dictionary("LSS Zone Categories")
				if categories
					categories.each_key{|cat|
						js_command = "get_category('" + cat + "')"
						@zone_dialog.execute_script(js_command) if js_command
					}
					js_command = "bind_categories()"
					@zone_dialog.execute_script(js_command) if js_command
				else
					js_command = "get_category('" + @category + "')"
					@zone_dialog.execute_script(js_command) if js_command
					js_command = "bind_categories()"
					@zone_dialog.execute_script(js_command) if js_command
				end
			end
			
			# This method handles mouse moving event, while the tool is active. It has different handling cases depending
			# on tool state:
			# - 'pick_face' looks for face under cursor position and uses it for generating @nodal_points array from its vertices
			# - 'draw_contour' uses input point position to set the last nodal point coordinate of zone's contour, while contour drawing is in progress
			# - 'specify_height' uses z-coordinate of input point position to set zone's height
			# - 'insert_new_node' becomes active after hitting 'Ins' key when cursor is over center of zone's contour segment
			# - 'eye_dropper' looks for a face under cursor and reads its material
			# - 'over_obj' if @drag_state==true moves an object under cursor to a position of an input point
			# (types of draggable object: nodal point, height adjustment point, center of segment)
			# - 'cut_opening' uses input point position to set the last coordinate of an opening's contour
			# - nil state looks at object under cursor in order to find out if it is a zone object or not
			# (for further highlighting zone object under cursor).
			
			def onMouseMove(flags, x, y, view)
				@ip1.pick(view, x, y)
				if( @ip1 != @ip )
					view.invalidate
					@ip.copy!(@ip1)
					view.tooltip = @ip.tooltip
				end
				case @pick_state
					when "pick_face"
						ph=view.pick_helper
						ph.do_pick(x,y)
						under_cur=nil
						ph.all_picked.each_index{|ind|
							ent=ph.leaf_at(ind)
							if ent.is_a?(Sketchup::Face)
								under_cur=ent
								break
							end
						}
						if under_cur
							norm=under_cur.normal
							parent=under_cur.parent
							child=under_cur
							while parent!=@model
								if parent.respond_to?("instances") # Condition added in ver. 1.1.0 24-Oct-13
									inst_arr=parent.instances.select{|ent| parent.entities.include?(child)}
									break if inst_arr[0].nil?
									ind=0
									if inst_arr.length>1
										inst_arr.each_index{|chk_ind|
											inst=inst_arr[chk_ind]
											if inst.bounds.contains?(@ip.position)
												ind=chk_ind
												break
											end
										}
									end
									norm=norm.transform(inst_arr[ind].transformation)
									child=inst_arr[ind]
									parent=inst_arr[ind].parent
								else
									break
								end
							end
							if norm.z.abs>0.1 # Comparison with zero sometimes does not work well because of accuracy
								@face_under_cur=under_cur
								@nodal_points=Array.new
								parent=@face_under_cur.parent
								child=under_cur
								verts=@face_under_cur.outer_loop.vertices
								pt0=verts.first.position
								while parent!=@model
									if parent.respond_to?("instances") # Condition added in ver. 1.1.0 24-Oct-13
										inst_arr=parent.instances.select{|ent| parent.entities.include?(child)}
										break if inst_arr[0].nil?
										ind=0
										if inst_arr.length>1
											inst_arr.each_index{|chk_ind|
												inst=inst_arr[chk_ind]
												if inst.bounds.contains?(@ip.position)
													ind=chk_ind
													break
												end
											}
										end
										pt0=pt0.transform(inst_arr[ind].transformation)
										child=inst_arr[ind]
										parent=inst_arr[ind].parent
									else
										break
									end
								end
								@floor_level=pt0.z
								verts.each{|vrt|
									pt1=vrt.position
									parent=@face_under_cur.parent
									child=under_cur
									while parent!=@model
										if parent.respond_to?("instances") # Condition added in ver. 1.1.0 24-Oct-13
											inst_arr=parent.instances.select{|ent| parent.entities.include?(child)}
											break if inst_arr[0].nil?
											ind=0
											if inst_arr.length>1
												inst_arr.each_index{|chk_ind|
													inst=inst_arr[chk_ind]
													if inst.bounds.contains?(@ip.position)
														ind=chk_ind
														break
													end
												}
											end
											pt1=pt1.transform(inst_arr[ind].transformation)
											child=inst_arr[ind]
											parent=inst_arr[ind].parent
										else
											break
										end
									end
									pt1.z=@floor_level
									@nodal_points<<pt1
								}
								self.refresh_mid_points
								@under_cur_invalid_bnds=nil
							else
								@face_under_cur=nil
								@under_cur_invalid_bnds=nil
								@nodal_points=Array.new
								@mid_points=Array.new
							end
						else
							@face_under_cur=nil
							@under_cur_invalid_bnds=nil
							@nodal_points=Array.new
							@mid_points=Array.new
						end
					when "draw_contour"
						if @nodal_points.length>1
							if @ip_prev.valid?
								@ip.pick(view, x, y, @ip_prev) # It is very important to re-pick @ip again, because it allows inferencing
							else
								@ip.pick(view, x, y)
							end
						end
						pt=@ip.position
						if @nodal_points.length>1
							prev_pt=@nodal_points[@nodal_points.length-2]
							dist=pt.distance(prev_pt)
							Sketchup.vcb_value=Sketchup.format_length(dist)
							pt.z=@floor_level.to_f
						end
						if @nodal_points.length==0
							@nodal_points<<pt
						end
						if @nodal_points.length>1
							ph=view.pick_helper
							pt.z=@floor_level.to_f
							first_pt=@nodal_points.first
							@over_first_pt = ph.test_point(first_pt, x, y)
							self.onSetCursor
						end
						@nodal_points[@nodal_points.length-1]=pt
						self.refresh_mid_points
					# New handler added in ver. 1.2.0 17-Nov-13.
					when "pick_int_pt"
						if @trace_cont
							if @trace_cont.is_tracing==false
								if @trace_cont.is_ready
									@last_state=@pick_state
									@pick_state=nil
									self.onSetCursor
									@ready4apply=true
								else
									@trace_cont.int_pt=@ip.position
									@trace_cont.init_check
								end
							end
						end
					when "specify_height"
						if @ip.position.z>@floor_level.to_f
							@height=@ip.position.z-@floor_level.to_f
						else
							@height=0
						end
						@volume=@area.to_f*@height.to_f
						self.settings2hash
						self.send_settings2dlg
						js_command = "apply_defaults()"
						@zone_dialog.execute_script(js_command)
					when "eye_dropper"
						ph=view.pick_helper
						ph.do_pick(x,y)
						@under_cur_mat=nil
						ph.all_picked.each_index{|ind|
							ent=ph.leaf_at(ind)
							if ent.respond_to?("material")
								@under_cur_mat=ent.material
								break
							end
						}
					when "over_obj"
						if @selected_zone
							if @drag_state
								if @over_pt_ind
									new_pt=@ip.position
									new_pt.z=@floor_level.to_f
									@nodal_points[@over_pt_ind]=new_pt
									self.refresh_mid_points
								end
								if @over_mid_pt_ind
									ind1=@over_mid_pt_ind
									ind2=@over_mid_pt_ind-1
									new_mid_pt=@ip.position
									new_mid_pt.z=@floor_level.to_f
									vec=@clicked_pt.vector_to(new_mid_pt)
									new_pt1=@nodal_points[ind1].offset(vec)
									new_pt2=@nodal_points[ind2].offset(vec)
									new_pt1.z=@floor_level.to_f
									new_pt2.z=@floor_level.to_f
									@nodal_points[ind1]=new_pt1
									@nodal_points[ind2]=new_pt2
									@clicked_pt=Geom::Point3d.new(new_mid_pt)
									self.refresh_mid_points
								end
								if @over_height_adj_pt
									new_pt=@ip.position
									if new_pt.z>@floor_level.to_f
										@height=new_pt.z-@floor_level
									end
								end
							else
								ph=view.pick_helper
								@over_pt_ind=nil
								@over_mid_pt_ind=nil
								@pick_state=nil
								height_adj_pt=Geom::Point3d.new(@nodal_points.first)
								height_adj_pt.z=@floor_level.to_f+@height.to_f
								@over_height_adj_pt=ph.test_point(height_adj_pt, x, y)
								if @over_height_adj_pt
									@pick_state="over_obj"
									self.onSetCursor
								else
									@nodal_points.each_index{|ind|
										pt=@nodal_points[ind]
										over_pt = ph.test_point(pt, x, y)
										mid_pt=@mid_points[ind]
										over_mid_pt = ph.test_point(mid_pt, x, y)
										if over_pt or over_mid_pt
											@over_pt_ind=ind if over_pt
											@over_mid_pt_ind=ind if over_mid_pt
											@pick_state="over_obj"
											self.onSetCursor
											break
										end
									}
								end
							end
						else
							@over_pt_ind=nil
							@over_mid_pt_ind=nil
							@pick_state=nil
							self.onSetCursor
						end
					when "insert_new_node"
						pt=@ip.position
						pt.z=@floor_level.to_f
						@nodal_points[@new_node_ind]=pt
						self.refresh_mid_points
					when "cut_opening"
						new_pt=@ip.position
						if @new_opening.nil?
							@new_opening=Hash.new
							pts=Array.new
							pts<<new_pt
							@new_opening["points"]=pts
							@openings_arr<<@new_opening
						else
							pts=@new_opening["points"]
							if pts.length>1
								if @ip_prev.valid?
									@ip.pick(view, x, y, @ip_prev) # It is very important to pick @ip again, because it allows inferencing
								else
									@ip.pick(view, x, y)
								end
								new_pt=@ip.position # It is necessary to do it again because of inferencing
								prev_pt=pts[pts.length-2]
								dist=new_pt.distance(prev_pt)
								Sketchup.vcb_value=Sketchup.format_length(dist)
							end
							if pts.length>3
								plane=Geom.fit_plane_to_points(pts)
								if plane
									proj_pts=Array.new
									pts.each{|pt|
										proj_pts<<pt.project_to_plane(plane)
									}
									pts=Array.new(proj_pts)
									new_pt=new_pt.project_to_plane(plane)
								end
							end
							if pts.first==new_pt
								if pts.length>2
									@over_first_pt=true
								end
							else
								pts[pts.length-1]=new_pt
								if pts.length>2
									ph=view.pick_helper
									first_pt=pts.first
									@over_first_pt=ph.test_point(first_pt, x, y)
								end
							end
							@new_opening["points"]=pts
							@openings_arr[@openings_arr.length-1]=@new_opening
						end
					else
						ph=view.pick_helper
						@opening_under_cur_ind=nil
						ph.all_picked.each_index{|ind|
							path=ph.path_at(ind)
							path.each{|ent|
								if ent.is_a?(Sketchup::Group)
									op_type=ent.get_attribute("LSS_Zone_Element", "type")
									if op_type
										if op_type.include?("opening")
											bb=ent.bounds
											@openings_arr.each_index{|op_ind|
												op_hash=@openings_arr[op_ind]
												pts=op_hash["points"]
												inside_bb=false
												pts.each{|op_pt|
													if bb.contains?(op_pt)==false
														break
													end
													inside_bb=true
												}
												if inside_bb
													@opening_under_cur_ind=op_ind
													break
												end
											}
											if @opening_under_cur_ind
												break
											end
										end
									end
								end
							}
							break if @opening_under_cur_ind
						}
						if @selected_zone
							height_adj_pt=Geom::Point3d.new(@nodal_points.first)
							height_adj_pt.z=@floor_level.to_f+@height.to_f
							@over_height_adj_pt=ph.test_point(height_adj_pt, x, y)
							if @over_height_adj_pt
								@pick_state="over_obj"
								self.onSetCursor
							else
								@over_pt_ind=nil
								@over_mid_pt_ind=nil
								ind=0; pt=nil; over_pt=nil
								for ind in 0..@nodal_points.length-1
									pt=@nodal_points[ind]
									over_pt = ph.test_point(pt, x, y)
									mid_pt=@mid_points[ind]
									over_mid_pt = ph.test_point(mid_pt, x, y)
									if over_pt or over_mid_pt
										@over_pt_ind=ind if over_pt
										@over_mid_pt_ind=ind if over_mid_pt
										@pick_state="over_obj"
										self.onSetCursor
										break
									end
								end
							end
						end
						if @pick_state!="over_obj"
							ph.do_pick(x,y)
							under_cur=ph.best_picked
							if under_cur
								if under_cur.is_a?(Sketchup::Group)
									number=under_cur.get_attribute("LSS_Zone_Entity", "number")
									if number
										@zone_under_cur=under_cur
									else
										@zone_under_cur=nil
									end
								else
									@zone_under_cur=nil
								end
							else
								@zone_under_cur=nil
							end
						end
				end
			end
			
			# This method calculates positions for points, which represent centers of segments of zone contour
			# using positions of zone contour's nodal points.
			# Method re-initializes array of middle points, then calculates coordinates of each segment center
			# and add a point with calculated coordinates into this array.
			# It is usually called after changes of @nodal_points array, which may take place after dragging a
			# nodal point, or during drawing a new zone's contour etc.
			
			def refresh_mid_points
				@mid_points=Array.new
				x=0; y=0; z=0
				for ind in 0..@nodal_points.length-1
					pt1=@nodal_points[ind]
					pt2=@nodal_points[ind-1]
					x=(pt1.x+pt2.x)/2.0
					y=(pt1.y+pt2.y)/2.0
					z=(pt1.z+pt2.z)/2.0
					mid_pt=Geom::Point3d.new(x, y, z)
					@mid_points<<mid_pt
				end
			end
			
			# This method handles mouse left button down event.
			# It sets @drag_state to true.
			
			def onLButtonDown(flags, x, y, view)
				@drag_state=true
				@clicked_pt=@ip.position
				if @over_mid_pt_ind
					@clicked_pt=Geom::Point3d.new(@mid_points[@over_mid_pt_ind]) if @mid_points[@over_mid_pt_ind]
				end
			end
			
			# This method handles mouse left button up event.
			# It has various handling for each different tool's state:
			# - 'pick_face' chooses clicked face (if any) as a sorce for new zone contour
			# - 'draw_contour' adds new nodal point or finish drawing if position of the first nodal point was clicked
			# - 'specify_height' confirms new height
			# - 'insert_new_node' confirms new inserted node position
			# - 'eye_dropper' picks material of a face under cursor if any
			# - 'over_obj' drops draggable objects
			# (types of draggable objects: nodal point, height adjustment point, center of segment)
			# - 'cut_opening' adds new point to an opening's contour
			# - nil state selects zone under cursor
			# And finally method sets @drag_state to false.
			
			def onLButtonUp(flags, x, y, view)
				ph=view.pick_helper
				ph.do_pick x,y
				case @pick_state
					when "pick_face"
						if @face_under_cur
							@picked_face=@face_under_cur
							self.refresh_mid_points
							if @height.to_f==0
								if @zone_type!="flat"
									@pick_state="specify_height"
								else
									@last_state=@pick_state
									@pick_state=nil
									@ready4apply=true
								end
							else
								@last_state=@pick_state
								@pick_state=nil
								@ready4apply=true
							end
							self.onSetCursor
						else
							@nodal_points=Array.new
							@mid_points=Array.new
						end
					when "draw_contour"
						pt=@nodal_points.last
						if @nodal_points.length>1
							first_pt=@nodal_points.first
							over_first_pt=ph.test_point(first_pt, x, y)
							if over_first_pt
								last_pt=@nodal_points.pop
								@last_state=@pick_state
								@pick_state=nil
								self.onSetCursor
								@ready4apply=true
							else
								@nodal_points<<pt
								self.refresh_mid_points
							end
						else
							@nodal_points<<pt
							@floor_level=pt.z
							self.send_settings2dlg
							self.refresh_mid_points
						end
					# Added in ver. 1.2.0, 13-Nov-13.
					when "pick_int_pt"
						self.create_zone_from_int_pt(@ip.position)
					when "specify_height"
						if @ip.position.z>@floor_level.to_f
							@height=@ip.position.z-@floor_level.to_f
						else
							@height=0
						end
						@last_state="pick_face"
						@pick_state=nil
						self.onSetCursor
					when "eye_dropper"
						if @under_cur_mat
							case @eye_dropper_type
								when "floor"
									@floor_material=@under_cur_mat.name
								when "ceiling"
									@ceiling_material=@under_cur_mat.name
								when "wall"
									@wall_material=@under_cur_mat.name
							end
							@pick_state=nil
							self.onSetCursor
							self.send_settings2dlg
							js_command = "refresh_colors()"
							@zone_dialog.execute_script(js_command) if js_command
							js_command = "unpress_eye_dropper_btn('" + @eye_dropper_type + "')" if @eye_dropper_type
							@zone_dialog.execute_script(js_command) if js_command
						else
							UI.messagebox($lsszoneStrings.GetString("Click on a face to pick its material."))
						end
					when "over_obj"
						if @drag_state
							if @selected_zone
								if @over_pt_ind or @over_mid_pt_ind or @over_height_adj_pt
									if @over_pt_ind
										new_pt=@ip.position
										new_pt.z=@floor_level.to_f
										@nodal_points[@over_pt_ind]=new_pt
									end
									self.refresh_mid_points
									@ip.clear # This is incredibly important statement. If it is missing, then recreation of a zone causes SU crash.
									self.recreate_zone
								end
							end
						end
					when "insert_new_node"
						@pick_state=nil
						self.recreate_zone
					when "cut_opening"
						pts=@new_opening["points"]
						new_pt=pts.last
						if @over_first_pt
							@ip.clear # This is incredibly important statement. If it is missing, then recreation of a zone causes SU crash.
							@last_state=@pick_state
							@pick_state=nil
							self.onSetCursor
							pts=@new_opening["points"]
							pts.pop
							plane=Geom.fit_plane_to_points(pts)
							@new_opening["points"]=pts
							c_pt=@selected_zone.bounds.center
							proj_pt=c_pt.project_to_plane(plane)
							norm=proj_pt.vector_to(c_pt)
							op_type=self.guess_op_type(norm)
							@new_opening["type"]=op_type
							@openings_arr[@openings_arr.length-1]=@new_opening
							self.recreate_zone
							@pick_state=@last_state
							@last_state=nil
							@new_opening=nil
							@over_first_pt=false
						else
							@new_opening["points"]<<new_pt
							@openings_arr[@openings_arr.length-1]=@new_opening
						end
					else
						ph=view.pick_helper
						ph.do_pick(x,y)
						under_cur=ph.best_picked
						if under_cur
							if under_cur.is_a?(Sketchup::Group)
								number=under_cur.get_attribute("LSS_Zone_Entity", "number")
								if number
									@selected_zone=under_cur
									self.read_settings_from_zone
									self.send_settings2dlg
									js_command = "apply_defaults()"
									@zone_dialog.execute_script(js_command)
									js_command = "custom_init()"
									@zone_dialog.execute_script(js_command)
									if @zone_type!="box" and @zone_type!="flat"
										disp=""
										js_command = "opening_cont_display('" + disp + "')"
										@zone_dialog.execute_script(js_command)
									else
										disp="none"
										js_command = "opening_cont_display('" + disp + "')"
										@zone_dialog.execute_script(js_command)
									end
								else
									self.small_reset
									disp="none"
									js_command = "opening_cont_display('" + disp + "')"
									@zone_dialog.execute_script(js_command)
								end
							else
								self.small_reset
								disp="none"
								js_command = "opening_cont_display('" + disp + "')"
								@zone_dialog.execute_script(js_command)
							end
						else
							self.small_reset
							disp="none"
							js_command = "opening_cont_display('" + disp + "')"
							@zone_dialog.execute_script(js_command)
						end
				end
				self.send_settings2dlg
				js_command = "apply_defaults()"
				@zone_dialog.execute_script(js_command)
				@drag_state=false
				@ip_prev.copy!(@ip)
			end
			
			# This method makes zone contour from a boundary of objects, which surround a given point in an active model.
			# Added in ver. 1.2.0 17-Nov-13.
			
			def create_zone_from_int_pt(int_pt)
				@floor_level=int_pt.z
				@trace_cont.int_pt=int_pt
				@trace_cont.init_check
				@trace_cont.aperture_pts=@aperture_pts
				@trace_cont.trace
				if @trace_cont.use_materials
					@floor_material=@picked_floor_mat
					@wall_material=@picked_wall_mat
					self.send_settings2dlg
					js_command = "refresh_colors()"
					@zone_dialog.execute_script(js_command) if js_command
				end
			end
			
			# This method resets tool's parameters without resetting zone settings.
			
			def small_reset
				@selected_zone=nil
				@labels_arr=nil
				disp="none"
				js_command = "opening_cont_display('" + disp + "')"
				@zone_dialog.execute_script(js_command)
				@nodal_points=Array.new
				@mid_points=Array.new
				@openings_arr=Array.new
				@zone_under_cur=nil
				@opening_under_cur_ind=nil
				@over_pt_ind=nil
				@over_mid_pt_ind=nil
				@drag_state=false
				@over_first_pt=false
				@over_height_adj_pt=false
				@new_opening=nil
				# Clear from construction points
				if @const_pts_arr.length>0
					@model.entities.erase_entities(@const_pts_arr)
					@const_pts_arr=Array.new
				end
				@trace_cont=nil
				# Tracing settings
				@int_pt_chk_hgt=Sketchup.read_default("LSS Zone Defaults", "int_pt_chk_hgt", 100.0)
				@aperture_size=Sketchup.read_default("LSS Zone Defaults", "aperture_size", 4.0)
				@trace_openings=Sketchup.read_default("LSS Zone Defaults", "trace_openings", "true")
				@use_materials=Sketchup.read_default("LSS Zone Defaults", "use_materials", "true")
				
				@picked_floor_mat=nil
				@picked_wall_mat=nil
			end
			
			# This method erases selected zone (selected by LSS Zone tool, not by native SU selection tool),
			# then calls #create_zone_entity in order to create new instance of LSS_Zone_Entity class,
			# then actually create new zone object and send parameters of newly created zone to a dialog.
			# This method is called for example after dragging a nodal point of selected zone's contour, because it is
			# necessary to recreate a zone with new contour or after changing any setting of selected zone
			# in a dialog.
			
			def recreate_zone
				@model.start_operation($lsszoneStrings.GetString("Recreate Zone"), true)
					
					# Read custom attributes attached to a zone if any and store to a dicts_hash. Added in ver. 1.1.2 11-Nov-13.
					attr_dicts=@selected_zone.attribute_dictionaries
					dicts_hash=Hash.new
					attr_dicts.each{|dict|
						setting_hash=Hash.new
						dict.each_key{|key|
							val=dict[key]
							setting_hash[key]=val
						}
						dicts_hash[dict.name]=setting_hash
					}
					
					# Read information about internal point (added in ver. 1.2.0 19-Nov-13)
					@int_pt_crds=""
					comp_inst_arr=@selected_zone.entities.to_a.select{|ent| (ent.is_a?(Sketchup::ComponentInstance))}
					if comp_inst_arr.length>0
						int_pt_inst=comp_inst_arr.select{|ent| (ent.definition.name=="lss_zone_int_pt")}[0]
						if int_pt_inst
							pos=int_pt_inst.bounds.min.transform(@selected_zone.transformation)
							@int_pt_crds=pos.to_a.join("|")
							@int_pt_chk_hgt=@selected_zone.get_attribute("LSS_Zone_Entity", "int_pt_chk_hgt")
							@aperture_size=@selected_zone.get_attribute("LSS_Zone_Entity", "aperture_size")
							@trace_openings=@selected_zone.get_attribute("LSS_Zone_Entity", "trace_openings")
							@use_materials=@selected_zone.get_attribute("LSS_Zone_Entity", "use_materials")
							# Read default in case if @zone_grop does not have corresponding attributes
							@int_pt_chk_hgt=Sketchup.read_default("LSS Zone Defaults", "int_pt_chk_hgt", 100.0) if @int_pt_chk_hgt.nil?
							@aperture_size=Sketchup.read_default("LSS Zone Defaults", "aperture_size", 100.0) if @aperture_size.nil?
							@trace_openings=Sketchup.read_default("LSS Zone Defaults", "trace_openings", 100.0) if @trace_openings.nil?
							@use_materials=Sketchup.read_default("LSS Zone Defaults", "use_materials", 100.0) if @use_materials.nil?
						end
					end
					
					@selected_zone.erase!
					@selected_zone=nil
					@zone_under_cur=nil
					@opening_under_cur_ind=nil
					@over_pt_ind=nil
					@over_mid_pt_ind=nil
					@drag_state=false
					self.create_zone_entity
					# If the optional parameter==false, then "create_zone" method does not perform @model.start_operation
					@zone_entity.create_zone(false)
					
					new_zone_group=@zone_entity.zone_group
					
					# Attach back custom attributes to a new_zone_group. Added in ver. 1.1.2 11-Nov-13.
					dicts_hash.each_key{|dict_name|
						if new_zone_group.attribute_dictionaries[dict_name]
							dict_hash=dicts_hash[dict_name]
							dict_hash.each_key{|key|
								chk_val=new_zone_group.get_attribute(dict_name, key)
								if chk_val.nil?
									val=dict_hash[key]
									new_zone_group.set_attribute(dict_name, key, val)
								end
							}
						else
							dict_hash=dicts_hash[dict_name]
							dict_hash.each_key{|key|
								val=dict_hash[key]
								new_zone_group.set_attribute(dict_name, key, val)
							}
						end
					}
					
					@selected_zone=new_zone_group
					self.read_settings_from_zone
					self.send_settings2dlg
					@pick_state=nil
				@model.commit_operation
			end
			
			# This method reads attributes from selected zone (selected by LSS Zone tool, not by native SU selection tool).
			# It also reads information about openings and attached labels.
			
			def read_settings_from_zone
				@number=@selected_zone.get_attribute("LSS_Zone_Entity", "number")
				@name=@selected_zone.get_attribute("LSS_Zone_Entity", "name")
				@area=@selected_zone.get_attribute("LSS_Zone_Entity", "area")
				@perimeter=@selected_zone.get_attribute("LSS_Zone_Entity", "perimeter")
				@height=@selected_zone.get_attribute("LSS_Zone_Entity", "height")
				@volume=@selected_zone.get_attribute("LSS_Zone_Entity", "volume")
				@floor_level=@selected_zone.get_attribute("LSS_Zone_Entity", "floor_level")
				@floor_number=@selected_zone.get_attribute("LSS_Zone_Entity", "floor_number")
				@category=@selected_zone.get_attribute("LSS_Zone_Entity", "category")
				@memo=@selected_zone.get_attribute("LSS_Zone_Entity", "memo")
				@walls_area=@selected_zone.get_attribute("LSS_Zone_Entity", "walls_area")
				@floor_material=@selected_zone.get_attribute("LSS_Zone_Entity", "floor_material")
				@ceiling_material=@selected_zone.get_attribute("LSS_Zone_Entity", "ceiling_material")
				@wall_material=@selected_zone.get_attribute("LSS_Zone_Entity", "wall_material")
				
				@zone_type=@selected_zone.get_attribute("LSS_Zone_Entity", "zone_type")
				@floors_count=@selected_zone.get_attribute("LSS_Zone_Entity", "floors_count")
				
				area_face_grp=@selected_zone.entities.select{|grp| (grp.get_attribute("LSS_Zone_Element", "type")=="area")}[0]
				if area_face_grp
					area_face=area_face_grp.entities.select{|ent| (ent.get_attribute("LSS_Zone_Element", "type")=="area")}[0]
					if area_face
						@nodal_points=Array.new
						@mid_points=Array.new
						verts=area_face.outer_loop.vertices
						verts.each{|vrt|
							@nodal_points<<vrt.position.transform(@selected_zone.transformation)
						}
						self.refresh_mid_points
					end
				end
				
				# Read openings
				@openings_arr=Array.new
				ops_groups_arr=Array.new
				@selected_zone.entities.each{|grp|
					op_type=grp.get_attribute("LSS_Zone_Element", "type")
					if op_type
						if op_type.include?("opening")
							ops_groups_arr<<grp
						end
					end
				}
				
				ops_groups_arr.each{|op_grp|
					op_type=op_grp.get_attribute("LSS_Zone_Element", "type")
					op_face=op_grp.entities.select{|ent| (ent.is_a?(Sketchup::Face))}[0]
					if op_face
						op_pts=Array.new
						op_verts=op_face.outer_loop.vertices
						op_verts.each{|vrt|
							op_pts<<vrt.position.transform(op_grp.transformation).transform(@selected_zone.transformation)
						}
						op_hash=Hash.new
						op_hash["type"]=op_type
						op_hash["points"]=op_pts
						@openings_arr<<op_hash
					end
				}
				
				# Labels
				@labels_arr=Array.new
				zone_attr_dicts=@selected_zone.attribute_dictionaries
				zone_attr_dicts.each{|dict|
					if dict.name.split(":")[0]=="zone_label"
						preset_name=dict["preset_name"]
						label_template=dict["label_template"]
						label_layer=dict["label_layer"]
						@labels_arr<<[preset_name, label_template, label_layer]
					end
				}
			end
			
			# This method draws preview of a zone and some accessory graphics, such as:
			# - color material sample, when 'eye_dropper' tool state is active
			# - opening plane, when 'cut_opening' tool state is active
			# - bounds of a zone under cursor, when tool state is nil
			# and so on.
			
			def draw(view)
				if @ip.valid?
					@ip.draw(view)
				end
				if @nodal_points.length>0
					@floor_pts2d=Array.new
					@ceiling_pts2d=Array.new
					@nodal_points.each{|pt|
						@floor_pts2d<<view.screen_coords(pt)
						ceiling_pt=Geom::Point3d.new(pt.x, pt.y, @floor_level.to_f+@height.to_f)
						@ceiling_pts2d<<view.screen_coords(ceiling_pt)
					}
					@floor_pts2d<<@floor_pts2d.first
					@ceiling_pts2d<<@ceiling_pts2d.first
				end
				self.draw_contour(view)
				self.draw_vert_lines(view)
				self.draw_ceiling(view)
				self.draw_picked_face_verts(view) if @pick_state=="pick_face"
				if @pick_state=="draw_contour"
					self.draw_nodal_points(view)
					self.draw_proj_line(view)
				end
				if @pick_state=="eye_dropper"
					self.draw_mat_color_sample(view)
				end
				if @zone_under_cur and @selected_zone!=@zone_under_cur
					self.draw_zone_under_cur(view)
				end
				if @selected_zone
					if not(@selected_zone.deleted?)
						self.draw_nodal_points(view)
						self.draw_mid_points(view)
						if @over_pt_ind
							view.line_width=1
							if @drag_state
								pt_size=8; pt_type=2; pt_col="red"
							else
								pt_size=8; pt_type=2; pt_col="silver"
							end
							view.draw_points(@nodal_points[@over_pt_ind], pt_size, pt_type, pt_col)
							pt_size=8; pt_type=1; pt_col="black"
							view.draw_points(@nodal_points[@over_pt_ind], pt_size, pt_type, pt_col)
							view.line_width=1
						end
						if @over_mid_pt_ind
							view.line_width=1
							if @drag_state
								pt_size=8; pt_type=7; pt_col="red"
							else
								pt_size=8; pt_type=7; pt_col="silver"
							end
							view.draw_points(@mid_points[@over_mid_pt_ind], pt_size, pt_type, pt_col)
							pt_size=8; pt_type=6; pt_col="black"
							view.draw_points(@mid_points[@over_mid_pt_ind], pt_size, pt_type, pt_col)
							view.line_width=1
						end
						height_adj_pt=Geom::Point3d.new(@nodal_points.first)
						height_adj_pt.z=@floor_level.to_f+@height.to_f
						pt1=view.screen_coords(@nodal_points.first)
						pt2=view.screen_coords(height_adj_pt)
						view.line_width=3
						view.drawing_color="red"
						view.line_stipple="-"
						view.draw2d(GL_LINES, [pt1, pt2])
						view.line_width=1
						view.drawing_color="black"
						view.line_stipple=""
						if @over_height_adj_pt
							heigth_txt=Sketchup.format_length(@height.to_f).to_s
							txt_pt=pt2+[20, 20]
							status = view.draw_text(txt_pt, heigth_txt)
							status = view.draw_text(txt_pt, heigth_txt)
							view.line_width=1
							if @drag_state
								pt_size=8; pt_type=2; pt_col="red"
							else
								pt_size=8; pt_type=2; pt_col="silver"
							end
							view.draw_points(height_adj_pt, pt_size, pt_type, pt_col)
							pt_size=8; pt_type=1; pt_col="black"
							view.draw_points(height_adj_pt, pt_size, pt_type, pt_col)
							view.line_width=1
						else
							pt_size=8; pt_type=1; pt_col="black"
							view.draw_points(height_adj_pt, pt_size, pt_type, pt_col)
							view.line_width=1
						end
						self.draw_openings(view)
					end
				end
				if @opening_under_cur_ind
					op_hash=@openings_arr[@opening_under_cur_ind]
					pts=op_hash["points"]
					pts2d=Array.new
					pts.each{|pt|
						pts2d<<view.screen_coords(pt)
					}
					pts2d<<view.screen_coords(pts.first)
					view.line_width=4
					view.drawing_color="red"
					view.draw2d(GL_LINE_STRIP, pts2d)
					view.line_width=1
					view.drawing_color="black"
				end
				if @trace_cont
					if @trace_cont.openings_arr
						if @trace_cont.openings_arr.length>0
							self.draw_openings(view)
						end
					end
				end
				if @pick_state=="pick_int_pt"
					self.draw_pick_int_pt(view)
				end
			end
			
			def draw_pick_int_pt(view)
				return if @trace_cont.nil?
				@nodal_points=@trace_cont.nodal_points
				@openings_arr=@trace_cont.openings_arr
				if @trace_cont.is_tracing
					view.line_width=1
				else
					view.line_width=2
				end
				init_pt=@trace_cont.init_pt
				return if init_pt.nil?
				chk_pt=@trace_cont.chk_pt
				int_pt=@trace_cont.int_pt
				view.line_stipple="."
				view.drawing_color="black"
				view.draw_line(int_pt, chk_pt)
				view.draw_line(chk_pt, init_pt)
				view.line_stipple=""
				pt_size=6; pt_type=1; pt_col="black"
				view.draw_points(chk_pt, pt_size, pt_type, pt_col)
				pt_size=6; pt_type=1; pt_col="red"
				view.draw_points(init_pt, pt_size, pt_type, pt_col)
				aperture_pts=@trace_cont.aperture_pts
				return if aperture_pts.nil?
				return if aperture_pts.length==0
				if @trace_cont.use_materials=="true"
					self.draw_floor_wall_mats(int_pt, init_pt, view)
				end
				ap_pts2d=Array.new
				aperture_pts.each{|pt|
					ap_pts2d<<view.screen_coords(pt)
					# view.draw_text(view.screen_coords(pt), aperture_pts.index(pt).to_s)
				}
				ap_pts2d<<view.screen_coords(aperture_pts.first)
				view.line_width=1
				view.drawing_color="black"
				view.draw2d(GL_LINE_STRIP, ap_pts2d)
			end
			
			def draw_floor_wall_mats(floor_pt, wall_pt, view)
				view.line_width=1
				floor_tr=Geom::Transformation.new(floor_pt)
				wall_norm=@trace_cont.norm
				if wall_norm
					wall_pos_tr=Geom::Transformation.new(wall_pt)
					wall_norm_tr=Geom::Transformation.new(Geom::Point3d.new(0,0,0), wall_norm)
					wall_mat=@trace_cont.wall_mat
				end
				floor_pts=Array.new
				wall_pts=Array.new
				@square_pts.each{|pt|
					floor_pts<<view.screen_coords(pt.transform(floor_tr))
					wall_pts<<view.screen_coords(pt.transform(wall_norm_tr).transform(wall_pos_tr)) if wall_norm
				}
				ph=view.pick_helper
				floor_xy=view.screen_coords(floor_pt)
				ph.do_pick(floor_xy.x,floor_xy.y)
				floor_mat=nil
				ph.all_picked.each_index{|ind|
					ent=ph.leaf_at(ind)
					if ent.respond_to?("material")
						floor_mat=ent.material
						break
					end
				}
				if floor_mat
					col=floor_mat.color
					view.drawing_color=col
					view.draw2d(GL_QUADS, floor_pts)
				end
				floor_pts<<floor_pts.first
				view.drawing_color="black"
				view.draw2d(GL_LINE_STRIP, floor_pts)
				if wall_norm
					if wall_mat
						col=wall_mat.color
						view.drawing_color=col
						view.draw2d(GL_QUADS, wall_pts)
					end
					wall_pts<<wall_pts.first
					view.drawing_color="black"
					view.draw2d(GL_LINE_STRIP, wall_pts)
				end
				@picked_floor_mat=floor_mat.name if floor_mat
				@picked_wall_mat=wall_mat.name if wall_mat and wall_norm
			end
			
			# This method draws contours of zone's openings and shows plane of new opening, which is cut at the moment. 
			
			def draw_openings(view)
				openings2d=Array.new
				@openings_arr.each_index{|ind|
					opening=@openings_arr[ind]
					if opening
						pts=opening["points"]
						pts2d=Array.new
						pts.each{|pt|
							pts2d<<view.screen_coords(pt)
						}
						if ind!=@openings_arr.length-1 or @pick_state!="cut_opening" or @new_opening.nil?
							pts2d<<view.screen_coords(pts.first)
						end
						openings2d<<pts2d
					end
				}
				if openings2d.length>0
					view.line_width=6
					view.drawing_color="black"
					openings2d.each_index{|ind|
						pts2d=openings2d[ind]
						if ind==openings2d.length-1 and @pick_state=="cut_opening" and @new_opening
							view.drawing_color="red"
							if @over_first_pt==false
								view.line_stipple="-"
							end
						end
						view.draw2d(GL_LINE_STRIP, pts2d) if pts2d.length>1
					}
					view.line_width=1
					view.drawing_color="black"
					view.line_stipple=""
				end
				# Draw opening plane
				if @pick_state=="cut_opening"
					if @new_opening
						pts=@new_opening["points"]
						bb=Geom::BoundingBox.new
						bb.add(pts)
						if pts.length>2
							plane=Geom.fit_plane_to_points(pts)
							if plane
								min_pt=bb.min
								max_pt=bb.max
								pt1=view.screen_coords(bb.corner(0).project_to_plane(plane))
								pt2=view.screen_coords(bb.corner(3).project_to_plane(plane))
								pt3=view.screen_coords(bb.corner(7).project_to_plane(plane))
								pt4=view.screen_coords(bb.corner(4).project_to_plane(plane))
								if min_pt.x==max_pt.x
									pt1=view.screen_coords(bb.corner(0).project_to_plane(plane))
									pt2=view.screen_coords(bb.corner(2).project_to_plane(plane))
									pt3=view.screen_coords(bb.corner(6).project_to_plane(plane))
									pt4=view.screen_coords(bb.corner(4).project_to_plane(plane))
								end
								if min_pt.y==max_pt.y
									pt1=view.screen_coords(bb.corner(0).project_to_plane(plane))
									pt2=view.screen_coords(bb.corner(1).project_to_plane(plane))
									pt3=view.screen_coords(bb.corner(5).project_to_plane(plane))
									pt4=view.screen_coords(bb.corner(4).project_to_plane(plane))
								end
								if min_pt.z==max_pt.z
									pt1=view.screen_coords(bb.corner(0).project_to_plane(plane))
									pt2=view.screen_coords(bb.corner(1).project_to_plane(plane))
									pt3=view.screen_coords(bb.corner(3).project_to_plane(plane))
									pt4=view.screen_coords(bb.corner(2).project_to_plane(plane))
								end
								col=Sketchup::Color.new("silver")
								col.alpha=0.5
								view.drawing_color=col
								view.draw2d(GL_QUADS, [pt1, pt2, pt3, pt4])
								col=Sketchup::Color.new(150, 150, 150)
								view.drawing_color=col
								view.line_stipple=""
								view.draw2d(GL_LINE_STRIP, [pt1, pt2, pt3, pt4, pt1])
								c_pt=@selected_zone.bounds.center
								proj_pt=c_pt.project_to_plane(plane)
								norm=proj_pt.vector_to(c_pt)
								op_type=self.guess_op_type(norm)
								txt_pt=pt1+[10, -10]
								status = view.draw_text(txt_pt, op_type)
								status = view.draw_text(txt_pt, op_type)
								# Draw cross
								mid_pt1=Geom::Point3d.new((pt1.x+pt2.x)/2.0, (pt1.y+pt2.y)/2.0)
								mid_pt2=Geom::Point3d.new((pt2.x+pt3.x)/2.0, (pt2.y+pt3.y)/2.0)
								mid_pt3=Geom::Point3d.new((pt3.x+pt4.x)/2.0, (pt3.y+pt4.y)/2.0)
								mid_pt4=Geom::Point3d.new((pt4.x+pt1.x)/2.0, (pt4.y+pt1.y)/2.0)
								view.draw2d(GL_LINES, [mid_pt1, mid_pt3, mid_pt2, mid_pt4])
							end
						end
					end
				end
			end
			
			# This method tries to figure out type of an opening depends on its normal vector direction.
			# Types are:
			# - wall opening
			# - floor opening
			# - ceiling opening
			
			def guess_op_type(norm)
				if norm.length>0
					z_vec=Geom::Vector3d.new(0, 0, 1)
					ang=norm.angle_between(z_vec)
					if ang>(135.0*Math::PI/180.0)
						op_type="ceiling_opening"
					end
					if ang<(45.0*Math::PI/180.0)
						op_type="floor_opening"
					end
					if ang<=(135.0*Math::PI/180.0) and ang>=(45.0*Math::PI/180.0)
						op_type="wall_opening"
					end
				else
					op_type="wall_opening"
				end
				if op_type.nil?
					op_type="wall_opening"
				end
				op_type
			end
			
			# This method shows geometry summary of a zone while tool is active.
			
			def draw_geom_summary(view)
				summary_text=""
				summary_text+="#{@number} #{@name}\n"
				summary_text+=$lsszoneStrings.GetString("Area: ")
				summary_text+=Sketchup.format_area(@area.to_f)
				summary_text+="\n"
				summary_text+=$lsszoneStrings.GetString("Perimeter: ")
				summary_text+=Sketchup.format_length(@perimeter.to_f)
				summary_text+="\n"
				summary_text+=$lsszoneStrings.GetString("Height: ")
				summary_text+=Sketchup.format_length(@height.to_f)
				summary_text+="\n"
				summary_text+=$lsszoneStrings.GetString("Volume: ")
				summary_text+=LSS_Math.new.format_volume(@volume.to_f)
				bb=Geom::BoundingBox.new
				@nodal_points.each{|pt|
					ceiling_pt=Geom::Point3d.new(pt.x, pt.y, @floor_level.to_f+@height.to_f)
					bb.add(ceiling_pt)
				}
				txt_pt=view.screen_coords(bb.max)
				status = view.draw_text(txt_pt, summary_text)
				status = view.draw_text(txt_pt, summary_text)
			end
			
			# This method draws points at the centers of segments of zone's contour.
			
			def draw_mid_points(view)
				return if @mid_points.length<1
				view.line_width=1
				view.draw_points(@mid_points, 8, 6, "black")
			end
			
			# This method draws small square near cursor position, which has the same color as a material of
			# a face under cursor position. #draw method calls this method, when 'eye_dropper' tool state
			# is active.
			
			def draw_mat_color_sample(view)
				pt1=view.screen_coords(@ip.position) + [24, 0]
				pt2=pt1+[24, 0]
				pt3=pt1+[24, -24]
				pt4=pt1+[0, -24]
				if @under_cur_mat
					col=@under_cur_mat.color
					view.drawing_color=col
					view.draw2d(GL_QUADS, [pt1, pt2, pt3, pt4])
				end
				view.drawing_color="black"
				view.draw2d(GL_LINE_STRIP, [pt1, pt2, pt3, pt4, pt1])
			end
			
			# This method draws a contour of a zone.
			# It also performs calculation of zone's geometry summary (area, perimeter, volume)
			# and sends calculated values to 'LSS Zone' dialog.
			# Calculation takes place when @show_geom_summary==true.
			# The point is that calculation slows down drawing process so it is possible to turn it off
			# in order to make drawing process more smooth, but geometry summary won't be updated instantly
			# while drawing in that case.
			
			def draw_contour(view)
				return if @nodal_points.length<2
				@nodal_points1=Array.new if @nodal_points1.nil?
				len=0; pt1=nil; pt2=nil
				for ind in 0..@nodal_points.length-1
					pt1=@nodal_points[ind]
					pt2=@nodal_points[ind-1]
					len+=pt1.distance(pt2)
				end
				@perimeter=len
				view.drawing_color="red"
				view.line_width=3
				view.draw2d(GL_LINE_STRIP, @floor_pts2d)
				@triangles=nil; tri_took_place=false
				is_tracing=false
				if @trace_cont
					is_tracing=true if @trace_cont.is_tracing
				end
				if (@nodal_points!=@nodal_points1 and @show_geom_summary and @over_first_pt==false and @nodal_points.length>2 and is_tracing==false) or @pick_state=="pick_face"
					tri_took_place=true
					@triangles=LSS_Geom.new.triangulate_poly(@nodal_points)
					@nodal_points1=Array.new(@nodal_points)
					if @triangles
						if @triangles.length>0
							tot_area=0
							@triangles2d=Array.new
							@triangles.each{|tri|
								tri.each{|pt|
									@triangles2d<<view.screen_coords(pt)
								}
								tot_area+=LSS_Geom.new.calc_triangle_area(tri[0], tri[1], tri[2])
							}
							@area=tot_area
							@volume=@area*@height.to_f
							self.settings2hash
							self.send_settings2dlg
							js_command = "apply_defaults()"
							@zone_dialog.execute_script(js_command)
							self.draw_geom_summary(view) if @show_geom_summary
						end
					end
				end
				if @triangles
					if @triangles.length>0
						@triangles2d=Array.new
						@triangles.each{|tri|
							tri.each{|pt|
								@triangles2d<<view.screen_coords(pt)
							}
						}
						zone_col="white"
						if @category
							materials=@model.materials
							cat_mat=materials[@category]
							if cat_mat
								zone_col=cat_mat.color
								zone_col.alpha=cat_mat.alpha
							end
						end
						view.drawing_color=zone_col
						view.draw2d(GL_TRIANGLES, @triangles2d)
						view.line_width=1
						view.drawing_color="silver"
						view.line_stipple="."
						view.draw2d(GL_LINE_STRIP, @triangles2d)
						view.line_stipple=""
					end
				else
					if tri_took_place
						warning_text=$lsszoneStrings.GetString("Contour intersection(s) detected.")
						txt_pt=view.screen_coords(@ip.position)
						txt_pt=[txt_pt.x+32, txt_pt.y]
						status = view.draw_text(txt_pt, warning_text)
						status = view.draw_text(txt_pt, warning_text)
					end
				end
			end
			
			# This method draws vertical lines, which represent zone's corner edges.
			
			def draw_vert_lines(view)
				return if @nodal_points.length<2 or @height.to_f==0
				view.drawing_color="DarkGray"
				view.line_width=1
				@floor_pts2d.each_index{|ind|
					floor_pt=@floor_pts2d[ind]
					ceiling_pt=@ceiling_pts2d[ind]
					view.draw2d(GL_LINES, [floor_pt, ceiling_pt])
				}
			end
			
			# This method draws contour of zone's ceiling.
			
			def draw_ceiling(view)
				return if @nodal_points.length<2 or @height.to_f==0
				view.drawing_color="black"
				view.line_width=3
				view.draw2d(GL_LINE_STRIP, @ceiling_pts2d)
			end
			
			def draw_picked_face_verts(view)
				return if @nodal_points.length<1
				view.line_width=1
				view.draw_points(@nodal_points, 6, 2, "black")
			end
			
			# This method draws nodal points of zone's contour.
			# It highlights nodal point, when cursor is over it as well.
			
			def draw_nodal_points(view)
				return if @nodal_points.length<1
				view.line_width=1
				case @pick_state
					when nil
						view.draw_points(@nodal_points, 8, 1, "black")
					when "over_obj"
						view.draw_points(@nodal_points, 8, 1, "black")
					when "draw_contour"
						if @over_first_pt
							view.line_width=1
							view.draw_points(@nodal_points, 8, 3, "silver")
							close_contour_str=$lsszoneStrings.GetString("Finish drawing")
							view.tooltip=close_contour_str # Does not work...
						else
							view.line_width=2
							view.draw_points(@nodal_points, 8, 3, "black")
						end
						# Emphasize first nodal point
						view.draw_points(@nodal_points.first, 10, 1, "black")
						view.line_width=1
				end
			end
			
			# This method draws a line between input point position and a current nodal point of a zone contour.
			# The point is that all nodal points have the same z-coordinate obviously (which equals to @floor_level)
			# and each new nodal point is forced to have it too, but z-coordinate of input point position may differ from
			# @floor_level. So this 'project line' is kind of a visual helper, which helps to figure out positions of 
			# new nodal point and current input point.
			
			def draw_proj_line(view)
				return if @nodal_points.last.nil?
				return if @nodal_points.last==@ip.position
				pt1=view.screen_coords(@nodal_points.last)
				pt2=view.screen_coords(@ip.position)
				view.line_stipple="."
				view.drawing_color="black"
				view.draw2d(GL_LINES, [pt1, pt2])
				view.draw_points(@ip.position, 4, 7, "black")
			end
			
			# This method highlights corners of a bounding box of a zone under cursor,
			# while tool state is nil.
			
			def draw_zone_under_cur(view)
				return if @zone_under_cur.deleted?
				bnds=@zone_under_cur.bounds
				self.draw_bounds(view, bnds, 6, 1, "green", 2)
			end
			
			# This method draws points of a bounding box passed as an argument.
			
			def draw_bounds(view, bnds, pt_size, pt_type, pt_col, line_wdt)
				# pt_type 1 = open square, 2 = filled square, 3 = "+", 4 = "X", 5 = "*", 6 = open triangle, 7 = filled triangle.
				pts=Array.new
				for i in 0..7
					pt=bnds.corner(i)
					pts<<pt
				end
				view.line_width = line_wdt
				view.draw_points(pts, pt_size, pt_type, pt_col)
			end
			
			# This method resets 'LSS Zone' tool.
			# It performs #small_reset, which resets only tool's parameters (without affecting zone's settings),
			# then it calls #read_defaults, which finally resets zone's settings to default values.
			
			def reset(view)
				@ip.clear
				@ip1.clear
				if( view )
					view.tooltip = nil
					view.invalidate
				end
				
				self.small_reset
				@pick_state=nil
				
				self.read_defaults
				self.send_settings2dlg
			end
			
			# This method is called in case of 'LSS Zone' tool deactivation.

			def deactivate(view)
				@zone_dialog.close
				self.reset(view)
			end
			
			# This method increments zone number.
			
			def increment_number
				if @number.to_i>0
					new_number=(@number.to_i+1).to_s
					new_len=new_number.length
					len=@number.to_s.length
					d_l=len-new_len
					if d_l>0
						@number="0"*d_l+new_number
					else
						@number=new_number
					end
					self.settings2hash
					self.send_settings2dlg
					js_command = "apply_defaults()"
					@zone_dialog.execute_script(js_command)
				end
			end
			
			# This method enables value box of SU.
			
			def enableVCB?
				return true
			end
			
			# This method processes values entered by user into a value box, while tool is active.
			# Two tool states uses parsed value of a value box:
			# - 'draw_contour' tool state
			# - 'cut_opening' tool state
			# It is possible to enter the exact distance for the next nodal point of a zone contour while its drawing or
			# for the next point of an opening being cut at the moment.
			
			def onUserText(text, view)
				case @pick_state
					when "draw_contour"
						if @nodal_points.length>1
							len=nil
							len=Sketchup.parse_length(text)
							if len
								if len>0
									prev_pt=@nodal_points[@nodal_points.length-2]
									curr_pt=@nodal_points[@nodal_points.length-1]
									vec=prev_pt.vector_to(curr_pt)
									vec.length=len
									new_pt=prev_pt.offset(vec)
									new_pt.z=@floor_level.to_f
									@nodal_points.pop
									@nodal_points<<new_pt
									curr_pt=@ip.position
									curr_pt.z=@floor_level.to_f
									@nodal_points<<curr_pt
									self.refresh_mid_points
									view.invalidate
									const_pt=@model.entities.add_cpoint(new_pt)
									@const_pts_arr<<const_pt
									scr_pt=view.screen_coords(new_pt)
									@ip_prev.pick(view,scr_pt.x, scr_pt.y)
								end
							end
						end
					when "cut_opening"
						if @new_opening
							pts=@new_opening["points"]
							if pts.length>1
								len=nil
								len=Sketchup.parse_length(text)
								if len # Condition added in ver. 1.2.0 19-Nov-13
									if len>0 # Condition added in ver. 1.2.0 19-Nov-13
										prev_pt=pts[pts.length-2]
										curr_pt=pts[pts.length-1]
										vec=prev_pt.vector_to(curr_pt)
										vec.length=len
										new_pt=prev_pt.offset(vec)
										pts.pop
										pts<<new_pt
										pts<<curr_pt
										@new_opening["points"]=pts
										@openings_arr[@openings_arr.length-1]=@new_opening
										view.invalidate
										const_pt=@model.entities.add_cpoint(new_pt)
										@const_pts_arr<<const_pt
										scr_pt=view.screen_coords(new_pt)
										@ip_prev.pick(view,scr_pt.x, scr_pt.y)
									end
								end
							end
						end
					when "pick_int_pt"
						if @trace_cont
							if @trace_cont.is_tracing
								@trace_cont.stop_tracing
							end
							hgt=Sketchup.parse_length(text)
							if hgt
								@int_pt_chk_hgt=hgt
							end
							@trace_cont=LSS_Zone_Trace_Cont.new
							@nodal_points=Array.new
							@trace_cont.int_pt_chk_hgt=@int_pt_chk_hgt
							@trace_cont.int_pt=@ip.position
							@trace_cont.init_check
							view.invalidate
						end
					else
					# Default pick state handling
				end
			end
			
			# Handle pressed key while tool is active.
			# Enable inference lock by Shift key pressing.
			
			def onKeyDown(key, repeat, flags, view)
				if key==VK_SHIFT
					case @pick_state
						when "draw_contour"
						if @nodal_points.length>1
							if @ip_prev.valid?
								if @ip_prev.degrees_of_freedom==1
									view.lock_inference(@ip)
								else
									view.lock_inference(@ip_prev, @ip)
								end
								@ip_prev.draw(view)
								@ip.draw(view)
							end
						end
						when "cut_opening"
						pts=@new_opening["points"]
						if pts.length>1
							if @ip_prev.valid?
								if @ip_prev.degrees_of_freedom==1
									view.lock_inference(@ip)
								else
									view.lock_inference(@ip_prev, @ip)
								end
								@ip_prev.draw(view)
								@ip.draw(view)
							end
						end
					end
				end
			end
			
			# Handle some hot-key strokes while the tool is active
			
			def onKeyUp(key, repeat, flags, view)
				
				if key==VK_DELETE
					# Delete last added nodal point if any while drawing a contour
					if @pick_state=="draw_contour"
						if @nodal_points
							if @nodal_points.length>0
								last_pt=@nodal_points.pop
								self.refresh_mid_points
								if @const_pts_arr.length>0
									@const_pts_arr.each{|c_pt|
										if c_pt.position==last_pt
											c_pt.erase!
										end
									}
								end
								view.invalidate
							end
						end
					end
					# Delete particular nodal point of selected zone
					if @pick_state=="over_obj"
						@ip.clear # This is incredibly important statement. If it is missing, then recreation of a zone causes SU crash. Fixed in ver. 1.1.2 13-Nov-13.
						if @selected_zone
							if @over_pt_ind
								del_pt=@nodal_points.delete_at(@over_pt_ind)
								self.refresh_mid_points
								self.recreate_zone
							end
							@over_pt_ind=nil
							@pick_state=nil
						end
					end
					
					# Delete last segment of an opening while performing cutting of new opening
					if @pick_state=="cut_opening"
						pts=@new_opening["points"]
						if pts.length>1
							last_pt=pts.pop
							@new_opening["points"]=pts
							@openings_arr[@openings_arr.length-1]=@new_opening
							if @const_pts_arr.length>0
								@const_pts_arr.each{|c_pt|
									if c_pt.position==last_pt
										c_pt.erase!
									end
								}
							end
							view.invalidate
						end
					end
					
					# Delete opening under cursor
					if @pick_state.nil?
						@ip.clear # This is incredibly important statement. If it is missing, then recreation of a zone causes SU crash. Fixed in ver. 1.1.2 13-Nov-13.
						if @opening_under_cur_ind
							@openings_arr.delete_at(@opening_under_cur_ind)
							@opening_under_cur_ind=nil
							if @selected_zone
								self.recreate_zone
							end
						end
					end
				end
				
				# Toggle zone summary visibility
				if key.chr=="\t"
					if @show_geom_summary
						@show_geom_summary=false
					else
						@show_geom_summary=true
					end
					view.invalidate
				end
				
				if key.chr=="\r"
					case @pick_state
						when nil
						# Apply current settings and generate zone object if @ready4apply
						if @ready4apply
							self.create_zone_entity
							if @zone_entity
								if @selected_zone
									@ip.clear # This is incredibly important statement. If it is missing, then recreation of a zone causes SU crash. Fixed in ver. 1.1.2 13-Nov-13.
									self.recreate_zone
								else
									@zone_entity.create_zone
									self.small_reset
									@pick_state=@last_state
									if @last_state=="pick_int_pt"
										@trace_cont=LSS_Zone_Trace_Cont.new
										@nodal_points=Array.new
										@trace_cont.int_pt_chk_hgt=@int_pt_chk_hgt
									end
									self.onSetCursor
									@last_state=nil
									self.increment_number
								end
							else
								UI.messagebox($lsszoneStrings.GetString("Draw zone or pick existing face before clicking 'Create'"))
							end
						end
						# Select zone under cursor
						if @pick_state.nil?
							if @zone_under_cur
								@selected_zone=@zone_under_cur
								self.read_settings_from_zone
								view.invalidate
							end
						end
						when "draw_contour"
							# Enter key handling disabled because of VCB
						when "pick_face"
							# Pick face under cursor
							if @face_under_cur
								@picked_face=@face_under_cur
								verts=@picked_face.outer_loop.vertices
								@nodal_points=Array.new
								verts.each{|vrt|
									@nodal_points<<vrt.position
								}
								self.refresh_mid_points
								if @height.to_f==0
									@pick_state="specify_height"
								else
									@last_state=@pick_state
									@pick_state=nil
									@ready4apply=true
								end
								self.onSetCursor
							end
						when "cut_opening"
							# Enter key handling disabled because of VCB
					end
				end
				
				if key==VK_END
					# Cancel last node and finish drawing
					if @pick_state=="draw_contour"
						if @nodal_points
							if @nodal_points.length>3
								last_pt=@nodal_points.pop
								self.refresh_mid_points
								@last_state=@pick_state
								@pick_state=nil
								@ready4apply=true
								view.invalidate
							end
						end
					end
					
					if @pick_state=="cut_opening"
						@last_state=@pick_state
						@pick_state=nil
						pts=@new_opening["points"]
						last_pt=pts.pop
						@new_opening["points"]=pts
						plane=Geom.fit_plane_to_points(pts)
						c_pt=@selected_zone.bounds.center
						proj_pt=c_pt.project_to_plane(plane)
						norm=proj_pt.vector_to(c_pt)
						op_type=self.guess_op_type(norm)
						@new_opening["type"]=op_type
						@openings_arr[@openings_arr.length-1]=@new_opening
						@new_opening=nil
						@over_first_pt=false
						@ip.clear # This is incredibly important statement. If it is missing, then recreation of a zone causes SU crash. Fixed in ver. 1.1.2 13-Nov-13.
						self.recreate_zone
						@pick_state=@last_state
						self.onSetCursor
						@last_state=nil
						view.invalidate
					end
				end
				
				if key==VK_HOME
					@pick_state=nil
					self.small_reset
				end
				
				if key==VK_INSERT
					if @over_mid_pt_ind
						new_pt=@mid_points[@over_mid_pt_ind]
						@nodal_points.insert(@over_mid_pt_ind, new_pt)
						@new_node_ind=@over_mid_pt_ind
						self.refresh_mid_points
						@pick_state="insert_new_node"
					end
				end
				
				if key==VK_SHIFT
					view = view.lock_inference
				end
			end
			
			# Tool context menu
			def getMenu(menu)
				view=Sketchup.active_model.active_view
				case @pick_state
				when "draw_contour"
					if @nodal_points.length>3
						menu.add_item($lsszoneStrings.GetString("Finish")) {
							last_pt=@nodal_points.pop
							self.refresh_mid_points
							@last_state=@pick_state
							@pick_state=nil
							@ready4apply=true
							view.invalidate
						}
					end
					if @nodal_points.length>1
						menu.add_item($lsszoneStrings.GetString("Cancel Last Node")) {
							last_pt=@nodal_points.pop
							self.refresh_mid_points
							view.invalidate
						}
					end
					menu.add_item($lsszoneStrings.GetString("Cancel Whole")) {
						self.reset(view)
					}
					if @show_geom_summary
						menu.add_item($lsszoneStrings.GetString("Hide Geometry Summary")) {
							@show_geom_summary=false
						}
					else
						menu.add_item($lsszoneStrings.GetString("Show Geometry Summary")) {
							@show_geom_summary=true
						}
					end
					menu.add_separator
					menu.add_item($lsszoneStrings.GetString("Terminate Tool")) {
						@zone_dialog.close
					}
				when "pick_face"
					menu.add_item($lsszoneStrings.GetString("Exit Picking Mode")) {
						self.reset(view)
					}
					if @show_geom_summary
						menu.add_item($lsszoneStrings.GetString("Hide Geometry Summary")) {
							@show_geom_summary=false
						}
					else
						menu.add_item($lsszoneStrings.GetString("Show Geometry Summary")) {
							@show_geom_summary=true
						}
					end
					menu.add_separator
					menu.add_item($lsszoneStrings.GetString("Terminate Tool")) {
						@zone_dialog.close
					}
				when "cut_opening"
					if @new_opening
						pts=@new_opening["points"]
						if pts.length>3
							menu.add_item($lsszoneStrings.GetString("Close Contour and Finish")) {
								@last_state=@pick_state
								@pick_state=nil
								plane=Geom.fit_plane_to_points(pts)
								c_pt=@selected_zone.bounds.center
								proj_pt=c_pt.project_to_plane(plane)
								norm=proj_pt.vector_to(c_pt)
								op_type=self.guess_op_type(norm)
								@new_opening["type"]=op_type
								pts=@new_opening["points"]
								last_pt=pts.pop
								@new_opening["points"]=pts
								@openings_arr[@openings_arr.length-1]=@new_opening
								@new_opening=nil
								@over_first_pt=false
								@ip.clear # This is incredibly important statement. If it is missing, then recreation of a zone causes SU crash. Fixed in ver. 1.1.2 13-Nov-13.
								self.recreate_zone
								@pick_state=@last_state
								@last_state=nil
								view.invalidate
							}
						end
						if pts.length>1
							menu.add_item($lsszoneStrings.GetString("Cancel Last Segment")) {
								pts=@new_opening["points"]
								last_pt=pts.pop
								@new_opening["points"]=pts
								@openings_arr[@openings_arr.length-1]=@new_opening
								view.invalidate
							}
						end
						menu.add_item($lsszoneStrings.GetString("Cancel")) {
							self.reset(view)
						}
						menu.add_separator
						menu.add_item($lsszoneStrings.GetString("Terminate Tool")) {
							@zone_dialog.close
						}
					end
				else
					if @opening_under_cur_ind
						menu.add_item($lsszoneStrings.GetString("Delete Opening")) {
							@model.start_operation($lsszoneStrings.GetString("Erase Opening"), true)
							@opening_under_cur_ind.erase!
							@opening_under_cur_ind=nil
							@model.commit_operation
							if @selected_zone
								self.read_settings_from_zone
								@ip.clear # This is incredibly important statement. If it is missing, then recreation of a zone causes SU crash. Fixed in ver. 1.1.2 13-Nov-13.
								self.recreate_zone
							end
						}
					end
					if @zone_under_cur
						menu.add_item($lsszoneStrings.GetString("Select")) {
							@selected_zone=@zone_under_cur
							self.read_settings_from_zone
							view.invalidate
						}
					end
					if @selected_zone
						menu.add_item($lsszoneStrings.GetString("Unselect")) {
							self.small_reset
						}
						if @over_mid_pt_ind
							menu.add_item($lsszoneStrings.GetString("Insert Node")) {
								new_pt=@mid_points[@over_mid_pt_ind]
								@nodal_points.insert(@over_mid_pt_ind, new_pt)
								@new_node_ind=@over_mid_pt_ind
								self.refresh_mid_points
								@pick_state="insert_new_node"
							}
						end
					end
					menu.add_item($lsszoneStrings.GetString("Reset")) {
						self.reset(view)
					}
					if @show_geom_summary
						menu.add_item($lsszoneStrings.GetString("Hide Geometry Summary")) {
							@show_geom_summary=false
						}
					else
						menu.add_item($lsszoneStrings.GetString("Show Geometry Summary")) {
							@show_geom_summary=true
						}
					end
					menu.add_separator
					menu.add_item($lsszoneStrings.GetString("Terminate Tool")) {
						@zone_dialog.close
					}
				end
			end
			
			# Handle Esc key press while tool is active.
			# - get back to nil tool state from any other state
			# - when state is nil, unselect zone if any by performing #small_reset
			# - cancel new node insertion if it was initialized
			# - cancel cutting a new opening
			
			def onCancel(reason, view)
				if @pick_state=="draw_contour" or @pick_state=="pick_face" or @pick_state=="specify_height"
					@pick_state=nil
					self.small_reset
				end
				if @pick_state.nil?
					self.small_reset
				end
				if @pick_state=="eye_dropper"
					@pick_state=nil
					self.send_settings2dlg
					js_command = "unpress_eye_dropper_btn('" + @eye_dropper_type + "')" if @eye_dropper_type
					@zone_dialog.execute_script(js_command) if js_command
				end
				if @pick_state=="insert_new_node"
					del_pt=@nodal_points.delete_at(@new_node_ind)
					@pick_state=nil
				end
				if @pick_state=="cut_opening"
					@pick_state=nil
					@new_opening=nil
					@openings_arr.pop
					view.invalidate
				end
				# Added in ver. 1.2.0 17-Nov-13.
				if @pick_state=="pick_int_pt"
					if @trace_cont
						if @trace_cont.is_tracing
							@trace_cont.stop_tracing
						else
							@pick_state=nil
							self.small_reset
						end
					end
				end
				self.onSetCursor
				view.invalidate
			end
			
			# Display custom content within 'Instructor' floater.
			
			def getInstructorContentDirectory
				locale=Sketchup.get_locale 
				dir_path="../../../../Plugins/lss_zone/Resources/#{locale}/help/zone_tool/"
				return dir_path
			end
		end #class LSS_Zone_Tool

		if( not file_loaded?("lss_zone_tool.rb") )
			LSS_Zone_Tool_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_tool.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	