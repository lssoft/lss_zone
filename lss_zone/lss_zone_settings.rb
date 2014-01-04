# lss_zone_settings.rb ver. 1.2.1 alpha 26-Dec-13
# The file, which contains 'Global Settings' dialog implementation
# Not in use for now.

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
		
		# This class adds 'Global Settings' command.
		# Not in use for now.
		
		class LSS_Zone_Settings_Cmd
			def initialize
				settings=LSS_Zone_Settings.new
				lss_zone_settings_cmd=UI::Command.new($lsszoneStrings.GetString("Global Settings")){
					settings.create_web_dial
				}
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=13
					lss_zone_settings_cmd.small_icon = "./tb_icons/settings_24.png"
					lss_zone_settings_cmd.large_icon = "./tb_icons/settings_32.png"
				else
					lss_zone_settings_cmd.small_icon = "./tb_icons/settings_16.png"
					lss_zone_settings_cmd.large_icon = "./tb_icons/settings_24.png"
				end
				lss_zone_settings_cmd.tooltip = $lsszoneStrings.GetString("Click to adjust extension's global settings.")
				$lsszoneToolbar.add_item(lss_zone_settings_cmd)
				$lsszoneMenu.add_item(lss_zone_settings_cmd)
			end

		end #class LSS_Zone_Settings_Cmd
		
		class LSS_Zone_Settings
			def initialize
				@int_pt_chk_hgt=100.0
				@aperture_size=4.0
				@trace_openings="true"
				@use_materials="true"
				@min_wall_offset=12.0
				@op_trace_offset=2.0
				@segm_tracing_lim=3000
				
				# Level where to place label text initially during creation of a zone
				@label_level="bottom" # bottom, center, top
				# Position of a label on the label level plane
				@label_pos="center" #top_left, top_right, bottom_right, bottom_left, center
				# Offset from chosen alignment point
				@label_offset=30
				
				# Style of tools' dialogs' contents representation (standard or small)
				@dial_style="standard"
				
				@settings_hash=Hash.new
				self.settings2hash
				$lss_zone_settings_dial_is_active=false
				
				# Hash, which contains states of roll groups states (folded/unfolded).
				# Added in ver. 1.2.1 09-Dec-13.
				@dialog_rolls_hash=Hash.new
				@dialog_rolls_hash["trace_cont_group"]="-"
				@dialog_rolls_hash["label_pos_group"]="-"
				
				# Stick dialog height setting. Added in ver. 1.2.1 09-Dec-13.
				@stick_height="true"
			end
			
			def settings2hash
				@settings_hash["int_pt_chk_hgt"]=[@int_pt_chk_hgt, "distance"]
				@settings_hash["aperture_size"]=[@aperture_size, "distance"]
				@settings_hash["trace_openings"]=[@trace_openings, "boolean"]
				@settings_hash["use_materials"]=[@use_materials, "boolean"]
				@settings_hash["min_wall_offset"]=[@min_wall_offset, "distance"]
				@settings_hash["op_trace_offset"]=[@op_trace_offset, "distance"]
				@settings_hash["segm_tracing_lim"]=[@segm_tracing_lim, "integer"]
				
				# Label position settings. Added in ver. 1.2.1 09-Dec-13.
				@settings_hash["label_level"]=[@label_level, "string"]
				@settings_hash["label_pos"]=[@label_pos, "string"]
				@settings_hash["label_offset"]=[@label_offset, "distance"]
				
				# Dialogs representation style. Added in ver. 1.2.1 26-Dec-13.
				@settings_hash["dial_style"]=[@dial_style, "string"]
				
				# Stick dialog height setting. Added in ver. 1.2.1 09-Dec-13.
				@settings_hash["stick_height"]=[@stick_height, "boolean"]
				
				# Store data types
				@settings_hash.each_key{|key|
					Sketchup.write_default("LSS Zone Data Types", key, @settings_hash[key][1])
				}
			end
			
			def hash2settings
				@int_pt_chk_hgt=@settings_hash["int_pt_chk_hgt"][0]
				@aperture_size=@settings_hash["aperture_size"][0]
				@trace_openings=@settings_hash["trace_openings"][0]
				@use_materials=@settings_hash["use_materials"][0]
				@min_wall_offset=@settings_hash["min_wall_offset"][0]
				@op_trace_offset=@settings_hash["op_trace_offset"][0]
				@segm_tracing_lim=@settings_hash["segm_tracing_lim"][0]
				
				# Label position settings. Added in ver. 1.2.1 09-Dec-13.
				@label_level=@settings_hash["label_level"][0]
				@label_pos=@settings_hash["label_pos"][0]
				@label_offset=@settings_hash["label_offset"][0]
				
				# Dialogs representation style. Added in ver. 1.2.1 26-Dec-13.
				@dial_style=@settings_hash["dial_style"][0]
				
				# Stick dialog height setting. Added in ver. 1.2.1 09-Dec-13.
				@stick_height=@settings_hash["stick_height"][0]
			end
			
			def read_defaults
				@settings_hash.each_key{|key|
					default_value=Sketchup.read_default("LSS Zone Defaults", key, @settings_hash[key][0])
					default_data_type=Sketchup.read_default("LSS Zone Data Types", key, @settings_hash[key][1])
					@settings_hash[key]=[default_value, default_data_type]
				}
				self.hash2settings
				
				# Group of dialog settings states (folded/unfolded). Added in ver. 1.2.1 09-Dec-13
				@dialog_rolls_hash.each_key{|key|
					@dialog_rolls_hash[key]=Sketchup.read_default("LSS_Zone_Settings_Dialog_Rolls", key, "-")
				}
			end
			
			def write_defaults
				self.settings2hash
				@settings_hash.each_key{|key|
					Sketchup.write_default("LSS Zone Defaults", key, @settings_hash[key][0].to_s)
				}
				
				# Group of settings states (folded/unfolded). Added in ver. 1.2.1 06-Dec-13
				@dialog_rolls_hash.each_key{|key|
					Sketchup.write_default("LSS_Zone_Settings_Dialog_Rolls", key, @dialog_rolls_hash[key])
				}
			end
			
			def create_web_dial
				return if $lss_zone_settings_dial_is_active
				$lss_zone_settings_dial_is_active=true
				# Read defaults
				self.read_defaults
				
				# Create the WebDialog instance
				@settings_dialog = UI::WebDialog.new($lsszoneStrings.GetString("LSS Zone Settings"), true, "LSS Zone Settings", 350, 350, 200, 200, true)
				@settings_dialog.max_width=450
				@settings_dialog.min_width=210
			
				# Attach an action callback
				@settings_dialog.add_action_callback("get_data") do |web_dialog,action_name|
					if action_name=="apply_settings"
						self.write_defaults
					end
					if action_name=="get_settings" # From Ruby to web-dialog
						self.send_settings2dlg
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
							LSS_Zone_Utils.new.adjust_dial_size(@settings_dialog, @cont_height, @cont_width, @d_width, @d_height, @dial_y, @scr_height) if val=="true"
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
							@settings_dialog.execute_script(js_command) if js_command
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
						@settings_dialog.execute_script(js_command) if js_command
						@init_width=@visible_width
						@init_height=@visible_height
						@settings_dialog.set_size(@init_width, @init_height)
						js_command="send_visible_size()"
						@settings_dialog.execute_script(js_command) if js_command
						@d_height=@init_height-@visible_height + @hdr_ftr_height
						@d_width=@init_width-@visible_width
						win_width=@init_width+@d_width
						win_height=@init_height+@d_height
						@settings_dialog.set_size(win_width, win_height)
					end
					if action_name=="adjust_dial_size"
						if @stick_height=="true"
							LSS_Zone_Utils.new.adjust_dial_size(@settings_dialog, @cont_height, @cont_width, @d_width, @d_height, @dial_y, @scr_height)
						end
					end
					# Content size block end
					if action_name=="cancel"
						@settings_dialog.close
					end
					# Dialog style handling. Added in ver. 1.2.1 26-Dec-13.
					if action_name=="get_dial_style"
						dial_style=Sketchup.read_default("LSS Zone Defaults", "dial_style", "standard")
						js_command="get_dial_style('" + dial_style + "')"
						@settings_dialog.execute_script(js_command) if js_command
					end
				end
				resource_dir=LSS_Dirs.new.resource_path
				dial_path="#{resource_dir}/lss_zone/lss_zone_settings.html"
				@settings_dialog.set_file(dial_path)
				@settings_dialog.show()
				@settings_dialog.set_on_close{
					self.write_defaults
					$lss_zone_settings_dial_is_active=false
				}
			end
			
			def send_settings2dlg
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
					@settings_dialog.execute_script(js_command) if js_command
				}
			end
		end #class LSS_Zone_Settings

		if( not file_loaded?("lss_zone_settings.rb") )
			LSS_Zone_Settings_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_settings.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	