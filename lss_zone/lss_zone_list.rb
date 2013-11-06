# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# lss_zone_list.rb ver. 1.1.1 beta 06-Nov-13
# The file, which contains report generator implementation.
# It generates all or selected zones list in an active model.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		
		require 'lss_zone/lss_zone_list_template.rb'
		
		class LSS_Zone_List_Cmd
			def initialize
				lss_zone_list_cmd=UI::Command.new($lsszoneStrings.GetString("List Zones")){
					LSS_Zone_List.new.list_dial
				}
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=13
					lss_zone_list_cmd.small_icon = "./tb_icons/list_24.png"
					lss_zone_list_cmd.large_icon = "./tb_icons/list_32.png"
				else
					lss_zone_list_cmd.small_icon = "./tb_icons/list_16.png"
					lss_zone_list_cmd.large_icon = "./tb_icons/list_24.png"
				end
				lss_zone_list_cmd.tooltip = $lsszoneStrings.GetString("Select zones, then click to generate a list of selected zones.")
				$lsszoneToolbar.add_item(lss_zone_list_cmd)
				$lsszoneMenu.add_item(lss_zone_list_cmd)
			end
		end #class LSS_Zone_List_Cmd
		
		# This class contains implementation of a dialog for building lists of selected zones.
		
		class LSS_Zone_List
			attr_accessor :settings_hash
			attr_accessor :selected_zones
			attr_accessor :name_aliases
			attr_accessor :charts_arr
			def initialize
				@model=Sketchup.active_model
				@selected_zones=nil
				@query_string=""
				@sort_by=""
				@sort_dir="ascending" #descending
				@group_by=""
				@list_name=""
				
				@settings_hash=Hash.new
				@name_aliases=Hash.new
				@charts_arr=Array.new
			end
			
			def filter_selection
				@selected_zones=Array.new
				if @selection.length==0
					UI.messagebox($lsszoneStrings.GetString("It is necessary to select some zone objects before launching 'List' command."))
				else
					selected_groups=@selection.select{|ent| ent.is_a?(Sketchup::Group)}
					@selected_zones=selected_groups.select{|grp| not(grp.get_attribute("LSS_Zone_Entity", "number").nil?)}
				end
			end
			
			def list_dial
				@selection=@model.selection
				self.filter_selection
				return if @selected_zones.length==0
				i=1
				tot_cnt=@selected_zones.length
				progr_char="|"; rest_char="_"; scale_coeff=1
				progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
				@collected_data=Array.new
				@selected_zones.each{|zone_entity|
					attr_hash=Hash.new
					attr_dict=zone_entity.attribute_dictionary("LSS_Zone_Entity")
					attr_dict.each_key{|key|
						attr_hash[key]=attr_dict[key]
					}
					@collected_data<<attr_hash
					progr_bar.update(i)
					i+=1
					Sketchup.status_text=$lsszoneStrings.GetString("Collecting data: ") + progr_bar.progr_string
				}
				self.create_list_dial
				Sketchup.status_text=$lsszoneStrings.GetString("Data collection complete.")
			end
			
			def run_query
				if @query_string.nil? or @query_string==""
					@query_result=Array.new
					@sort_by=""
					@group_by=""
					self.settings2hash
					return
				end
				
				# Select fields
				i=1
				tot_cnt=@collected_data.length
				progr_char="|"; rest_char="_"; scale_coeff=1
				progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
				js_command = "set_progress_state()"
				@zone_list_dial.execute_script(js_command) if js_command
				count_fields=0
				selected_fields=Array.new
				@collected_data.each{|record|
					new_record=Hash.new
					record.each_key{|key|
						if key!=""
							if @query_string.include?(key)
								new_record[key]=record[key]
								count_fields+=1
							end
						end
					}
					selected_fields<<new_record
					progr_bar.update(i)
					i+=1
					Sketchup.status_text=$lsszoneStrings.GetString("Selecting fields: ") + progr_bar.progr_string
				}
				Sketchup.status_text=$lsszoneStrings.GetString("Selection complete.")
				js_command = "set_default_state()"
				@zone_list_dial.execute_script(js_command) if js_command
				if count_fields==0
					@query_result=Array.new
					@sort_by=""
					@group_by=""
					self.settings2hash
					return
				end
				
				# Sort
				if @sort_by.nil?
					@sort_by=""
				end
				if @sort_by!=""
					if @sort_dir=="ascending"
						begin
							sorted_result=selected_fields.sort { |x,y| x[@sort_by] <=> y[@sort_by] }
						rescue
							sorted_result=Array.new(selected_fields)
						end
					else
						begin
							sorted_result=selected_fields.sort { |x,y| y[@sort_by] <=> x[@sort_by] }
						rescue
							sorted_result=Array.new(selected_fields)
						end
					end
				else
					sorted_result=Array.new(selected_fields)
				end
				
				# Group
				if @group_by.nil?
					@group_by=""
				end
				if @group_by!=""
					grp_by_values=Array.new
					sorted_result.each{|record|
						grp_by_values<<record[@group_by]
					}
					grp_by_values.uniq!
					@query_result=Array.new
					i=1
					tot_cnt=grp_by_values.length
					progr_char="|"; rest_char="_"; scale_coeff=1
					progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
					js_command = "set_progress_state()"
					grp_by_values.each{|grp_val|
						grp_arr=sorted_result.select{|record| record[@group_by]==grp_val}
						new_record=Hash.new
						grp_arr.each{|grp_rec|
							grp_rec.each_key{|key|
								if key==@group_by
									new_record[key]=grp_rec[key]
								else
									if new_record[key].nil?
										new_record[key]=grp_rec[key]
										# Added in ver. 1.0.2 beta 15-Oct-13.
										if key=="floor_level"
											value=grp_rec[key]
											dist_str=Sketchup.format_length(value.to_f).to_s
											value=dist_str
											new_record[key]=value
										end
									else
										# Handling of different grouping cases. Added in ver. 1.0.1 beta 08-Oct-13
										value_type=Sketchup.read_default("LSS Zone Data Types", key)
										case value_type
											when "distance"
												if key!="floor_level"
													new_record[key]=new_record[key].to_f+grp_rec[key].to_f
												else
													value=grp_rec[key]
													dist_str=Sketchup.format_length(value.to_f).to_s
													value=dist_str
													new_record[key]+="; " + value if (new_record[key].include?(value))==false
												end
											when "area"
												new_record[key]+=grp_rec[key]
											when "volume"
												new_record[key]+=grp_rec[key]
											when "string"
												new_record[key]+=", " + grp_rec[key].to_s if (new_record[key].include?(grp_rec[key].to_s))==false
											when "boolean"
												new_record[key]="..."
											else
												new_record[key]+=grp_rec[key]
										end
									end
								end
							}
						}
						@query_result<<new_record
						progr_bar.update(i)
						i+=1
						Sketchup.status_text=$lsszoneStrings.GetString("Grouping: ") + progr_bar.progr_string
					}
					Sketchup.status_text=$lsszoneStrings.GetString("Grouping complete.")
					js_command = "set_default_state()"
					@zone_list_dial.execute_script(js_command) if js_command
				else
					@query_result=Array.new(sorted_result)
				end
				
				# Format Data
				i=1
				tot_cnt=@query_result.length
				progr_char="|"; rest_char="_"; scale_coeff=1
				progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
				js_command = "set_progress_state()"
				@zone_list_dial.execute_script(js_command) if js_command
				@query_result.each{|record|
					record.each_key{|key|
						value=record[key]
						value_type=Sketchup.read_default("LSS Zone Data Types", key)
						case value_type
							when "distance"
								dist_str=Sketchup.format_length(value.to_f).to_s
								value=dist_str
								# Unformat back "floor_level". Added 15-Oct-13.
								if key=="floor_level"
									if @group_by!=""
										value=record[key]
									end
								end
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
						record[key]=value
					}
					progr_bar.update(i)
					i+=1
					Sketchup.status_text=$lsszoneStrings.GetString("Formatting data: ") + progr_bar.progr_string
				}
				Sketchup.status_text=$lsszoneStrings.GetString("Formatting complete.")
				js_command = "set_default_state()"
				@zone_list_dial.execute_script(js_command) if js_command
			end
			
			def create_list_dial
				# Create the WebDialog instance
				@zone_list_dial = UI::WebDialog.new($lsszoneStrings.GetString("List Zones"), true, "LSS List Zones", 450, 500, 200, 200, true)
				@zone_list_dial.min_width=450
				
				# Attach an action callback
				@zone_list_dial.add_action_callback("get_data") do |web_dialog,action_name|
					view=Sketchup.active_model.active_view
					if action_name=="get_settings" # From Ruby to web-dialog
						self.send_settings2dlg
						view.invalidate
					end
					if action_name=="apply_settings"
						self.generate_list
					end
					if action_name=="get_presets"
						self.send_presets2dlg
					end
					if action_name=="get_fields"
						self.send_fields2dlg(@zone_list_dial)
					end
					if action_name=="get_name_aliases"
						self.send_name_aliases2dlg(@zone_list_dial)
					end
					if action_name=="get_charts"
						self.send_charts2dlg(@zone_list_dial)
					end
					if action_name=="get_zones_data"
						self.send_zones_data2dlg(@zone_list_dial)
					end
					if action_name.split(",")[0]=="select_preset"
						@list_name=action_name.split(",")[1]
						self.settings2hash
						self.read_template_from_file
					end
					if action_name.split(",")[0]=="edit_preset"
						@list_name=action_name.split(",")[1]
						self.edit_preset
					end
					if action_name.split(",")[0]=="delete_preset"
						@list_name=action_name.split(",")[1]
						self.delete_preset
					end
					if action_name=="add_preset"
						self.add_preset
					end
					if action_name=="cancel"
						@zone_list_dial.close
					end
				end
				resource_dir=LSS_Dirs.new.resource_path
				dial_path="#{resource_dir}/lss_zone/lss_zone_list.html"
				@zone_list_dial.set_file(dial_path)
				@zone_list_dial.show()
				@zone_list_dial.set_on_close{
					
					# self.write_defaults
					# self.write_presets
					# Sketchup.active_model.select_tool(nil)
				}
			end
			
			def read_template_from_file
				return if @list_name.nil? or @list_name==""
				@preset_file_name=@list_names[@list_name]
				if @preset_file_name.nil?
					@preset_file_name=@list_names[@list_names.keys.first]
				end
				resource_dir=LSS_Dirs.new.resource_path
				presets_dir="#{resource_dir}/list_presets/"
				preset_file=File.open(presets_dir+@preset_file_name, "r")
				obj_block=false
				@name_aliases=Hash.new
				@charts_arr=Array.new
				while (line = preset_file.gets)
					if line.include?("<") and line.include?("</")==false
						obj_block=true
						obj_name=line.gsub(/[<>\n]/, "")
						case obj_name
							when "chart"
							chart_hash=Hash.new
						end
					end
					if line.include?("</")
						obj_block=false
						case obj_name
							when "chart"
							@charts_arr<<chart_hash
						end
					end
					if obj_block and line.include?("<")==false
						key_val=line.split("=")
						key_val[1]=key_val[1].gsub("\n", "") if key_val[1]
						case obj_name
							when "name_aliases"
								@name_aliases[key_val[0]]=key_val[1]
							when "chart"
								chart_hash[key_val[0]]=key_val[1]
						end
					end
					if obj_block==false and line.include?("</")==false
						key_val=line.split("=")
						key_val[1]=key_val[1].gsub("\n", "") if key_val[1]
						@settings_hash[key_val[0]]=[key_val[1], "string"] if key_val[1]
					end
				end
				preset_file.close
				self.hash2settings
			end
			
			def delete_preset
				resource_dir=LSS_Dirs.new.resource_path
				presets_dir="#{resource_dir}/list_presets/"
				file2del_name=nil
				Dir.foreach(presets_dir){|preset_file_name|
					if preset_file_name!="." and preset_file_name!=".."
						begin
							preset_file=File.open(presets_dir+preset_file_name, "r")
							while (line = preset_file.gets)
								key_val=line.split("=")
								if key_val[1]
									key_val[1]=key_val[1].gsub("\n", "")
									if key_val[0]=="list_name"
										if key_val[1].include?(@list_name)
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
				@list_name=""
				@preset_file_name=""
				self.refresh
			end
			
			def edit_preset
				template_inst=LSS_Zone_List_Template.new
				self.read_template_from_file
				template_inst.settings_hash=@settings_hash
				template_inst.parent=self
				template_inst.create_web_dial
			end
			
			def add_preset
				@query_string=""
				@sort_by=""
				@sort_dir="ascending" #descending
				@group_by=""
				@list_name=""
				self.settings2hash
				
				resource_dir=LSS_Dirs.new.resource_path
				presets_dir="#{resource_dir}/list_presets/"
				file_exist=true
				file_no=0
				while file_exist
					file_no_str=file_no.to_s
					file_no_str="0"+file_no_str if file_no_str.length<2
					file_no_str="0"+file_no_str if file_no_str.length<3
					new_file_name="list_"+file_no_str+".lst"
					@preset_file_name=new_file_name
					full_name=presets_dir+new_file_name
					file_exist=File.exist?(full_name)
					if file_exist==false
						new_preset=File.new(full_name, "w")
						const_part=$lsszoneStrings.GetString("New List Template")
						@list_name="#{const_part} #{file_no_str}"
						new_preset.puts("list_name="+@list_name)
						new_preset.close
						@preset_file_name=new_file_name
					end
					file_no+=1
				end
				self.refresh
				self.edit_preset
			end
			
			def send_presets2dlg
				@list_names=Hash.new
				resource_dir=LSS_Dirs.new.resource_path
				presets_dir="#{resource_dir}/list_presets/"
				Dir.foreach(presets_dir){|preset_file_name|
					if preset_file_name!="." and preset_file_name!=".."
						begin
							preset_file=File.open(presets_dir+preset_file_name, "r")
							while (line = preset_file.gets)
								key_val=line.split("=")
								key_val[1]=key_val[1].gsub("\n", "")
								if key_val[0]=="list_name"
									@list_names[key_val[1]]=preset_file_name
									if @list_name=="" or @list_name.nil?
										@list_name=key_val[1]
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
				if @list_names.length>0
					js_command = "clear_presets()"
					@zone_list_dial.execute_script(js_command) if js_command
					@list_names.each_key{|list_name|
						js_command = "get_preset('" + list_name + "')" if list_name
						@zone_list_dial.execute_script(js_command) if js_command
					}
				end
				self.read_template_from_file
			end
			
			def send_fields2dlg(dial)
				if @query_string.nil? or @query_string==""
					self.read_template_from_file
				end
				field_names=@query_string.gsub("@", "").split(" ")
				js_command="clear_fields()"
				dial.execute_script(js_command)
				field_names.each{|field_name|
					js_command = "get_field_name('" + field_name + "')"
					dial.execute_script(js_command)
				}
			end
			
			def send_zones_data2dlg(dial)
				if @query_string.nil? or @query_string==""
					js_command="clear_records()"
					dial.execute_script(js_command)
					return
				end
				field_names=@query_string.gsub("@", "").split(" ")
				self.run_query
				js_command="clear_records()"
				dial.execute_script(js_command)
				i=1
				tot_cnt=@query_result.length
				progr_char="|"; rest_char="_"; scale_coeff=1
				progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
				js_command = "set_progress_state()"
				dial.execute_script(js_command) if js_command
				@query_result.each{|record|
					js_command = "clear_key_val()"
					dial.execute_script(js_command) if js_command
					field_names.each{|field_name|
						escaped_val=record[field_name].to_s.gsub(/\n/, "\\n")
						js_command = "get_key_val('" + "#{field_name}|#{escaped_val}" + "')" if escaped_val
						dial.execute_script(js_command) if js_command
					}
					js_command = "add_record()"
					dial.execute_script(js_command) if js_command
					progr_bar.update(i)
					i+=1
					Sketchup.status_text=$lsszoneStrings.GetString("Sending data: ") + progr_bar.progr_string
				}
				Sketchup.status_text=$lsszoneStrings.GetString("Data sent.")
				js_command = "set_default_state()"
				dial.execute_script(js_command) if js_command
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
					@zone_list_dial.execute_script(js_command) if js_command
				}
			end
			
			def send_name_aliases2dlg(dial)
				js_command="clear_name_aliases()"
				dial.execute_script(js_command) if js_command
				@name_aliases.each_key{|key|
					name_alias_str= key.to_s + "|" + @name_aliases[key]
					js_command = "get_name_alias('" + name_alias_str + "')" if name_alias_str
					dial.execute_script(js_command) if js_command
				}
			end
			
			def send_charts2dlg(dial)
				js_command="clear_charts()"
				dial.execute_script(js_command) if js_command
				@charts_arr.each{|chart_hash|
					chart_name=chart_hash["chart_name"]
					data_field=chart_hash["data_field"]
					legend_field=chart_hash["legend_field"]
					chart_str= chart_name + "," + data_field + "," + legend_field
					js_command = "get_chart('" + chart_str + "')"
					dial.execute_script(js_command)
				}
			end
			
			def settings2hash
				@settings_hash["list_name"]=[@list_name, "string"]
				@settings_hash["sort_by"]=[@sort_by, "string"]
				@settings_hash["group_by"]=[@group_by, "string"]
				@settings_hash["sort_dir"]=[@sort_dir, "string"]
				@settings_hash["query_string"]=[@query_string, "string"]
			end
			
			def hash2settings
				return if @settings_hash.keys.length==0
				@list_name=@settings_hash["list_name"][0]
				@sort_by=@settings_hash["sort_by"][0]
				@group_by=@settings_hash["group_by"][0]
				@sort_dir=@settings_hash["sort_dir"][0]
				@query_string=@settings_hash["query_string"][0]
			end
			
			def refresh
				js_command = "custom_init()"
				@zone_list_dial.execute_script(js_command) if js_command
			end
			
			def save_template
				resource_dir=LSS_Dirs.new.resource_path
				presets_dir="#{resource_dir}/list_presets/"
				preset_file=File.open(presets_dir+@preset_file_name, "w")
				@settings_hash.each_key{|key|
					if @settings_hash[key][0]
						str=key+"="+@settings_hash[key][0]
					else
						str=key+"="
					end
					preset_file.puts(str)
				}
				if @name_aliases.length>0
					preset_file.puts("<name_aliases>")
					@name_aliases.each_key{|key|
						if @name_aliases[key]
							str=key+"="+@name_aliases[key]
						else
							str=key+"="
						end
						preset_file.puts(str)
					}
					preset_file.puts("</name_aliases>")
				end
				if @charts_arr.length>0
					@charts_arr.each{|chart_hash|
						preset_file.puts("<chart>")
						chart_hash.each_key{|key|
							if chart_hash[key]
								str=key+"="+chart_hash[key]
							else
								str=key+"="
							end
							preset_file.puts(str)
						}
						preset_file.puts("</chart>")
					}
				end
				preset_file.close
			end
			
			def generate_list
				title=$lsszoneStrings.GetString("Save List of Zones to HTML File")
				resource_dir=LSS_Dirs.new.resource_path
				default_dir="#{resource_dir}/generated_lists"
				default_name=$lsszoneStrings.GetString("zones_list.html")
				list_path=UI.savepanel(title, default_dir, default_name)
				return if list_path.nil?
				ext_str=list_path.split(".")[1]
				if ext_str.nil? or ext_str==""
					list_path+=".html"
				else
					if ext_str!="html"
						list_path=list_path.split(".")[0]+".html"
					end
				end
				list_file=File.open(list_path, "w")
				list_file.puts("<html>")
					list_file.puts("<head>")
						list_file.puts("<title>#{@list_name}</title>")
						list_file.puts("<meta http-equiv='Content-Type' content='text/html; charset=UTF-8'>")
						list_file.puts("<style type='text/css'>")
								list_file.puts(".list_table")
								list_file.puts("{")
									list_file.puts("border: 1px solid black;")
									list_file.puts("width: 100%;")
									list_file.puts("border-collapse: collapse;")
								list_file.puts("}")
								list_file.puts(".value_cell")
								list_file.puts("{")
									list_file.puts("border: 1px solid black;")
								list_file.puts("}")
								list_file.puts(".header_cell")
								list_file.puts("{")
									list_file.puts("border: 1px solid black;")
									list_file.puts("background: silver;")
								list_file.puts("}")
						list_file.puts("</style>")
					list_file.puts("</head>")
					list_file.puts("<body>")
						list_file.puts("<table class='list_table'>")
							list_file.puts("<caption>")
								list_file.puts(@list_name)
							list_file.puts("</caption>")
							field_names=@query_string.gsub("@", "").split(" ").compact
							list_file.puts("<tr>")
								field_names.each{|field_name|
									list_file.puts("<th class='header_cell'>")
										col_name=@name_aliases[field_name]
										if col_name
											list_file.puts(col_name)
										else
											list_file.puts(field_name)
										end
									list_file.puts("</th>")
								}
							list_file.puts("</tr>")
							self.run_query
							i=1
							tot_cnt=@query_result.length
							progr_char="|"; rest_char="_"; scale_coeff=1
							progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
							js_command = "set_progress_state()"
							@zone_list_dial.execute_script(js_command) if js_command
							@query_result.each{|record|
								list_file.puts("<tr>")
								field_names.each{|field_name|
									list_file.puts("<td class='value_cell'>")
										val=record[field_name]
										list_file.puts(val)
									list_file.puts("</td>")
								}
								list_file.puts("</tr>")
								progr_bar.update(i)
								i+=1
								Sketchup.status_text=$lsszoneStrings.GetString("Saving to a file: ") + progr_bar.progr_string
							}
							Sketchup.status_text=$lsszoneStrings.GetString("Saving complete.")
							js_command = "set_default_state()"
							@zone_list_dial.execute_script(js_command) if js_command
						list_file.puts("</table>")
					list_file.puts("</body>")
				list_file.puts("</html>")
				list_file.close
				status = UI.openURL(list_path)
			end
		end #class LSS_Zone_List

		if( not file_loaded?("lss_zone_list.rb") )
			LSS_Zone_List_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_list.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	