# lss_zone_link_ops.rb ver. 1.2.1 alpha 25-Dec-13
# The script, which contains 'Link Openings Tool' implementation.
# This tool searches for adjacent openings among selected zones
# and marks adjucent openings as internal.
# It provides ability to generate links graph in an active model as well.

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		
		# This class adds 'Link Openings Tool' command to LSS Zone menu and toolbar.
		
		class LSS_Zone_Link_Ops_Cmd
			def initialize
				# Add Link Openings command
				lss_zone_link_ops_cmd=UI::Command.new($lsszoneStrings.GetString("Link Openings Tool")){
					link_ops_tool=LSS_Zone_Link_Ops_Tool.new
					Sketchup.active_model.select_tool(link_ops_tool)
				}
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=13
					lss_zone_link_ops_cmd.small_icon = "./tb_icons/link_ops_24.png"
					lss_zone_link_ops_cmd.large_icon = "./tb_icons/link_ops_32.png"
				else
					lss_zone_link_ops_cmd.small_icon = "./tb_icons/link_ops_16.png"
					lss_zone_link_ops_cmd.large_icon = "./tb_icons/link_ops_24.png"
				end
				lss_zone_link_ops_cmd.tooltip = $lsszoneStrings.GetString("Select zones with openings, then click to link openings.")
				$lsszoneToolbar.add_item(lss_zone_link_ops_cmd)
				lss_zone_refresh_graph_cmd=UI::Command.new($lsszoneStrings.GetString("Refresh Links Graph")){
					refresh_graph=LSS_Zone_Refresh_Graph.new
					refresh_graph.process_selection
				}
				sub_menu=$lsszoneMenu.add_submenu($lsszoneStrings.GetString("Link Openings"))
				sub_menu.add_item(lss_zone_link_ops_cmd)
				sub_menu.add_item(lss_zone_refresh_graph_cmd)
				
				selection=Sketchup.active_model.selection
				UI.add_context_menu_handler do |context_menu|
					if selection.length==1
						if selection[0].get_attribute("LSS_Zone_Graph", "graph_group")
							context_menu.add_separator
							context_menu.add_item(lss_zone_refresh_graph_cmd)
						end
					end
				end
			end

		end #class LSS_Zone_Link_Ops_Cmd
		
		# This class contains implementation of a tool, which searches for adjacent openings among selected zones.
		
		class LSS_Zone_Link_Ops_Tool
			
			# Initialize tool's settings
			
			def initialize
				# If the distance between centers of two openings is less, than @check_dist, then openings are adjacent ones.
				@check_dist=12.0
				# The size of spheres, which represent graph nodes, and thickness of cylinders, which represent links between nodes
				# may represent area of a zone and area of opening respectively in case if this setting is set to "true".
				@weightened_graph="true"
				# Hash of settings is a common parameter for all LSS tools and tool-like classes, where lots of settings
				# are to be transferred between tool (tool-like class) and a web-dialog.
				@settings_hash=Hash.new
				# Array of openings of selected zones.
				@openings_arr=Array.new
				
				# Stick dialog height setting. Added in ver. 1.2.1 25-Dec-13.
				@stick_height="true"
			end
			
			def read_defaults
				@check_dist=Sketchup.read_default("LSS_Zone", "check_dist", 12.0)
				@weightened_graph=Sketchup.read_default("LSS_Zone", "weightened_graph", "true")
				self.settings2hash
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method populates @settings_hash with all adjustable parameters (class instance variables)
			# for further batch processing (for example for sending settings to a web-dialog or for writing
			# defaults using 'Sketchup.write_default'.
			
			def settings2hash
				@settings_hash["check_dist"]=[@check_dist, "distance"]
				@settings_hash["weightened_graph"]=[@weightened_graph, "boolean"]
				# Stick dialog height setting. Added in ver. 1.2.1 25-Dec-13.
				@settings_hash["stick_height"]=[@stick_height, "boolean"]
				
				# Store data types
				@settings_hash.each_key{|key|
					Sketchup.write_default("LSS Zone Data Types", key, @settings_hash[key][1])
				}
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method reads values from @settings_hash and sets values of corresponding instance variables.
			
			def hash2settings
				return if @settings_hash.keys.length==0
				@check_dist=@settings_hash["check_dist"][0]
				@weightened_graph=@settings_hash["weightened_graph"][0]
				# Stick dialog height setting. Added in ver. 1.2.1 25-Dec-13.
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
			end
			
			# This method creates 'Link Openings' dialog.
			# This dialog lets to set the value of @check_dist and provides the ability to 
			# start linking process.
			# Links preview area of a dialog allows to observe linking process.
			# It is possible to generate links graph in an active model after linking is finished
			# by clicking an appropriate command button on a dialog.
			
			def create_web_dial
				# Read defaults
				self.read_defaults
				
				# Create the WebDialog instance
				@link_ops_dialog = UI::WebDialog.new($lsszoneStrings.GetString("Link Openings"), true, "Link Openings", 350, 500, 200, 200, true)
				@link_ops_dialog.max_width=800
				@link_ops_dialog.min_width=280
			
				# Attach an action callback
				@link_ops_dialog.add_action_callback("get_data") do |web_dialog,action_name|
					view=Sketchup.active_model.active_view
					if action_name=="apply_settings"
						self.link_openings
					end
					if action_name=="get_settings" # From Ruby to web-dialog
						self.send_settings2dlg
						view.invalidate
					end
					if action_name=="get_cat_colors" # From Ruby to web-dialog
						self.send_cat_colors2dlg
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
						self.hash2settings
						# Handle stick height setting change
						if key=="stick_height"
							LSS_Zone_Utils.new.adjust_dial_size(@link_ops_dialog, @cont_height, @cont_width, @d_width, @d_height, @dial_y, @scr_height) if val=="true"
						end
					end
					if action_name.split(",")[0]=="move_node" # From web-dialog
						ind=action_name.split(",")[1].to_i
						dx=action_name.split(",")[2].to_f
						dy=action_name.split(",")[3].to_f
						node=@nodes_arr[ind]
						new_pos=Geom::Point3d.new(@init_pos.x+dx, @init_pos.y-dy, @init_pos.z)
						node["position"]=new_pos
						@nodes_arr[ind]=node
						view.invalidate
					end
					if action_name.split(",")[0]=="save_node_init_pos" # From web-dialog
						ind=action_name.split(",")[1].to_i
						node=@nodes_arr[ind]
						@init_pos=node["position"]
						view.invalidate
					end
					if action_name.split(",")[0]=="refresh_links" # From web-dialog
						ind=action_name.split(",")[1].to_i
						node=@nodes_arr[ind]
						pos_str=ind.to_s+"|"+node["position"].to_a.join(",")
						js_command = "update_node_position('" + pos_str + "')"
						@link_ops_dialog.execute_script(js_command)
						js_command = "rebuild_links_graph()"
						@link_ops_dialog.execute_script(js_command) if js_command
					end
					if action_name=="build_graph"
						self.build_graph
					end
					if action_name=="reset"
						view=Sketchup.active_model.active_view
						self.reset(view)
						view.invalidate
						Sketchup.active_model.select_tool(nil)
						link_ops_tool=LSS_Zone_Link_Ops_Tool.new
						Sketchup.active_model.select_tool(link_ops_tool)
					end
					if action_name=="cancel_action"
						reason="dialog_cancel"
						self.onCancel(reason, view)
					end
					# Content size block start (WARNING: this block differs from similar blocks in other dialogs)
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
					# Warning: this particular action presents only in 'Link Openings' dialog
					if action_name.split(",")[0]=="links_cont_height"
						@links_cont_height=action_name.split(",")[1].to_i
					end
					if action_name=="init_dial_d_size"
						# Warning: this parameter request present only in 'Link Openings' dialog
						# because links container is available only in this dialog.
						js_command="send_links_cont_height()"
						@link_ops_dialog.execute_script(js_command) if js_command
						#
						js_command="send_visible_size()"
						@link_ops_dialog.execute_script(js_command) if js_command
						@init_width=@visible_width
						@init_height=@visible_height
						@link_ops_dialog.set_size(@init_width, @init_height)
						js_command="send_visible_size()"
						@link_ops_dialog.execute_script(js_command) if js_command
						# @d_height computing differs from other dialogs because of links container height
						@d_height1=@init_height-@visible_height + @hdr_ftr_height + @links_cont_height
						@d_height2=@init_height-@visible_height + @hdr_ftr_height
						@d_width=@init_width-@visible_width
						win_width=@init_width+@d_width
						win_height=@init_height+@d_height2
						@link_ops_dialog.set_size(win_width, win_height)
					end
					if action_name=="adjust_dial_size_max"
						if @stick_height=="true"
							LSS_Zone_Utils.new.adjust_dial_size(@link_ops_dialog, @cont_height, @cont_width, @d_width, @d_height1, @dial_y, @scr_height)
						end
					end
					if action_name=="adjust_dial_size_min"
						if @stick_height=="true"
							LSS_Zone_Utils.new.adjust_dial_size(@link_ops_dialog, @cont_height, @cont_width, @d_width, @d_height2, @dial_y, @scr_height)
						end
					end
					if action_name=="adjust_dial_size"
						if @stick_height=="true"
							LSS_Zone_Utils.new.adjust_dial_size(@link_ops_dialog, @cont_height, @cont_width, @d_width, @d_height1, @dial_y, @scr_height)
						end
					end
					# Content size block end
				end
				resource_dir=LSS_Dirs.new.resource_path
				dial_path="#{resource_dir}/lss_zone/lss_zone_link_ops.html"
				@link_ops_dialog.set_file(dial_path)
				@link_ops_dialog.show()
				@link_ops_dialog.set_on_close{
					self.write_defaults
					Sketchup.active_model.select_tool(nil)
				}
			end
			
			# Initialize @model.
			# Initialize input points and @selection.
			# Perform selection filtering in order to select only zone objects from selection set.
			# Create 'Link Openings' web-dialog.
			
			def activate
				@model=Sketchup.active_model
				@ip = Sketchup::InputPoint.new
				@ip1 = Sketchup::InputPoint.new
				@selection=@model.selection
				self.filter_selection
				self.create_web_dial
			end
			
			# This method collects only zone objects from current selection set and
			# puts collected zone groups to @selected_zones array for further processing.
			
			def filter_selection
				@selected_zones=Array.new
				if @selection.length==0
					UI.messagebox($lsszoneStrings.GetString("It is necessary to select some zone objects before launching 'Link Openings' command."))
				else
					selected_groups=@selection.select{|ent| ent.is_a?(Sketchup::Group)}
					@selected_zones=selected_groups.select{|grp| not(grp.get_attribute("LSS_Zone_Entity", "number").nil?)}
				end
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method performs batch sending of settings to a web-dialog by iterating through a @settings_hash.
			# Each value of @settings_hash is an array of two values:
			# 1. value itself
			# 2. value type
			# So #send_settings2dlg method uses 'value_type' to format representation of a value in a web-dialog.
			# The point is that all dimensional data in Sketchup is stored in decimal inches, so it is necessary
			# to format length, area and volume values in order to represent a value as a string 
			# in a user-specific format.
			
			def send_settings2dlg
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
					@link_ops_dialog.execute_script(js_command) if js_command
				}
			end
			
			# Read categories colors and send them to dialog in order to display nodes of a graph
			# using zone's category color.
			
			def send_cat_colors2dlg
				# Send list of categories from an active model to a web-dialog
				js_command = "clear_cats_arr()"
				@link_ops_dialog.execute_script(js_command) if js_command
				categories=@model.attribute_dictionary("LSS Zone Categories")
				materials=@model.materials
				if categories
					categories.each_key{|cat|
						mat=materials[cat]
						col=mat.color
						cat_col_str=cat+"|" + col.to_a.join(",")
						js_command = "get_cat_col('" + cat_col_str + "')"
						@link_ops_dialog.execute_script(js_command) if js_command
					}
				end
			end
			
			# Draw links, nodes and highlight internal openings.
			
			def draw(view)
				if @links_arr
					if @links_arr.length>0
						self.draw_links(view)
					end
				end
				if @nodes_arr
					if @nodes_arr.length>0
						self.draw_nodes(view)
					end
				end
				if @openings_pts
					if @openings_pts.length>0
						self.draw_openings(view)
					end
				end
			end
			
			def draw_links(view)
				@links_arr.each{|link|
					node1=@nodes_arr[link[0]]
					node2=@nodes_arr[link[1]]
					pos1=node1["position"]
					pos2=node2["position"]
					link_line=[pos1, pos2]
					pts2d=Array.new
					link_line.each{|pt|
						pts2d<<view.screen_coords(pt)
					}
					view.line_width=3
					view.draw2d(GL_LINES, pts2d)
					view.line_width=1
				}
			end
			
			def draw_nodes(view)
				circle_pts=LSS_Geom.new.circle_pts12
				r=10.0
				# pt_type 1 = open square, 2 = filled square, 3 = "+", 4 = "X", 5 = "*", 6 = open triangle, 7 = filled triangle.
				# pt_size=20; pt_type=7; pt_col="red"
				# view.draw_points(pts, pt_size, pt_type, pt_col)
				@nodes_arr.each{|node|
					pt=node["position"]
					pt2d=view.screen_coords(pt)
					node_pts=Array.new
					circle_pts.each{|circ_pt|
						node_pts<<[circ_pt.x*r+pt2d.x, circ_pt.y*r+pt2d.y]
					}
					mat=@model.materials[node["category"]]
					col=mat.color
					col.alpha=mat.alpha
					view.drawing_color=col
					view.draw2d(GL_POLYGON, node_pts)
					view.drawing_color="black"
					view.line_width=3
					node_pts<<node_pts.first
					view.draw2d(GL_LINE_STRIP, node_pts)
					view.line_width=1
				}
			end
			
			def draw_openings(view)
				@openings_pts.each{|op_pts|
					pts2d=Array.new
					op_pts.each{|pt|
						pts2d<<view.screen_coords(pt)
					}
					pts2d<<view.screen_coords(op_pts.first)
					view.line_width=1
					view.drawing_color="black"
					view.draw2d(GL_LINE_STRIP, pts2d)
				}
			end
			
			# The main method, which checks distance between centers of openings and marks openings as internal in case
			# if checked distance is less, than a value specified in a dialog (@check_dist)
			
			def link_openings
				view=Sketchup.active_model.active_view
				js_command = "clear_nodes_and_links()"
				@link_ops_dialog.execute_script(js_command) if js_command
				i=1
				tot_cnt=@selected_zones.length
				progr_char="|"; rest_char="_"; scale_coeff=1
				progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
				js_command = "set_progress_state()"
				@link_ops_dialog.execute_script(js_command) if js_command
				@openings_arr=Array.new
				@selected_zones.each{|zone|
					groups_arr=zone.entities.select{|ent| ent.is_a?(Sketchup::Group)}
					groups_arr.each{|grp|
						if grp.get_attribute("LSS_Zone_Element", "type")
							if grp.get_attribute("LSS_Zone_Element", "type").include?("opening")
								@openings_arr<<grp
							end
						end
					}
					progr_bar.update(i)
					i+=1
					Sketchup.status_text=$lsszoneStrings.GetString("Collecting openings: ") + progr_bar.progr_string
				}
				Sketchup.status_text=$lsszoneStrings.GetString("Collecting complete.")
				js_command = "set_default_state()"
				@link_ops_dialog.execute_script(js_command) if js_command
				@links_arr=Array.new
				@nodes_arr=Array.new
				@processed_zones=Array.new
				@openings_pts=Array.new
				linked_ops=Array.new
				bb=Geom::BoundingBox.new
				ind1=0
				tot_cnt=@openings_arr.length
				progr_char="|"; rest_char="_"; scale_coeff=1
				progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
				js_command = "set_progress_state()"
				@link_ops_dialog.execute_script(js_command) if js_command
				id = UI.start_timer(0.01, true) {
					op1=@openings_arr[ind1]
					c_pt1=op1.bounds.center
					inst_arr1=op1.parent.instances.select{|ent| op1.parent.entities.include?(op1)}
					zone_c_pt1=inst_arr1[0].bounds.center
					# Read some identification data frome zone1
					zone1=inst_arr1[0]
					number1=zone1.get_attribute("LSS_Zone_Entity", "number")
					name1=zone1.get_attribute("LSS_Zone_Entity", "name")
					category1=zone1.get_attribute("LSS_Zone_Entity", "category")
					value1=zone1.get_attribute("LSS_Zone_Entity", "area")
					area1=Sketchup.format_area(value1.to_f).to_s
					identity_str1="#{number1},#{name1},#{area1}"
					@openings_arr.each_index{|ind2|
						if ind1!=ind2
							op2=@openings_arr[ind2]
							c_pt2=op2.bounds.center
							if linked_ops.include?(op1)==false and linked_ops.include?(op2)==false
								dist=c_pt1.distance(c_pt2)
								# Check the distance and mark openings as internal in case if it is less than @chek_dist
								if dist<@check_dist.to_f
									inst_arr2=op2.parent.instances.select{|ent| op2.parent.entities.include?(op2)}
									zone_c_pt2=inst_arr2[0].bounds.center
									
									# Read some identification data frome zone2
									zone2=inst_arr2[0]
									number2=zone2.get_attribute("LSS_Zone_Entity", "number")
									name2=zone2.get_attribute("LSS_Zone_Entity", "name")
									category2=zone2.get_attribute("LSS_Zone_Entity", "category")
									value2=zone2.get_attribute("LSS_Zone_Entity", "area")
									area2=Sketchup.format_area(value2.to_f).to_s
									identity_str2="#{number2},#{name2},#{area2}"
									
									# Check if zones are processed or not and add nodes to @nodes_arr
									zone1_processed=false; zone2_processed=false
									if @processed_zones.include?(zone1)==false
										@processed_zones<<zone1
										node_hash=Hash.new
										node_hash["number"]=number1
										node_hash["name"]=name1
										node_hash["category"]=category1
										node_hash["area"]=area1
										node_hash["position"]=zone_c_pt1
										@nodes_arr<<node_hash
										node_str1="#{number1},#{name1},#{category1},#{area1}"
										pos_str1=zone_c_pt1.to_a.join(",")
										js_command = "get_node_identity('" + node_str1 + "')"
										@link_ops_dialog.execute_script(js_command)
										js_command = "get_node_position('" + pos_str1 + "')"
										@link_ops_dialog.execute_script(js_command)
										zone1_processed=true
									end
									if @processed_zones.include?(zone2)==false
										@processed_zones<<zone2
										node_hash=Hash.new
										node_hash["number"]=number2
										node_hash["name"]=name2
										node_hash["category"]=category2
										node_hash["area"]=area2
										node_hash["position"]=zone_c_pt2
										@nodes_arr<<node_hash
										node_str2="#{number2},#{name2},#{category2},#{area2}"
										pos_str2=zone_c_pt2.to_a.join(",")
										js_command = "get_node_identity('" + node_str2 + "')"
										@link_ops_dialog.execute_script(js_command)
										js_command = "get_node_position('" + pos_str2 + "')"
										@link_ops_dialog.execute_script(js_command)
										zone2_processed=true
									end
									
									if zone1_processed==false or zone2_processed==false
										# Read openings points and areas
										op_face1=op1.entities.select{|ent| (ent.is_a?(Sketchup::Face))}[0]
										op_area1=op_face1.area
										if op_face1
											op_pts1=Array.new
											op_verts=op_face1.outer_loop.vertices
											op_verts.each{|vrt|
												op_pts1<<vrt.position.transform(op1.transformation).transform(zone1.transformation)
											}
											@openings_pts<<op_pts1
										end
										op_face2=op2.entities.select{|ent| (ent.is_a?(Sketchup::Face))}[0]
										op_area2=op_face2.area
										if op_face2
											op_pts2=Array.new
											op_verts=op_face2.outer_loop.vertices
											op_verts.each{|vrt|
												op_pts2<<vrt.position.transform(op2.transformation).transform(zone2.transformation)
											}
											@openings_pts<<op_pts2
										end
										
										# @links_arr<<[zone_c_pt1, c_pt1, c_pt1, c_pt2, c_pt2, zone_c_pt2]
										@links_arr<<[@processed_zones.index(zone1), @processed_zones.index(zone2), op_area1, op_area2]
										link_str=@processed_zones.index(zone1).to_s + "|" + @processed_zones.index(zone2).to_s + "|" + area1.to_s + "|" + area2.to_s
										js_command = "get_link('" + link_str + "')"
										@link_ops_dialog.execute_script(js_command) if js_command
										linked_ops<<op1
										linked_ops<<op2
										bb.add(zone_c_pt1)
										bb.add(zone_c_pt2)
										min_max_str=bb.min.to_a.join(",") + "|" + bb.max.to_a.join(",")
										js_command = "get_max_min_bounds('" + min_max_str + "')"
										@link_ops_dialog.execute_script(js_command) if js_command
										center_str=bb.center.to_a.join(",")
										js_command = "get_center('" + center_str + "')"
										@link_ops_dialog.execute_script(js_command) if js_command
										js_command = "rebuild_links_graph()"
										@link_ops_dialog.execute_script(js_command) if js_command
										view.invalidate
										
										op1.set_attribute("LSS_Zone_Element", "is_internal", true)
										op2.set_attribute("LSS_Zone_Element", "is_internal", true)
										# Set the same link_time in order to find linked openings more quickly later
										link_time=Time.now
										op1.set_attribute("LSS_Zone_Element", "link_time", link_time)
										op2.set_attribute("LSS_Zone_Element", "link_time", link_time)
										
										# Recalc zones' attributes
										was_internal1=op1.get_attribute("LSS_Zone_Element", "is_internal")
										was_internal2=op2.get_attribute("LSS_Zone_Element", "is_internal")
										self.recalc_openings(zone1, op1, op_area1) if was_internal1.nil? or was_internal1==false
										self.recalc_openings(zone2, op2, op_area2) if was_internal2.nil? or was_internal2==false
									end
								end
							end
						end
					}
					progr_bar.update(ind1)
					Sketchup.status_text=$lsszoneStrings.GetString("Linking openings: ") + progr_bar.progr_string
					ind1+=1
					if ind1==@openings_arr.length-1 or @stop_linking
						UI.stop_timer(id)
						js_command = "display_build_graph()"
						@link_ops_dialog.execute_script(js_command) if js_command
						Sketchup.status_text=$lsszoneStrings.GetString("Linking complete.")
						js_command = "set_default_state()"
						@link_ops_dialog.execute_script(js_command) if js_command
					end
				}
			end
			
			# This method updates zone's openings area information: decreases external openings area and
			# increases internal openings area by an area of an opening passed as an argument.
			
			def recalc_openings(zone, op, area)
				is_internal=op.get_attribute("LSS_Zone_Element", "is_internal")
				case op.get_attribute("LSS_Zone_Element", "type")
					when "wall_opening"
						wall_int_ops_area=zone.get_attribute("LSS_Zone_Entity", "wall_int_ops_area").to_f
						wall_ext_ops_area=zone.get_attribute("LSS_Zone_Entity", "wall_ext_ops_area").to_f
						wall_int_ops_area+=area
						wall_ext_ops_area-=area
						zone.set_attribute("LSS_Zone_Entity", "wall_int_ops_area", wall_int_ops_area)
						zone.set_attribute("LSS_Zone_Entity", "wall_ext_ops_area", wall_ext_ops_area)
					when "floor_opening"
						floor_int_ops_area=zone.get_attribute("LSS_Zone_Entity", "floor_int_ops_area").to_f
						floor_ext_ops_area=zone.get_attribute("LSS_Zone_Entity", "floor_ext_ops_area").to_f
						floor_int_ops_area+=area
						floor_ext_ops_area-=area
						zone.set_attribute("LSS_Zone_Entity", "floor_int_ops_area", floor_int_ops_area)
						zone.set_attribute("LSS_Zone_Entity", "floor_ext_ops_area", floor_ext_ops_area)
					when "ceiling_opening"
						ceiling_int_ops_area=zone.get_attribute("LSS_Zone_Entity", "ceiling_int_ops_area").to_f
						ceiling_ext_ops_area=zone.get_attribute("LSS_Zone_Entity", "ceiling_ext_ops_area").to_f
						ceiling_int_ops_area+=area
						ceiling_ext_ops_area-=area
						zone.set_attribute("LSS_Zone_Entity", "ceiling_int_ops_area", ceiling_int_ops_area)
						zone.set_attribute("LSS_Zone_Entity", "ceiling_ext_ops_area", ceiling_ext_ops_area)
				end
			end
			
			# This method build a graph, which illustrates links between adjacent zones.
			
			def build_graph
				graph_group=@model.entities.add_group
				etalon_len=Sketchup.parse_length("1000mm")
				etalon_r=Sketchup.parse_length("1000mm")
				etalon_r=etalon_r*3.0
				etalon_area=Math::PI*etalon_r*etalon_r
				@model.start_operation($lsszoneStrings.GetString("Build Graph"), true)
					definitions=@model.definitions
					# Populate with nodes
					node_path=Sketchup.find_support_file("node.skp","Plugins/lss_zone/support/")
					node_def=definitions.load(node_path)
					i=1
					tot_cnt=@nodes_arr.length
					progr_char="|"; rest_char="_"; scale_coeff=1
					progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
					js_command = "set_progress_state()"
					@link_ops_dialog.execute_script(js_command) if js_command
					@nodes_arr.each_index{|ind|
						node=@nodes_arr[ind]
						pos=node["position"]
						cat=node["category"]
						mat=@model.materials[cat]
						tr=Geom::Transformation.new
						pos_tr=Geom::Transformation.new(pos)
						node_inst=graph_group.entities.add_instance(node_def, tr)
						zone=@processed_zones[ind]
						area=zone.get_attribute("LSS_Zone_Entity", "area").to_f
						if @weightened_graph=="true"
							sc=Math.sqrt(area.to_f/etalon_area)
							sc_tr=Geom::Transformation.scaling(sc)
							node_inst.transform!(sc_tr)
						end
						node_inst.transform!(pos_tr)
						node_inst.material=mat
						node_inst.set_attribute("LSS_Zone_Graph", "type", "node")
						node_inst.set_attribute("LSS_Zone_Graph", "ind", ind)
						node_inst.set_attribute("LSS_Zone_Graph", "category", cat)
						node_inst.set_attribute("LSS_Zone_Graph", "area", area)
						progr_bar.update(i)
						i+=1
						Sketchup.status_text=$lsszoneStrings.GetString("Populating with nodes: ") + progr_bar.progr_string
					}
					Sketchup.status_text=$lsszoneStrings.GetString("Populating with nodes complete.")
					js_command = "set_default_state()"
					@link_ops_dialog.execute_script(js_command) if js_command
					# Populate with links
					link_path=Sketchup.find_support_file("link.skp","Plugins/lss_zone/support/")
					link_def=definitions.load(link_path)
					i=1
					tot_cnt=@links_arr.length
					progr_char="|"; rest_char="_"; scale_coeff=1
					progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
					js_command = "set_progress_state()"
					@link_ops_dialog.execute_script(js_command) if js_command
					@links_arr.each{|link|
						ind1=link[0]
						ind2=link[1]
						node1=@nodes_arr[ind1]
						node2=@nodes_arr[ind2]
						pos1=node1["position"]
						pos2=node2["position"]
						tr=Geom::Transformation.new
						link_inst=graph_group.entities.add_instance(link_def, tr)
						link_len=pos1.distance(pos2)
						z_sc=link_len.to_f/(etalon_len.to_f)
						area1=link[2]
						area2=link[3]
						if @weightened_graph=="true"
							area=(area1.to_f+area2.to_f)/2.0
							xy_sc=area/etalon_area
						else
							xy_sc=0.3
						end
						sc_tr=Geom::Transformation.scaling(xy_sc, xy_sc, z_sc)
						link_inst.transform!(sc_tr)
						vec=pos1.vector_to(pos2)
						if vec.length>0
							z_ax_tr=Geom::Transformation.new(pos1, vec)
							link_inst.transform!(z_ax_tr)
							link_inst.set_attribute("LSS_Zone_Graph", "type", "link")
							link_inst.set_attribute("LSS_Zone_Graph", "ind1", ind1)
							link_inst.set_attribute("LSS_Zone_Graph", "ind2", ind2)
							link_inst.set_attribute("LSS_Zone_Graph", "area1", area1)
							link_inst.set_attribute("LSS_Zone_Graph", "area2", area2)
						else
							link_inst.erase!
						end
						progr_bar.update(i)
						i+=1
						Sketchup.status_text=$lsszoneStrings.GetString("Populating with links: ") + progr_bar.progr_string
					}
					Sketchup.status_text=$lsszoneStrings.GetString("Populating with links complete.")
					js_command = "set_default_state()"
					@link_ops_dialog.execute_script(js_command) if js_command
					graph_group.set_attribute("LSS_Zone_Graph", "graph_group", true)
					graph_group.set_attribute("LSS_Zone_Graph", "weightened_graph", @weightened_graph)
				@model.commit_operation
			end
			
			# This method resets 'Link Openings' tool and web-dialog.
			
			def reset(view)
				@ip.clear
				@ip1.clear
				if( view )
					view.tooltip = nil
					view.invalidate
				end
				
				self.read_defaults
				self.send_settings2dlg
			end
			
			# This method closes 'Link Openings' dialog in case of tool deactivation.

			def deactivate(view)
				@link_ops_dialog.close
				self.reset(view)
			end
			
			# This method stops linking process in case of cancelling by hitting Esc key.
			
			def onCancel(reason, view)
				# Stop linking process if any
				@stop_linking=true
				view.invalidate
			end
			
			def getInstructorContentDirectory
				resource_dir=LSS_Dirs.new.resource_path
				locale=Sketchup.get_locale 
				dir_path="../../../../Plugins/lss_zone/Resources/#{locale}/help/link_ops/"
				return dir_path
			end
		end #class LSS_Zone_Link_Ops_Tool
		
		# This class contains implementation of links graph manual refreshing.
		# It might be useful after user moved some graph nodes.
		
		class LSS_Zone_Refresh_Graph
			
			# Initialize @model and @selection
			
			def initialize
				@model=Sketchup.active_model
				@selection=@model.selection
			end
			
			# Filters selection first, then refreshes selected graphs iterating through @selected_graph array and
			# calling #refresh_graph.
			
			def process_selection
				self.filter_selection
				if @selected_graphs.length>0
					@selected_graphs.each{|graph|
						self.refresh_graph(graph)
					}
				else
					UI.messagebox($lsszoneStrings.GetString("It is necessary to select some graph objects before launching 'Refresh Links Graph' command."))
				end
			end
			
			# This method Filter selection in order to select only link graphs.
			
			def filter_selection
				@selected_graphs=Array.new
				if @selection.length==0
					UI.messagebox($lsszoneStrings.GetString("It is necessary to select some graph objects before launching 'Refresh Links Graph' command."))
				else
					selected_groups=@selection.select{|ent| ent.is_a?(Sketchup::Group)}
					@selected_graphs=selected_groups.select{|grp| grp.get_attribute("LSS_Zone_Graph", "graph_group")}
				end
			end
			
			# This method refreshes given graph group.
			
			def refresh_graph(graph_group)
				@model.start_operation($lsszoneStrings.GetString("Refresh Graph"), true)
					@link_groups_arr=Array.new
					@node_groups_arr=Array.new
					i=1
					tot_cnt=graph_group.entities.length
					progr_char="|"; rest_char="_"; scale_coeff=1
					progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
					graph_group.entities.each{|ent|
						if ent.get_attribute("LSS_Zone_Graph", "type")=="node"
							@node_groups_arr<<ent
						end
						if ent.get_attribute("LSS_Zone_Graph", "type")=="link"
							@link_groups_arr<<ent
						end
						progr_bar.update(i)
						i+=1
						Sketchup.status_text=$lsszoneStrings.GetString("Reading nodes and links: ") + progr_bar.progr_string
					}
					Sketchup.status_text=$lsszoneStrings.GetString("Reading complete.")
					@links_arr=Array.new
					@nodes_arr=Array.new(@node_groups_arr.length)
					i=1
					tot_cnt=@node_groups_arr.length
					progr_char="|"; rest_char="_"; scale_coeff=1
					progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
					@node_groups_arr.each{|node_group|
						ind=node_group.get_attribute("LSS_Zone_Graph", "ind").to_i
						area=node_group.get_attribute("LSS_Zone_Graph", "area").to_f
						category=node_group.get_attribute("LSS_Zone_Graph", "category")
						node_hash=Hash.new
						node_hash["area"]=area
						node_hash["category"]=category
						node_hash["position"]=node_group.bounds.center
						@nodes_arr[ind]=node_hash
						progr_bar.update(i)
						i+=1
						Sketchup.status_text=$lsszoneStrings.GetString("Building nodes array: ") + progr_bar.progr_string
					}
					i=1
					tot_cnt=@link_groups_arr.length
					progr_char="|"; rest_char="_"; scale_coeff=1
					progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
					@link_groups_arr.each{|link_group|
						ind1=link_group.get_attribute("LSS_Zone_Graph", "ind1").to_i
						ind2=link_group.get_attribute("LSS_Zone_Graph", "ind2").to_i
						area1=link_group.get_attribute("LSS_Zone_Graph", "area1").to_f
						area2=link_group.get_attribute("LSS_Zone_Graph", "area2").to_f
						@links_arr<<[ind1, ind2, area1, area2]
						progr_bar.update(i)
						i+=1
						Sketchup.status_text=$lsszoneStrings.GetString("Building links array: ") + progr_bar.progr_string
					}
					
					graph_group.entities.clear!
					
					@weightened_graph=graph_group.get_attribute("LSS_Zone_Graph", "weightened_graph")
					etalon_len=Sketchup.parse_length("1000mm")
					etalon_r=Sketchup.parse_length("1000mm")
					etalon_r=etalon_r*3.0
					etalon_area=Math::PI*etalon_r*etalon_r
					definitions=@model.definitions
					# Populate with nodes
					node_path=Sketchup.find_support_file("node.skp","Plugins/lss_zone/support/")
					node_def=definitions.load(node_path)
					i=1
					tot_cnt=@nodes_arr.length
					progr_char="|"; rest_char="_"; scale_coeff=1
					progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
					@nodes_arr.each_index{|ind|
						node=@nodes_arr[ind]
						pos=node["position"]
						cat=node["category"]
						area=node["area"].to_f
						mat=@model.materials[cat]
						tr=Geom::Transformation.new
						pos_tr=Geom::Transformation.new(pos)
						node_inst=graph_group.entities.add_instance(node_def, tr)
						if @weightened_graph=="true"
							sc=Math.sqrt(area.to_f/etalon_area)
							sc_tr=Geom::Transformation.scaling(sc)
							node_inst.transform!(sc_tr)
						end
						node_inst.transform!(pos_tr)
						node_inst.material=mat
						node_inst.set_attribute("LSS_Zone_Graph", "type", "node")
						node_inst.set_attribute("LSS_Zone_Graph", "ind", ind)
						node_inst.set_attribute("LSS_Zone_Graph", "category", cat)
						node_inst.set_attribute("LSS_Zone_Graph", "area", area)
						progr_bar.update(i)
						i+=1
						Sketchup.status_text=$lsszoneStrings.GetString("Populating with nodes: ") + progr_bar.progr_string
					}
					# Populate with links
					link_path=Sketchup.find_support_file("link.skp","Plugins/lss_zone/support/")
					link_def=definitions.load(link_path)
					i=1
					tot_cnt=@links_arr.length
					progr_char="|"; rest_char="_"; scale_coeff=1
					progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
					@links_arr.each{|link|
						ind1=link[0]
						ind2=link[1]
						node1=@nodes_arr[ind1]
						node2=@nodes_arr[ind2]
						pos1=node1["position"]
						pos2=node2["position"]
						tr=Geom::Transformation.new
						link_inst=graph_group.entities.add_instance(link_def, tr)
						link_len=pos1.distance(pos2)
						z_sc=link_len.to_f/(etalon_len.to_f)
						area1=link[2]
						area2=link[3]
						if @weightened_graph=="true"
							area=(area1.to_f+area2.to_f)/2.0
							xy_sc=area/etalon_area
						else
							xy_sc=0.3
						end
						sc_tr=Geom::Transformation.scaling(xy_sc, xy_sc, z_sc)
						link_inst.transform!(sc_tr)
						vec=pos1.vector_to(pos2)
						z_ax_tr=Geom::Transformation.new(pos1, vec)
						link_inst.transform!(z_ax_tr)
						link_inst.set_attribute("LSS_Zone_Graph", "type", "link")
						link_inst.set_attribute("LSS_Zone_Graph", "ind1", ind1)
						link_inst.set_attribute("LSS_Zone_Graph", "ind2", ind2)
						link_inst.set_attribute("LSS_Zone_Graph", "area1", area1)
						link_inst.set_attribute("LSS_Zone_Graph", "area2", area2)
						progr_bar.update(i)
						i+=1
						Sketchup.status_text=$lsszoneStrings.GetString("Populating with links: ") + progr_bar.progr_string
					}
					Sketchup.status_text=$lsszoneStrings.GetString("Graph refreshing complete.") + progr_bar.progr_string
				@model.commit_operation
			end
		end #class LSS_Zone_Refresh_Graph

		if( not file_loaded?("lss_zone_link_ops.rb") )
			LSS_Zone_Link_Ops_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_link_ops.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	