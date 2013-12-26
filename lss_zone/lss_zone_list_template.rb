# lss_zone_list_template.rb ver. 1.2.1 alpha 26-Dec-13
# The file, which contains report template editing dialog (query string, sort and group options etc)

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		
		# This class contains implementation of a dialog for editing zone's list template.
		# It is possible to edit query string, select field to sort by and/or to group by etc.
		# And even add a pie chart. And finally save template editing results to a file.
		# This class interacts havily with 'LSS_Zone_List' class, which contains
		# list generation dialog where it is possible to choose existing template and generate
		# a list.
		
		class LSS_Zone_List_Template
			# Name of list template
			attr_accessor :list_name
			# Handle to parent dialog ('List Zones' dialog)
			attr_accessor :parent
			# Hash of settings
			attr_accessor :settings_hash
			
			def initialize
				@list_name=""
				@parent=nil
				@settings_hash=Hash.new
				@charts_arr=Array.new
				
				# Stick dialog height setting. Added in ver. 1.2.1 13-Dec-13.
				@stick_height="true"
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
				Sketchup.write_default("LSS Zone List Template Defaults", "stick_height", @settings_hash["stick_height"][0].to_s)
			end
			
			def read_defaults
				default_value=Sketchup.read_default("LSS Zone List Template Defaults", "stick_height", "true")
				@settings_hash["stick_height"]=[default_value, "boolean"]
				@stick_height=default_value
			end
			
			# This method creates 'List Template' web-dialog.
			
			def create_web_dial
				self.hash2settings # Because we get @settings_hash from parent dialog before launching this method
				# Create the WebDialog instance
				@list_template_dial = UI::WebDialog.new($lsszoneStrings.GetString("List Template"), true, "LSS List Template", 450, 500, 200, 200, true)
				@list_template_dial.min_width=360
				
				# Attach an action callback
				@list_template_dial.add_action_callback("get_data") do |web_dialog,action_name|
					view=Sketchup.active_model.active_view
					if action_name=="save_template"
						@parent.charts_arr=@charts_arr
						self.settings2hash
						@parent.settings_hash=@settings_hash
						@parent.hash2settings
						@parent.save_template
						@parent.refresh
						@list_template_dial.close
					end
					if action_name=="get_settings" # From Ruby to web-dialog
						self.send_settings2dlg
						view.invalidate
					end
					if action_name=="get_zones_data"
						self.settings2hash
						@parent.settings_hash=@settings_hash
						@parent.hash2settings
						@parent.send_zones_data2dlg(@list_template_dial)
					end
					if action_name=="get_fields"
						self.hash2settings
						self.send_fields2dlg(@list_template_dial)
					end
					if action_name=="get_suggest_fields"
						self.send_suggest_fields2dlg
					end
					if action_name=="get_name_aliases"
						@parent.send_name_aliases2dlg(@list_template_dial)
					end
					if action_name=="get_charts"
						@parent.send_charts2dlg(@list_template_dial)
					end
					if action_name.split(",")[0]=="obtain_name_alias" # From web-dialog
						key=action_name.split(",")[1]
						val=action_name.split(",")[2]
						@parent.name_aliases[key]=val
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
							LSS_Zone_Utils.new.adjust_dial_size(@list_template_dial, @cont_height, @cont_width, @d_width, @d_height, @dial_y, @scr_height) if val=="true"
						end
						self.hash2settings
					end
					if action_name.split(",")[0]=="obtain_chart"
						chart_name=action_name.split(",")[1]
						data_field=action_name.split(",")[2]
						legend_field=action_name.split(",")[3]
						chart_hash=Hash.new
						chart_hash["chart_name"]=chart_name
						chart_hash["data_field"]=data_field
						chart_hash["legend_field"]=legend_field
						@charts_arr<<chart_hash
					end
					if action_name.split(",")[0]=="query_string"
						@query_string=action_name.split(",")[1]
						if @query_string.nil? or @query_string==""
							@sort_by=""
							@group_by=""
							@sort_dir=""
						else
							fields_cnt=0
							@suggest_field_names.each{|name|
								if @query_string.include?(name)
									fields_cnt+=1
								end
							}
							if fields_cnt==0
								@sort_by=""
								@group_by=""
								@sort_dir=""
							end
						end
						self.settings2hash
					end
					if action_name.split(",")[0]=="sort_by"
						@sort_by=action_name.split(",")[1]
					end
					if action_name.split(",")[0]=="group_by"
						@group_by=action_name.split(",")[1]
					end
					if action_name.split(",")[0]=="sort_dir"
						@sort_dir=action_name.split(",")[1]
					end
					if action_name=="cancel"
						@list_template_dial.close
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
						@list_template_dial.execute_script(js_command) if js_command
						@init_width=@visible_width
						@init_height=@visible_height
						@list_template_dial.set_size(@init_width, @init_height)
						js_command="send_visible_size()"
						@list_template_dial.execute_script(js_command) if js_command
						@d_height=@init_height-@visible_height + @hdr_ftr_height
						@d_width=@init_width-@visible_width
						win_width=@init_width+@d_width
						win_height=@init_height+@d_height
						@list_template_dial.set_size(win_width, win_height)
					end
					if action_name=="adjust_dial_size"
						if @stick_height=="true"
							LSS_Zone_Utils.new.adjust_dial_size(@list_template_dial, @cont_height, @cont_width, @d_width, @d_height, @dial_y, @scr_height)
						end
					end
					# Content size block end
					
					# Dialog style handling. Added in ver. 1.2.1 26-Dec-13.
					if action_name=="get_dial_style"
						dial_style=Sketchup.read_default("LSS Zone Defaults", "dial_style", "standard")
						js_command="get_dial_style('" + dial_style + "')"
						@list_template_dial.execute_script(js_command) if js_command
					end
				end
				resource_dir=LSS_Dirs.new.resource_path
				dial_path="#{resource_dir}/lss_zone/lss_zone_list_template.html"
				@list_template_dial.set_file(dial_path)
				@list_template_dial.show_modal()
				@list_template_dial.set_on_close{
	
				}
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
					if @settings_hash[key][1]=="distance"
						dist_str=Sketchup.format_length(@settings_hash[key][0].to_f).to_s
						setting_pair_str= key.to_s + "|" + dist_str.gsub("'", "*") # Patch to solve js errors problem with feet and inches
					else
						setting_pair_str= key.to_s + "|" + @settings_hash[key][0].to_s
					end
					js_command = "get_setting('" + setting_pair_str + "')" if setting_pair_str
					@list_template_dial.execute_script(js_command) if js_command
				}
			end
			
			# This method sends attribute names, which were found in a @query_string to a web-dialog, which was passed as an argument.
			# 'List Template' dialog also uses an array of attribute names as a sorce of values for selectors:
			# - sort by drop-down list
			# - group by drop-down list
			
			def send_fields2dlg(dial)
				if @query_string.nil? or @query_string==""
					js_command="clear_fields()"
					dial.execute_script(js_command)
					return
				end
				field_names=@query_string.gsub("@", "").split(" ")
				js_command="clear_fields()"
				dial.execute_script(js_command)
				field_names.each{|field_name|
					js_command = "get_field_name('" + field_name + "')"
					dial.execute_script(js_command)
				}
			end
			
			# This method collects all available attribute names from selected zones to a @suggest_field_names array.
			# Then it sends mentioned names to 'List Template' web-dialog.
			# Auto-suggest widget, which is attached to a text field where query string contents are
			# to be entered and edited, uses mentioned above array of attribute names in order to allow picking a certain
			# attribute name from a suggestion list instead of typing it.
			
			def send_suggest_fields2dlg
				selected_zones=@parent.selected_zones
				@suggest_field_names=Array.new
				selected_zones.each{|zone|
					dict=zone.attribute_dictionary("LSS_Zone_Entity")
					dict.each_key{|key|
						if @suggest_field_names.include?(key)==false
							@suggest_field_names<<key
						end
					}
				}
				# Add nested elements names. Added in ver. 1.1.2 10-Nov-13.
				nested_elements_names=@parent.nested_elements_names
				if nested_elements_names
					if nested_elements_names.length>0
						nested_elements_names.each{|elt_name|
							@suggest_field_names<<elt_name
						}
					end
				end
				js_command="clear_suggest_fields()"
				@list_template_dial.execute_script(js_command)
				@suggest_field_names.each{|field_name|
					field_name1="@"+field_name
					js_command = "get_suggest_field_name('" + field_name1 + "')"
					@list_template_dial.execute_script(js_command)
				}
			end
		end #class LSS_Zone_List_Template
	end #module LSS_Zone_Extension
end #module LSS_Extensions	