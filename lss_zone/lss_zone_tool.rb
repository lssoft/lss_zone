# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# lss_zone_tool.rb ver. 1.1.0 beta 25-Oct-13
# The main file, which contains the main logic.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		#loads class wich contains Zone Entity
		require 'lss_zone/lss_zone_entity.rb'

		class LSS_Zone_Tool_Cmd
			def initialize
				@su_tools=Sketchup.active_model.tools
				@lss_zone_tool_observer=nil
				@lss_zone_tool_observer_state="disabled"
				
				lss_zone_tool=LSS_Zone_Tool.new
				lss_zone_cmd=UI::Command.new($lsszoneStrings.GetString("LSS Zone")){
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
		# It displays tool's dialog wich allows to draw new zone contour, pick a face, which represents
		# zone's contour, then set zone's attributes and finally generate new zone object.
		
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
			end
			
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
				self.settings2hash
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
			end
			
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
			end
			
			def write_defaults
				self.settings2hash
				@settings_hash.each_key{|key|
					Sketchup.write_default("LSS_Zone", key, @settings_hash[key][0].to_s)
				}
			end
			
			def create_web_dial
				# Read defaults
				self.read_defaults
				
				# Create the WebDialog instance
				@zone_dialog = UI::WebDialog.new($lsszoneStrings.GetString("LSS Zone"), true, "LSS Zone", 350, 500, 200, 200, true)
				@zone_dialog.max_width=450
				@zone_dialog.min_width=280
			
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
					if action_name.split(",")[1]=="floor_eye_dropper"
						@pick_state="eye_dropper"
						self.onSetCursor
						@eye_dropper_type="floor"
						js_command = "press_eye_dropper_btn('" + @eye_dropper_type + "')" if @eye_dropper_type
						@zone_dialog.execute_script(js_command) if js_command
					end
					if action_name.split(",")[1]=="ceiling_eye_dropper"
						@pick_state="eye_dropper"
						self.onSetCursor
						@eye_dropper_type="ceiling"
						js_command = "press_eye_dropper_btn('" + @eye_dropper_type + "')" if @eye_dropper_type
						@zone_dialog.execute_script(js_command) if js_command
						
					end
					if action_name.split(",")[1]=="wall_eye_dropper"
						@pick_state="eye_dropper"
						self.onSetCursor
						@eye_dropper_type="wall"
						js_command = "press_eye_dropper_btn('" + @eye_dropper_type + "')" if @eye_dropper_type
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
						end
						self.hash2settings
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
			end
			
			def getExtents
				if @nodal_points.length>0
					bb=Sketchup.active_model.bounds
					@nodal_points.each{|pt|
						bb.add(pt)
					}
				end
			end
			
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
			
			def onLButtonDown(flags, x, y, view)
				@drag_state=true
				@clicked_pt=@ip.position
				if @over_mid_pt_ind
					@clicked_pt=Geom::Point3d.new(@mid_points[@over_mid_pt_ind]) if @mid_points[@over_mid_pt_ind]
				end
			end
			
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
										js_command = "opening_tbody_display('" + disp + "')"
										@zone_dialog.execute_script(js_command)
									else
										disp="none"
										js_command = "opening_tbody_display('" + disp + "')"
										@zone_dialog.execute_script(js_command)
									end
								else
									self.small_reset
									disp="none"
									js_command = "opening_tbody_display('" + disp + "')"
									@zone_dialog.execute_script(js_command)
								end
							else
								self.small_reset
								disp="none"
								js_command = "opening_tbody_display('" + disp + "')"
								@zone_dialog.execute_script(js_command)
							end
						else
							self.small_reset
							disp="none"
							js_command = "opening_tbody_display('" + disp + "')"
							@zone_dialog.execute_script(js_command)
						end
				end
				self.send_settings2dlg
				js_command = "apply_defaults()"
				@zone_dialog.execute_script(js_command)
				@drag_state=false
				@ip_prev.copy!(@ip)
			end
			
			def small_reset
				@selected_zone=nil
				@labels_arr=nil
				disp="none"
				js_command = "opening_tbody_display('" + disp + "')"
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
			end
			
			def recreate_zone
				@model.start_operation($lsszoneStrings.GetString("Recreate Zone"), true)
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
					@selected_zone=@zone_entity.zone_group
					self.read_settings_from_zone
					self.send_settings2dlg
					@pick_state=nil
				@model.commit_operation
			end
			
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
			end
			
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
					view.line_width=4
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
			
			def draw_mid_points(view)
				return if @mid_points.length<1
				view.line_width=1
				view.draw_points(@mid_points, 8, 6, "black")
			end
			
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
				if (@nodal_points!=@nodal_points1 and @show_geom_summary and @over_first_pt==false and @nodal_points.length>2) or @pick_state=="pick_face"
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
			
			def draw_zone_under_cur(view)
				return if @zone_under_cur.deleted?
				bnds=@zone_under_cur.bounds
				self.draw_bounds(view, bnds, 6, 1, "green", 2)
			end
			
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

			def deactivate(view)
				@zone_dialog.close
				self.reset(view)
			end
			
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
			
			def enableVCB?
				return true
			end
			
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
			
			# Handle some hot-key strokes while the tool is active
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
									self.recreate_zone
								else
									@zone_entity.create_zone
									self.small_reset
									@pick_state=@last_state
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
				self.onSetCursor
				view.invalidate
			end
			
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