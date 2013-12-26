# lss_zone_labels.rb ver. 1.2.1 alpha 26-Dec-13
# The script, which implements attaching labels with zone attributes to existing zone objects
# in an active model.

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
	
		require 'lss_zone/lss_zone_label_template.rb'
		
		# This class adds 'Attach Labels' command to LSS Zone menu and toolbar.
		
		class LSS_Zone_Labels_Cmd
			def initialize
				lss_zone_labels_tool=LSS_Zone_Labels_Tool.new
				lss_zone_labels_cmd=UI::Command.new($lsszoneStrings.GetString("Attach Labels")){
					Sketchup.active_model.select_tool(lss_zone_labels_tool)
					lss_zone_labels_tool.filter_selection
				}
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=13
					lss_zone_labels_cmd.small_icon = "./tb_icons/labels_24.png"
					lss_zone_labels_cmd.large_icon = "./tb_icons/labels_32.png"
				else
					lss_zone_labels_cmd.small_icon = "./tb_icons/labels_16.png"
					lss_zone_labels_cmd.large_icon = "./tb_icons/labels_24.png"
				end
				lss_zone_labels_cmd.tooltip = $lsszoneStrings.GetString("Select zones, then click to attach labels.")
				$lsszoneToolbar.add_item(lss_zone_labels_cmd)
				$lsszoneMenu.add_item(lss_zone_labels_cmd)
			end
		end #class LSS_Zone_Labels_Cmd
		
		# This class contains tool implementation for text labels attaching to selected zone(s) in an active model
		
		class LSS_Zone_Labels_Tool
			attr_accessor :preset_name
			attr_accessor :label_template
			def initialize
				@model=Sketchup.active_model
				@preset_name=""
				@label_preview_txt=""
				@label_template=""
				@preset_file_name=""
				
				@label_layer="LSS Zone Label"
				
				@settings_hash=Hash.new
				
				# Stick dialog height setting. Added in ver. 1.2.1 10-Dec-13.
				@stick_height="true"
				
				$lss_labels_dial_is_active=false
			end
			
			def activate
				@selection=@model.selection
				self.create_web_dial
			end
			
			# In case if current selection contains some irrelevant objects (not only zone objects) it is
			# necessary to filter selection and store selected zones in an array for further processing.
			
			def filter_selection
				@field_names=Array.new
				@selected_zones=Array.new
				if @selection.length==0
					UI.messagebox($lsszoneStrings.GetString("It is necessary to select some zone objects before launching 'Labels' command."))
				else
					i=1
					tot_cnt=@selection.length
					progr_char="|"
					rest_char="_"
					scale_coeff=1
					progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
					js_command = "set_progress_state()"
					@zone_labels_dialog.execute_script(js_command) if js_command
					@selection.each{|ent|
						if ent.is_a?(Sketchup::Group)
							number=ent.get_attribute("LSS_Zone_Entity", "number")
							if number
								@selected_zones<<ent
								dict=ent.attribute_dictionary("LSS_Zone_Entity")
								dict.each_key{|key|
									if @field_names.include?(key)==false
										@field_names<<key
									end
								}
							end
						end
						progr_bar.update(i)
						i+=1
						Sketchup.status_text=$lsszoneStrings.GetString("Filtering selection: ") + progr_bar.progr_string
					}
					Sketchup.status_text=$lsszoneStrings.GetString("Filtering complete.")
					js_command = "set_default_state()"
					@zone_labels_dialog.execute_script(js_command) if js_command
				end
			end
			
			# This class creates 'Labels' web-dialog.
			
			def create_web_dial
				return if $lss_labels_dial_is_active
				$lss_labels_dial_is_active=true
			
				self.read_defaults
				
				# Create the WebDialog instance
				@zone_labels_dialog = UI::WebDialog.new($lsszoneStrings.GetString("Labels"), true, "LSS Zone Labels", 450, 500, 200, 200, true)
				@zone_labels_dialog.min_width=350
				@zone_labels_dialog.max_width=800
				
				# Attach an action callback
				@zone_labels_dialog.add_action_callback("get_data") do |web_dialog,action_name|
					view=Sketchup.active_model.active_view
					if action_name=="apply_settings"
						self.attach_labels
					end
					if action_name=="get_settings" # From Ruby to web-dialog
						self.send_settings2dlg
						view.invalidate
					end
					if action_name=="get_presets"
						self.send_presets2dlg
					end
					if action_name=="get_layers"
						self.send_layers2dlg
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
							LSS_Zone_Utils.new.adjust_dial_size(@zone_labels_dialog, @cont_height, @cont_width, @d_width, @d_height, @dial_y, @scr_height) if val=="true"
						end
						self.hash2settings
					end
					if action_name=="get_label_preview"
						self.generate_label_preview_txt
						self.send_label_preview2dlg(@zone_labels_dialog)
					end
					if action_name.split(",")[0]=="select_preset"
						@preset_name=action_name.split(",")[1]
						self.settings2hash
						self.read_template_from_file
					end
					if action_name.split(",")[0]=="edit_preset"
						@preset_name=action_name.split(",")[1]
						self.edit_preset
					end
					if action_name.split(",")[0]=="delete_preset"
						@preset_name=action_name.split(",")[1]
						self.delete_preset
					end
					if action_name=="add_preset"
						self.add_preset
					end
					if action_name=="reset"
						view=Sketchup.active_model.active_view
						self.reset(view)
						view.invalidate
						lss_zone_labels_tool=LSS_Zone_Labels_Tool.new
						Sketchup.active_model.select_tool(lss_zone_labels_tool)
					end
					if action_name=="cancel"
						@zone_labels_dialog.close
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
						@zone_labels_dialog.execute_script(js_command) if js_command
						@init_width=@visible_width
						@init_height=@visible_height
						@zone_labels_dialog.set_size(@init_width, @init_height)
						js_command="send_visible_size()"
						@zone_labels_dialog.execute_script(js_command) if js_command
						@d_height=@init_height-@visible_height + @hdr_ftr_height
						@d_width=@init_width-@visible_width
						win_width=@init_width+@d_width
						win_height=@init_height+@d_height
						@zone_labels_dialog.set_size(win_width, win_height)
					end
					if action_name=="adjust_dial_size"
						if @stick_height=="true"
							LSS_Zone_Utils.new.adjust_dial_size(@zone_labels_dialog, @cont_height, @cont_width, @d_width, @d_height, @dial_y, @scr_height)
						end
					end
					# Content size block end
					
					# Dialog style handling. Added in ver. 1.2.1 26-Dec-13.
					if action_name=="get_dial_style"
						dial_style=Sketchup.read_default("LSS Zone Defaults", "dial_style", "standard")
						js_command="get_dial_style('" + dial_style + "')"
						@zone_labels_dialog.execute_script(js_command) if js_command
					end
				end
				resource_dir=LSS_Dirs.new.resource_path
				dial_path="#{resource_dir}/lss_zone/lss_zone_labels.html"
				@zone_labels_dialog.set_file(dial_path)
				@zone_labels_dialog.show()
				@zone_labels_dialog.set_on_close{
					self.write_defaults
					Sketchup.active_model.select_tool(nil)
					$lss_labels_dial_is_active=false
				}
			end
			
			# The main method, which attaches labels to each of selected zone group.
			# It iterates through @selected_zones array and attaches new attribute to each zone.
			# The attribute has the following information:
			# - label preset name
			# - label template
			# - label layer
			# Then it calls 'process_selection' method of LSS_Zone_Rebuild_Tool, which
			# iterates through selected zones and rebuilds each zone. Method, which rebuilds
			# each zone, reads all attributes (including information about attached labels)
			# from an existing zone, then erases existing zone, then creates new zone using
			# settings obtained from attributes. Method, which creates new zone iterates through
			# array of labels (which has new label as well) and finally adds text objects
			# inside newly created zone group.
			
			def attach_labels
				rebuild_tool=LSS_Zone_Rebuild_Tool.new
				dict_name="zone_label: "+@preset_name
				i=1
				tot_cnt=@selected_zones.length
				progr_char="|"
				rest_char="_"
				scale_coeff=1
				progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
				js_command = "set_progress_state()"
				@zone_labels_dialog.execute_script(js_command) if js_command
				@model.start_operation($lsszoneStrings.GetString("Attach Labels"), true)
					@zone_labels_dialog.execute_script(js_command) if js_command
					@selected_zones.each{|zone|
						zone.set_attribute(dict_name, "preset_name", @preset_name)
						zone.set_attribute(dict_name, "label_template", @label_template)
						zone.set_attribute(dict_name, "label_layer", @label_layer)
						progr_bar.update(i)
						i+=1
						Sketchup.status_text=$lsszoneStrings.GetString("Attaching labels: ") + progr_bar.progr_string
					}
					# Set parameter to 'false' so 'process_selection' method does not perform '@model.start_operation'
					rebuild_tool.process_selection(false)
					self.filter_selection
				@model.commit_operation
				Sketchup.status_text=$lsszoneStrings.GetString("Labels attaching complete.")
				js_command = "set_default_state()"
				@zone_labels_dialog.execute_script(js_command) if js_command
			end
			
			# This method reads label template from a file with a name equal to @preset_file_name
			
			def read_template_from_file
				return if @preset_name.nil? or @preset_name==""
				@preset_file_name=@preset_names[@preset_name]
				if @preset_file_name.nil?
					@preset_file_name=@preset_names[@preset_names.keys.first]
				end
				resource_dir=LSS_Dirs.new.resource_path
				presets_dir="#{resource_dir}/label_presets/"
				preset_file=File.open(presets_dir+@preset_file_name, "r")
				@label_template=""
				read_template=false
				finish_reading=false
				while (line = preset_file.gets)
					if line.include?("<label_template>")
						read_template=true
					end
					if line.include?("</label_template>")
						read_template=false
						finish_reading=true
					end
					if finish_reading
						break
					end
					if read_template
						@label_template+=line
					end
				end
				preset_file.close
				@label_template.gsub!("<label_template>\n", "")
				@label_template.gsub!("<label_template>", "")
				@label_template.gsub!("</label_template>", "")
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method populates @settings_hash with all adjustable parameters (class instance variables)
			# for further batch processing (for example for sending settings to a web-dialog or for writing
			# defaults using 'Sketchup.write_default'.
			
			def settings2hash
				@settings_hash["preset_name"]=[@preset_name, "string"]
				@settings_hash["label_layer"]=[@label_layer, "string"]
				
				# Stick dialog height setting. Added in ver. 1.2.1 10-Dec-13.
				@settings_hash["stick_height"]=[@stick_height, "boolean"]
			end
			
			# This is a common method for all LSS tools and some tool-like classes, in which web-dialog is present
			# and lots of settings have to be sent back and forth between tool (or tool-like class) and web-dialog.
			# This method reads values from @settings_hash and sets values of corresponding instance variables.
			
			def hash2settings
				return if @settings_hash.keys.length==0
				@preset_name=@settings_hash["preset_name"][0]
				@label_layer=@settings_hash["label_layer"][0]
				
				# Stick dialog height setting. Added in ver. 1.2.1 10-Dec-13.
				@stick_height=@settings_hash["stick_height"][0]
			end
			
			# This method deletes preset with name equals to @preset_name.
			# Note that @preset_file_name is not equal to @preset_name.
			# Preset name is stored inside a file in a line, which starts with "label_name=".
			# Method iterates through all files stored in "#{resource_dir}/label_presets/"
			# and searches for a file which has the same contents after "label_name=" as @preset_name value does,
			# then deletes such file in case of its presense.
			# This method is called after clicking 'delete preset' button of 'Labels' dialog.
			
			def delete_preset
				resource_dir=LSS_Dirs.new.resource_path
				presets_dir="#{resource_dir}/label_presets/"
				file2del_name=nil
				Dir.foreach(presets_dir){|preset_file_name|
					if preset_file_name!="." and preset_file_name!=".."
						begin
							preset_file=File.open(presets_dir+preset_file_name, "r")
							while (line = preset_file.gets)
								key_val=line.split("=")
								if key_val[1]
									key_val[1]=key_val[1].gsub("\n", "")
									if key_val[0]=="label_name"
										if key_val[1].include?(@preset_name)
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
				File.delete(presets_dir+file2del_name) if file2del_name
				@preset_name=""
				@preset_file_name=""
				self.refresh
			end
			
			# Create instance of LSS_Zone_Label_Template, which has implementation of 'Label Template' dialog.
			# This method is called after clicking 'edit' button of 'Labels' dialog.
			
			def edit_preset
				template_inst=LSS_Zone_Label_Template.new
				template_inst.preset_name=@preset_name
				template_inst.label_template=@label_template
				template_inst.labels_tool=self
				template_inst.create_web_dial
			end
			
			# This method adds new preset. First of all it iterates through files in "#{resource_dir}/label_presets/" directory
			# in order to find out the minimum file number, which is not yet in use, then creates new file with 'lbl'
			# extension and 'label_<file number>' file name.
			# Initial preset name is also automatically generated ("New Label Template <file number>") and method
			# puts this name to a newly created file after "label_name=".
			# Immideately after creation of a new label template file this method calls #edit_preset method, so
			# it is possible to assign a meaningful name to a new template and create template contents last.
			
			def add_preset
				resource_dir=LSS_Dirs.new.resource_path
				presets_dir="#{resource_dir}/label_presets/"
				file_exist=true
				file_no=0
				while file_exist
					file_no_str=file_no.to_s
					file_no_str="0"+file_no_str if file_no_str.length<2
					file_no_str="0"+file_no_str if file_no_str.length<3
					new_file_name="label_"+file_no_str+".lbl"
					full_name=presets_dir+new_file_name
					file_exist=File.exist?(full_name)
					if file_exist==false
						new_preset=File.new(full_name, "w")
						const_part=$lsszoneStrings.GetString("New Label Template")
						@preset_name="#{const_part} #{file_no_str}"
						new_preset.puts("label_name="+@preset_name)
						new_preset.close
						@preset_file_name=new_file_name
					end
					file_no+=1
				end
				@label_template=""
				self.refresh
				self.edit_preset
			end
			
			# This method refreshes web-dialog contents by calling custom initialization function
			# of its java-script part.
			
			def refresh
				js_command = "custom_init()"
				@zone_labels_dialog.execute_script(js_command) if js_command
			end
			
			# This method sends generated sample label text stored in @label_preview_txt to a web-dialog,
			# so user may observe a sample of selected label before performing batch labels attaching.
			
			def send_label_preview2dlg(dial)
				# It is necessary to "double escape" new line characters again before sending to js
				escaped_text=@label_preview_txt.gsub(/\n/, "\\n").gsub("'", "*") # Patch to solve js errors problem with feet and inches. Added in ver. 1.1.1 06-Nov-13.
				js_command = "get_label_preview_txt('" + escaped_text + "')" if escaped_text
				dial.execute_script(js_command) if js_command
			end
			
			# This method iterates through all files stored in "#{resource_dir}/label_presets/" directory and
			# reads preset name from each file and put it into @preset_names hash.
			# Then it iterates through @preset_names hash and send each obtained name to a web-dialog.
			# All names get to an array of preset names which is a sorce of values for preset name selector
			# (drop-down list of names) of web-dialog.
			
			def send_presets2dlg
				@preset_names=Hash.new
				resource_dir=LSS_Dirs.new.resource_path
				presets_dir="#{resource_dir}/label_presets/"
				Dir.foreach(presets_dir){|preset_file_name|
					if preset_file_name!="." and preset_file_name!=".."
						begin
							preset_file=File.open(presets_dir+preset_file_name, "r")
							while (line = preset_file.gets)
								key_val=line.split("=")
								key_val[1]=key_val[1].gsub("\n", "")
								if key_val[0]=="label_name"
									@preset_names[key_val[1]]=preset_file_name
									if @preset_name=="" or @preset_name.nil?
										@preset_name=key_val[1]
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
				if @preset_names.length>0
					js_command = "clear_presets()"
					@zone_labels_dialog.execute_script(js_command) if js_command
					@preset_names.each_key{|preset_name|
						js_command = "get_preset('" + preset_name + "')" if preset_name
						@zone_labels_dialog.execute_script(js_command) if js_command
					}
				end
				self.read_template_from_file
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
					@zone_labels_dialog.execute_script(js_command) if js_command
				}
			end
			
			def write_defaults
				self.settings2hash
				Sketchup.write_default("LSS Zone Labels Defaults", "stick_height", @settings_hash["stick_height"][0].to_s)
			end
			
			def read_defaults
				default_value=Sketchup.read_default("LSS Zone Labels Defaults", "stick_height", "true")
				@settings_hash["stick_height"]=[default_value, "boolean"]
				@stick_height=default_value
			end
			
			# This method calls label preview drawing method.
			
			def draw(view)
				self.draw_label_preview(view)
			end
			
			# This method draws label preview text right in the center of screen in a current model.
			
			def draw_label_preview(view)
				return if @preset_name.nil? or @preset_name==""
				txt_pt=view.center
				preview_text="Preview of Label:\n\n" + @label_preview_txt
				status = view.draw_text(txt_pt, preview_text)
				status = view.draw_text(txt_pt, preview_text)
			end
			
			# This method generates label preview text. It processes only one zone from @selected_zones array.
			# Later this text becomes observable by a user within 'Labels' dialog and right in the center of
			# the screen.
			
			def generate_label_preview_txt
				if @label_template.nil? or @label_template==""
					@label_preview_txt=""
					return
				end
				etalon_zone=@selected_zones.first
				return if etalon_zone.nil? # Fix added in ver. 1.2.1 10-Dec-13.
				attr_dict=etalon_zone.attribute_dictionary("LSS_Zone_Entity")
				@label_preview_txt="#{@label_template}"
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
							
					end
					@label_preview_txt.gsub!(attr_name, value.to_s)
				}
			end
			
			# This method saves template to a corresponding label template file.
			
			def save_template
				resource_dir=LSS_Dirs.new.resource_path
				presets_dir="#{resource_dir}/label_presets/"
				preset_file=File.open(presets_dir+@preset_file_name, "w")
				preset_file.puts("label_name=#{@preset_name}")
				preset_file.puts("<label_template>")
				preset_file.puts(@label_template)
				preset_file.puts("<label_template>")
				preset_file.close
			end
			
			# This method sends attribute names to a web-dialog, which was passed as an argument.
			# Auto-suggest widget, which is attached to a text field where label template contents are
			# to be entered and edited, uses an array of attribute names in order to pick certain
			# attribute name from a suggestion list instead of typing it.
			
			def send_fields2dlg(dial)
				js_command="clear_fields()"
				dial.execute_script(js_command)
				@field_names.each{|field_name|
					field_name1="@"+field_name
					js_command = "get_field_name('" + field_name1 + "')"
					dial.execute_script(js_command)
				}
			end
			
			# This method sends layers to 'Labels' dialog. An array of labels is a sorce of
			# layer names for 'Layers' selector of 'Labels' dialog.
			# The idea is that later labels have to be placed on a specified layer (not just an
			# active layer, but a certain layer where this particular laber have to be).
			# This approach allows to attach multiple labels to a zone or to a set of zones and
			# make those labels visible on certain scenes without overlapping, which helps to prepare model
			# for 'LayOut'.
			# For example one set of labels may be visible at a floor plan only, another set of labels may be visible
			# at ceiling plan only, next one at furniture layout etc.
			
			def send_layers2dlg
				layers=@model.layers
				js_command="clear_layers()"
				@zone_labels_dialog.execute_script(js_command)
				layers.each{|layer|
					layer_name=layer.name
					js_command = "get_layer('" + layer_name + "')"
					@zone_labels_dialog.execute_script(js_command)
				}
			end
			
			# This method displays custom content within 'Instructor' floater.
			
			def getInstructorContentDirectory
				resource_dir=LSS_Dirs.new.resource_path
				locale=Sketchup.get_locale 
				dir_path="../../../../Plugins/lss_zone/Resources/#{locale}/help/labels/"
				return dir_path
			end
		end #class LSS_Zone_Labels_Tool

		if( not file_loaded?("lss_zone_labels.rb") )
			LSS_Zone_Labels_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_labels.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	