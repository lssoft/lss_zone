# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# lss_zone_label_template.rb ver. 1.0.0 beta 30-Sep-13
# The script, which implements editing label template (template's name and string)

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
			end
			
			def settings2hash
				@settings_hash["preset_name"]=[@preset_name, "string"]
				@settings_hash["label_template"]=[@label_template.gsub(/\n/, "\\n"), "string"] # It is important to double escape line breaks.
			end
			
			def hash2settings
				return if @settings_hash.keys.length==0
				@preset_name=@settings_hash["preset_name"][0]
				@label_template=@settings_hash["label_template"][0]
			end
			
			def create_web_dial
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
						self.hash2settings
					end
				end
				resource_dir=LSS_Dirs.new.resource_path
				dial_path="#{resource_dir}/lss_zone/lss_zone_label_template.html"
				@label_template_dial.set_file(dial_path)
				@label_template_dial.show_modal()
				@label_template_dial.set_on_close{
					
				}
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
					@label_template_dial.execute_script(js_command) if js_command
				}
			end
		end #class LSS_Zone_Label_Template
	end #module LSS_Zone_Extension
end #module LSS_Extensions	