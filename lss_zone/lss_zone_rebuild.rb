# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# lss_zone_rebuild.rb ver. 1.1.1 beta 03-Nov-13
# The file, which contains created zone(s) refreshing implementation

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		#loads class wich contains Zone Entity
		require 'lss_zone/lss_zone_entity.rb'

		class LSS_Zone_Rebuild_Cmd
			def initialize
				lss_zone_rebuild=LSS_Zone_Rebuild_Tool.new
				lss_zone_rebuild_cmd=UI::Command.new($lsszoneStrings.GetString("Rebuild")){
					Sketchup.active_model.select_tool(lss_zone_rebuild)
					lss_zone_rebuild.process_selection
				}
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=13
					lss_zone_rebuild_cmd.small_icon = "./tb_icons/rebuild_24.png"
					lss_zone_rebuild_cmd.large_icon = "./tb_icons/rebuild_32.png"
				else
					lss_zone_rebuild_cmd.small_icon = "./tb_icons/rebuild_16.png"
					lss_zone_rebuild_cmd.large_icon = "./tb_icons/rebuild_24.png"
				end
				lss_zone_rebuild_cmd.tooltip = $lsszoneStrings.GetString("Select zones, then click to rebuild.")
				lss_zone_rebuild_cmd.menu_text=$lsszoneStrings.GetString("Rebuild")
				$lsszoneToolbar.add_item(lss_zone_rebuild_cmd)
				$lsszoneMenu.add_item(lss_zone_rebuild_cmd)
			end
		end #class LSS_Zone_Rebuild_Cmd
		
		# This class contains implementaion of 'Rebuild' tool, which recreates all selected zones 'from scratch' in
		# order to refresh quantitave attributes and make them corresponded to actual geometry or maybe even
		# refresh geometry in order to make it corresponded to quantitave attributes.
		
		class LSS_Zone_Rebuild_Tool
			attr_accessor :recalc_floor_level
			attr_accessor :recalc_height
			attr_accessor :tool_nil
			
			def initialize
				@model=Sketchup.active_model
				@selection=@model.selection
				@recalc_floor_level=true
				@recalc_height=true
				@tool_nil=true
			end
			
			def process_selection(stand_alone=true)
				if @selection.length==0
					UI.messagebox($lsszoneStrings.GetString("It is necessary to select some zone objects before launching 'Rebuild' command."))
				else
					i=1; tot_cnt=@selection.length
					progr_char="|"; rest_char="_"; scale_coeff=1
					progr_bar=LSS_Progr_Bar.new(tot_cnt,progr_char,rest_char,scale_coeff)
					new_zones=Array.new
					@model.start_operation($lsszoneStrings.GetString("Rebuild Zone(s)"), true) if stand_alone
					# If stand_alone==false, then method is called from another @model.start_operation
						@selection.to_a.each{|ent| #to_a was added in order to iterate throug an array instead of collection
							if ent.is_a?(Sketchup::Group)
								number=ent.get_attribute("LSS_Zone_Entity", "number")
								if number
									# Set the second optional parameter to 'false' so 'rebuild' method does not perform '@model.start_operation'
									new_zones<<self.rebuild(ent, false) if (ent.deleted?)==false
								end
							end
							progr_bar.update(i)
							i+=1
							Sketchup.status_text=$lsszoneStrings.GetString("Rebuilding zones: ") + progr_bar.progr_string
						}
						Sketchup.status_text=$lsszoneStrings.GetString("Rebuilding complete.")
						@selection.add(new_zones)
					@model.commit_operation if stand_alone
					# If stand_alone==false, then method is called from another @model.start_operation
					Sketchup.active_model.select_tool(nil) if @tool_nil
				end
			end
			
			def rebuild(zone_group, stand_alone=true)
				@zone_group=zone_group
				return if @zone_group.nil?
				return if @zone_group.deleted?
				@number=@zone_group.get_attribute("LSS_Zone_Entity", "number")
				@name=@zone_group.get_attribute("LSS_Zone_Entity", "name")
				@area=@zone_group.get_attribute("LSS_Zone_Entity", "area")
				@perimeter=@zone_group.get_attribute("LSS_Zone_Entity", "perimeter")
				@height=@zone_group.get_attribute("LSS_Zone_Entity", "height")
				@volume=@zone_group.get_attribute("LSS_Zone_Entity", "volume")
				@floor_level=@zone_group.get_attribute("LSS_Zone_Entity", "floor_level")
				@floor_number=@zone_group.get_attribute("LSS_Zone_Entity", "floor_number")
				@category=@zone_group.get_attribute("LSS_Zone_Entity", "category")
				@memo=@zone_group.get_attribute("LSS_Zone_Entity", "memo")
				@walls_area=@zone_group.get_attribute("LSS_Zone_Entity", "walls_area")
				@floor_material=@zone_group.get_attribute("LSS_Zone_Entity", "floor_material")
				@ceiling_material=@zone_group.get_attribute("LSS_Zone_Entity", "ceiling_material")
				@wall_material=@zone_group.get_attribute("LSS_Zone_Entity", "wall_material")
				@floor_refno=@zone_group.get_attribute("LSS_Zone_Entity", "floor_refno")
				@ceiling_refno=@zone_group.get_attribute("LSS_Zone_Entity", "ceiling_refno")
				@wall_refno=@zone_group.get_attribute("LSS_Zone_Entity", "wall_refno")
				# New properties added in ver. 1.1.0 22-Oct-13.
				@zone_type=@zone_group.get_attribute("LSS_Zone_Entity", "zone_type")
				@floors_count=@zone_group.get_attribute("LSS_Zone_Entity", "floors_count")
				
				@labels_arr=Array.new
				zone_attr_dicts=@zone_group.attribute_dictionaries
				zone_attr_dicts.each{|dict|
					if dict.name.split(":")[0]=="zone_label"
						preset_name=dict["preset_name"]
						label_template=dict["label_template"]
						label_layer=dict["label_layer"]
						@labels_arr<<[preset_name, label_template, label_layer]
					end
				}
				
				@nodal_points=Array.new
				@zone_group.entities.each{|ent|
					ent_type=ent.get_attribute("LSS_Zone_Element", "type")
					if	ent_type=="area"
						ent.entities.each{|elt|
							elt_type=elt.get_attribute("LSS_Zone_Element", "type")
							if elt_type=="area"
								verts=elt.outer_loop.vertices
								verts.each{|vrt|
									pt=vrt.position.transform(@zone_group.transformation) # Maybe make transformation optional...
									if @recalc_floor_level==false
										pt.z=@floor_level.to_f
									end
									@nodal_points<<pt
								}
								@floor_level=@nodal_points.first.z if @recalc_floor_level
								break
							end
						}
					end
				}
				if @recalc_height
					# Zone types handling added in ver. 1.1.0 22-Oct-13.
					if @zone_type=="room"
						floor_grp=@zone_group.entities.select{|grp| (grp.get_attribute("LSS_Zone_Element", "type")=="floor")}[0]
						ceiling_grp=@zone_group.entities.select{|grp| (grp.get_attribute("LSS_Zone_Element", "type")=="ceiling")}[0]
						floor_pt=floor_grp.bounds.center
						ceiling_pt=ceiling_grp.bounds.center
						@height=(ceiling_pt.z-floor_pt.z).abs
					end
					if @zone_type=="box"
						max_pt=@zone_group.bounds.max
						min_pt=@zone_group.bounds.min
						@height=max_pt.z-min_pt.z
					end
				end
				
				
				# Read openings
				@openings_arr=Array.new
				ops_groups_arr=Array.new
				@zone_group.entities.each{|grp|
					op_type=grp.get_attribute("LSS_Zone_Element", "type")
					if op_type
						if op_type.include?("opening")
							ops_groups_arr<<grp
						end
					end
				}
				ops_groups_arr.each{|op_grp|
					op_type=op_grp.get_attribute("LSS_Zone_Element", "type")
					op_floor_level=op_grp.get_attribute("LSS_Zone_Element", "floor_level").to_f
					fl_level_delta=@floor_level.to_f-op_floor_level
					fl_level_offset_vec=Geom::Vector3d.new(0, 0, fl_level_delta)
					op_face=op_grp.entities.select{|ent| (ent.is_a?(Sketchup::Face))}[0]
					is_internal=op_grp.get_attribute("LSS_Zone_Element", "is_internal")
					link_time=op_grp.get_attribute("LSS_Zone_Element", "link_time")
					if op_face
						op_pts=Array.new
						op_verts=op_face.outer_loop.vertices
						op_verts.each{|vrt|
							op_pt=vrt.position.transform(op_grp.transformation).transform(@zone_group.transformation)
							if @recalc_floor_level==false
								op_pts<<op_pt.offset(fl_level_offset_vec)
							else
								op_pts<<op_pt
							end
						}
						op_hash=Hash.new
						op_hash["type"]=op_type
						op_hash["points"]=op_pts
						op_hash["is_internal"]=is_internal
						op_hash["link_time"]=link_time
						@openings_arr<<op_hash
					end
				}
				
				# Read custom attributes attached to a zone if any and store to a dicts_hash
				attr_dicts=@zone_group.attribute_dictionaries
				dicts_hash=Hash.new
				attr_dicts.each{|dict|
					setting_hash=Hash.new
					dict.each_key{|key|
						val=dict[key]
						setting_hash[key]=val
					}
					dicts_hash[dict.name]=setting_hash
				}
				
				zone_was_selected=false
				zone_was_selected=true if @selection.include?(@zone_group)
				@selection.remove(@zone_group) if zone_was_selected
				
				# Double check if something wrong with @zone_group
				return if @zone_group.nil?
				return if @zone_group.deleted?
				@model.start_operation($lsszoneStrings.GetString("Rebuild Zone"), true) if stand_alone
				# If stand_alone==false, then method is called from another @model.start_operation
					@zone_group.erase!
					
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
					@zone_entity.floors_count=@floors_count # Added in ver. 1.1.0 22-Oct-13
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
					# Zone Type
					@zone_entity.zone_type=@zone_type # Added in ver. 1.1.0 22-Oct-13
					
					# If the optional parameter==false, then "create_zone" method does not perform @model.start_operation
					@zone_entity.create_zone(false)
					new_zone_group=@zone_entity.zone_group
					
					# Attach back custom attributes to a new_zone_group
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
				@model.commit_operation if stand_alone
				# If stand_alone==false, then method is called from another @model.start_operation
				
				#Return created zone group
				new_zone_group
			end
			
			
		end #class LSS_Zone_Rebuild_Tool

		if( not file_loaded?("lss_zone_rebuild.rb") )
			LSS_Zone_Rebuild_Cmd.new
		end
		#-----------------------------------------------------------------------------
		file_loaded("lss_zone_rebuild.rb")
	end #module LSS_Zone_Extension
end #module LSS_Extensions	