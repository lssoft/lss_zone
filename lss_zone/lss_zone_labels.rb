# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# lss_zone_labels.rb ver. 1.0.0 beta 30-Sep-13
# The script, which implements attaching labels with zone attributes to existing zone objects
# in an active model.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
	
		require 'lss_zone/lss_zone_label_template.rb'
		
		class LSS_Zone_Labels_Cmd
			def initialize
				lss_zone_labels_tool=LSS_Zone_Labels_Tool.new
				lss_zone_labels_cmd=UI::Command.new($lsszoneStrings.GetString("Attach Labels")){
					Sketchup.active_model.select_tool(lss_zone_labels_tool)
					lss_zone_labels_tool.filter_selection
				}
				lss_zone_labels_cmd.small_icon = "./tb_icons/labels_24.png"
				lss_zone_labels_cmd.large_icon = "./tb_icons/labels_32.png"
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
			
			def create_web_dial
				self.read_defaults
				
				# Create the WebDialog instance
				@zone_labels_dialog = UI::WebDialog.new($lsszoneStrings.GetString("Labels"), true, "LSS Zone Labels", 450, 500, 200, 200, true)
				@zone_labels_dialog.min_width=450
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
				end
				resource_dir=LSS_Dirs.new.resource_path
				dial_path="#{resource_dir}/lss_zone/lss_zone_labels.html"
				@zone_labels_dialog.set_file(dial_path)
				@zone_labels_dialog.show()
				@zone_labels_dialog.set_on_close{
					self.write_defaults
					Sketchup.active_model.select_tool(nil)
				}
			end
			
			# The main method, which adds text objects inside each of selected zone group.
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
					rebuild_tool.process_selection
					self.filter_selection
				@model.commit_operation
				Sketchup.status_text=$lsszoneStrings.GetString("Labels attaching complete.")
				js_command = "set_default_state()"
				@zone_labels_dialog.execute_script(js_command) if js_command
			end

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
			
			def settings2hash
				@settings_hash["preset_name"]=[@preset_name, "string"]
				@settings_hash["label_layer"]=[@label_layer, "string"]
			end
			
			def hash2settings
				return if @settings_hash.keys.length==0
				@preset_name=@settings_hash["preset_name"][0]
				@label_layer=@settings_hash["label_layer"][0]
			end
			
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
			
			# Create instance of LSS_Zone_Label_Template, which has implementation of 'Label Template' dialog
			def edit_preset
				template_inst=LSS_Zone_Label_Template.new
				template_inst.preset_name=@preset_name
				template_inst.label_template=@label_template
				template_inst.labels_tool=self
				template_inst.create_web_dial
			end
			
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
			
			def refresh
				js_command = "custom_init()"
				@zone_labels_dialog.execute_script(js_command) if js_command
			end
			
			def send_label_preview2dlg(dial)
				# It is necessary to "double escape" new line characters again before sending to js
				escaped_text=@label_preview_txt.gsub(/\n/, "\\n")
				js_command = "get_label_preview_txt('" + escaped_text + "')" if escaped_text
				dial.execute_script(js_command) if js_command
			end
			
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
				# Sketchup.write_default("LSS_Zone_Labels", "presets_cnt", @presets_cnt)
			end
			
			def read_defaults
				# @presets_cnt=Sketchup.read_default("LSS_Zone_Labels", "presets_cnt", 0)
			end
			
			def draw(view)
				self.draw_label_preview(view)
			end
			
			def draw_label_preview(view)
				return if @preset_name.nil? or @preset_name==""
				txt_pt=view.center
				preview_text="Preview of Label:\n\n" + @label_preview_txt
				status = view.draw_text(txt_pt, preview_text)
				status = view.draw_text(txt_pt, preview_text)
			end
			
			def generate_label_preview_txt
				if @label_template.nil? or @label_template==""
					@label_preview_txt=""
					return
				end
				etalon_zone=@selected_zones.first
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
							value=area_str
						when "volume"
							vol_str=LSS_Math.new.format_volume(value)
							value=vol_str
						else
							
					end
					@label_preview_txt.gsub!(attr_name, value.to_s)
				}
			end
			
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
			
			def send_fields2dlg(dial)
				js_command="clear_fields()"
				dial.execute_script(js_command)
				@field_names.each{|field_name|
					field_name1="@"+field_name
					js_command = "get_field_name('" + field_name1 + "')"
					dial.execute_script(js_command)
				}
			end
			
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