# lss_zone_label_template.rb ver. 1.2.1 alpha 25-Dec-13
# The script, which implements editing label template (template's name and string)

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		
		# This class contains implementation of editing a label template in a new modal dialog window,
		# which opens from 'Attach Labels' dialog, implemented within 'LSS_Zone_Label' class.
		# This class interacts havily with 'LSS_Zone_Label' class. Both classes send information back and forth.
		
		class LSS_Zone_Label_Template
			attr_accessor :preset_name
			attr_accessor :label_template
			attr_accessor :labels_tool
			
			def initialize
				@preset_name=""
				@label_template=""
				@labels_tool=nil
				@settings_hash=Hash.new
				self.settings2hash
				
				$lss_label_template_dial_is_active=false
				
				# Stick dialog height setting. Added in ver. 1.2.1 09-Dec-13.
				@stick_height="true"
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method populates @settings_hash with all adjustable parameters (class instance variables)
			# for further batch processing (for example for sending settings to a web-dialog or for writing
			# defaults using 'Sketchup.write_default'.
			
			def settings2hash
				@settings_hash["preset_name"]=[@preset_name, "string"]
				@settings_hash["label_template"]=[@label_template.gsub(/\n/, "\\n"), "string"] # It is important to double escape line breaks.
				
				# Stick dialog height setting. Added in ver. 1.2.1 10-Dec-13.
				@settings_hash["stick_height"]=[@stick_height, "boolean"]
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method reads values from @settings_hash and sets values of corresponding instance variables.
			
			def hash2settings
				return if @settings_hash.keys.length==0
				@preset_name=@settings_hash["preset_name"][0]
				@label_template=@settings_hash["label_template"][0]
				
				# Stick dialog height setting. Added in ver. 1.2.1 10-Dec-13.
				@stick_height=@settings_hash["stick_height"][0]
			end
			
			def read_defaults
				default_value=Sketchup.read_default("LSS Zone Label Template Defaults", "stick_height", "true")
				@settings_hash["stick_height"]=[default_value, "boolean"]
				@stick_height=default_value
			end
			
			def write_defaults
				self.settings2hash
				Sketchup.write_default("LSS Zone Label Template Defaults", "stick_height", @settings_hash["stick_height"][0].to_s)
			end
			
			# This method creates 'Label Template' web-dialog.
			
			def create_web_dial
				return if $lss_label_template_dial_is_active
				$lss_label_template_dial_is_active=true
				
				# Read defaults
				self.read_defaults
				
				# Create the WebDialog instance
				@label_template_dial = UI::WebDialog.new($lsszoneStrings.GetString("Label Template"), true, "LSS Zone Label Template", 450, 500, 200, 200, true)
				@label_template_dial.min_width=450
				@label_template_dial.max_width=800
				
				# Attach an action callback
				@label_template_dial.add_action_callback("get_data") do |web_dialog,action_name|
					view=Sketchup.active_model.active_view
					if action_name=="get_settings" # From Ruby to web-dialog
						self.send_settings2dlg
						view.invalidate
					end
					if action_name=="save_template"
						@labels_tool.label_template=@label_template
						@labels_tool.preset_name=@preset_name
						@labels_tool.save_template
						@labels_tool.refresh
						@label_template_dial.close
					end
					if action_name=="cancel"
						@label_template_dial.close
					end
					if action_name=="get_fields"
						@labels_tool.send_fields2dlg(@label_template_dial)
					end
					if action_name=="get_label_preview"
						@labels_tool.generate_label_preview_txt
						@labels_tool.send_label_preview2dlg(@label_template_dial)
					end
					if action_name.split(",")[0]=="label_template"
						@label_template=action_name.split(",")[1]
						@labels_tool.label_template=@label_template
						@labels_tool.generate_label_preview_txt
						@labels_tool.send_label_preview2dlg(@label_template_dial)
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
							LSS_Zone_Utils.new.adjust_dial_size(@label_template_dial, @cont_height, @cont_width, @d_width, @d_height, @dial_y, @scr_height) if val=="true"
							# Patch to solve a problem with #set_on_close method of a modal web-dialog.
							self.hash2settings
							self.write_defaults
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
						@label_template_dial.execute_script(js_command) if js_command
						@init_width=@visible_width
						@init_height=@visible_height
						@label_template_dial.set_size(@init_width, @init_height)
						js_command="send_visible_size()"
						@label_template_dial.execute_script(js_command) if js_command
						@d_height=@init_height-@visible_height + @hdr_ftr_height
						@d_width=@init_width-@visible_width
						win_width=@init_width+@d_width
						win_height=@init_height+@d_height
						@label_template_dial.set_size(win_width, win_height)
					end
					if action_name=="adjust_dial_size"
						if @stick_height=="true"
							LSS_Zone_Utils.new.adjust_dial_size(@label_template_dial, @cont_height, @cont_width, @d_width, @d_height, @dial_y, @scr_height)
						end
					end
					# Content size block end
				end
				resource_dir=LSS_Dirs.new.resource_path
				dial_path="#{resource_dir}/lss_zone/lss_zone_label_template.html"
				@label_template_dial.set_file(dial_path)
				@label_template_dial.show_modal()
				# This method does not work for modal dialog...
				@label_template_dial.set_on_close{
					self.write_defaults
					$lss_label_template_dial_is_active=false
				}
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
					@label_template_dial.execute_script(js_command) if js_command
				}
			end
		end #class LSS_Zone_Label_Template
	end #module LSS_Zone_Extension
end #module LSS_Extensions	