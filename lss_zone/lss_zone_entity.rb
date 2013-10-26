# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# lss_zone_entity.rb ver. 1.1.0 beta 26-Oct-13
# This file contains the class with Zone Entity

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.


module LSS_Extensions
	module LSS_Zone_Extension
		
		require 'lss_zone/lss_zone_layers.rb'
		
		# The class where generation of zone group in a model is implemented.
		# Usage scenario of this class is:
		# - create an instance
		# - pass all necessary information about new zone through attributes of created instance (using attr_accessor)
		# - call 'create_zone' method of created instance
		
		class LSS_Zone_Entity
			# Identification
			attr_accessor :number
			attr_accessor :name
			# Geometry
			attr_accessor :area
			attr_accessor :perimeter
			attr_accessor :height
			attr_accessor :volume
			# Additional
			attr_accessor :floor_level
			attr_accessor :floor_number
			attr_accessor :category
			attr_accessor :memo
			# Materials
			attr_accessor :floor_material
			attr_accessor :wall_material
			attr_accessor :ceiling_material
			# Elements' Areas
			attr_accessor :floor_area
			attr_accessor :wall_area
			attr_accessor :ceiling_area
			# Elements' Types
			attr_accessor :floor_refno
			attr_accessor :wall_refno
			attr_accessor :ceiling_refno
			# Labels
			attr_accessor :labels_arr
			attr_accessor :default_label
			# Zone type
			attr_accessor :zone_type
			# Box type settings
			attr_accessor :floors_count
			
			# Nodal points
			attr_accessor :nodal_points
			
			# Openings
			attr_accessor :openings_arr
			
			# Result
			attr_accessor :zone_group
			
			def initialize
				# Identification
				@number=001
				@name=$lsszoneStrings.GetString("Room")
				# Geometry
				@area=0
				@perimeter=0
				@height=0
				@volume=0
				# Additional
				@floor_level=0
				@floor_number=0
				@category=""
				@memo=""
				# Nodal points
				@nodal_points=nil
				# Openings
				@openings_arr=Array.new
				# Materials
				@floor_material=nil
				@wall_material=nil
				@ceiling_material=nil
				# Elements' Areas
				@floor_area=0
				@wall_area=0
				@ceiling_area=0
				@wall_ext_ops_area=0
				@wall_int_ops_area=0
				@floor_ext_ops_area=0
				@floor_int_ops_area=0
				@ceiling_ext_ops_area=0
				@ceiling_int_ops_area=0
				# Elements' Types
				@floor_refno=""
				@wall_refno=""
				@ceiling_refno=""
				# Labels
				@default_label=["Default Label", "@number\n@area", "LSS Zone Label"]
				@labels_arr=[@default_label]
				# Zone type
				@zone_type="room"
				# Box type settings
				@floors_count=1
			
				@model=Sketchup.active_model
				@entities=@model.active_entities
			end
			
			# This is a main method, which generates zone group in an active model
			
			def create_zone(stand_alone=true)
				# If stand_alone==false, then method is called from another @model.start_operation
				if @nodal_points.length==0
					UI.messagebox($lsszoneStrings.GetString("There is no nodal points to create zone object from..."))
					return
				end
				
				self.clear_dups
				self.ensure_planar # Added in ver. 1.1.0 26-Oct-13
				
				# lss_zone_layer
				# area_layer
				# wall_layer
				# floor_layer
				# ceiling_layer
				# volume_layer
				@zone_layers=LSS_Zone_Layers.new
				
				if @zone_layers.lss_zone_layer.nil?
					@zone_layers.create_layers
				end
				
				if @zone_type.nil?
					@zone_type="room"
				end
				
				@model.start_operation($lsszoneStrings.GetString("Create Zone"), true) if stand_alone
				# If stand_alone==false, then method is called from another @model.start_operation
				
					@zone_group=@entities.add_group
					@zone_group.layer=@zone_layers.lss_zone_layer
					@floor_level=@nodal_points.first.z
					@ceiling_z=@floor_level.to_f+@height.to_f
					
					# Populate zone with elements
					# Create 'area_element', which represents an area of a the zone
					area_element=LSS_Element_Group.new(@nodal_points, "area", @category, @zone_group)
					area_element.assign_material2group=true
					area_group=area_element.create
					area_group.layer=@zone_layers.area_layer
					@area=area_element.area
					@perimeter=area_element.perimeter
					@volume=@area*(@height.to_f)
					
					if @zone_type=="room"
						# Create 'floor_element'
						floor_element=LSS_Element_Group.new(@nodal_points, "floor", @floor_material, @zone_group)
						floor_group=floor_element.create
						@floor_area=floor_element.area
						floor_group.layer=@zone_layers.floor_layer
						
						# Create 'ceiling_element'
						ceiling_points=Array.new
						@nodal_points.each{|pt|
							ceiling_pt=Geom::Point3d.new(pt.x, pt.y, @ceiling_z)
							ceiling_points<<ceiling_pt
						}
						ceiling_element=LSS_Element_Group.new(ceiling_points, "ceiling", @ceiling_material, @zone_group)
						ceiling_group=ceiling_element.create
						@ceiling_area=ceiling_element.area
						ceiling_group.layer=@zone_layers.ceiling_layer
					end
					
					# Walls and volume may exist only if @height>0. Check added in ver. 1.0.1 beta 08-Oct-13.
					if @height.to_f>0
						if @zone_type=="room"
							# Create wall elements
							@wall_area=0
							for i in 0..@nodal_points.length-1
								pt1=@nodal_points[i-1]
								pt2=@nodal_points[i]
								pt3=Geom::Point3d.new(pt1.x, pt1.y, @ceiling_z)
								pt4=Geom::Point3d.new(pt2.x, pt2.y, @ceiling_z)
								wall_points=[pt1, pt2, pt4, pt3]
								wall_element=LSS_Element_Group.new(wall_points, "wall", @wall_material, @zone_group)
								wall_group=wall_element.create
								wall_group.layer=@zone_layers.wall_layer
								@wall_area+=wall_element.area
							end
						end
						
						if @zone_type!="flat"
							# Create volume element
							volume_element=LSS_Volume_Group.new(@nodal_points, @height, @category, @zone_group)
							volume_group=volume_element.create
							volume_group.layer=@zone_layers.volume_layer
						end
					end
					
					if @zone_type=="room"
						# Create openings
						@openings_arr.each{|opening|
							pts=opening["points"].uniq
							if pts.is_a?(Array)
								if pts.length>2
									op_type=opening["type"]
									is_internal=opening["is_internal"]
									link_time=opening["link_time"]
									opening_element=LSS_Element_Group.new(pts, op_type, nil, @zone_group)
									opening_group=opening_element.create
									opening_area=opening_element.area
									opening_group.layer=@zone_layers.openings_layer
									opening_group.set_attribute("LSS_Zone_Element", "is_internal", is_internal)
									opening_group.set_attribute("LSS_Zone_Element", "link_time", link_time)
									# It is necessary to store information about zone's floor level because
									# openings have to be rebuilded relatively to it (in case of rebuilding).
									opening_group.set_attribute("LSS_Zone_Element", "floor_level", @floor_level)
									case op_type
										when "wall_opening"
										@wall_area-=opening_area
										if is_internal
											@wall_int_ops_area+=opening_area
										else
											@wall_ext_ops_area+=opening_area
										end
										when "floor_opening"
										@floor_area-=opening_area
										if is_internal
											@floor_int_ops_area+=opening_area
										else
											@floor_ext_ops_area+=opening_area
										end
										when "ceiling_opening"
										@ceiling_area-=opening_area
										if is_internal
											@ceiling_int_ops_area+=opening_area
										else
											@ceiling_ext_ops_area+=opening_area
										end
									end
								end
							end
						}
					end
					
					# Store attributes
					# Identity
					@zone_group.set_attribute("LSS_Zone_Entity", "number", @number)
					@zone_group.set_attribute("LSS_Zone_Entity", "name", @name)
					@zone_group.set_attribute("LSS_Zone_Entity", "category", @category)
					# Geometry
					@zone_group.set_attribute("LSS_Zone_Entity", "area", @area)
					@zone_group.set_attribute("LSS_Zone_Entity", "perimeter", @perimeter)
					if @zone_type!="flat"
						@zone_group.set_attribute("LSS_Zone_Entity", "height", @height)
						@zone_group.set_attribute("LSS_Zone_Entity", "volume", @volume)
					end
					if @zone_type=="room"
						@zone_group.set_attribute("LSS_Zone_Entity", "floor_level", @floor_level)
						@zone_group.set_attribute("LSS_Zone_Entity", "floor_number", @floor_number)
					end
					# Misc
					@zone_group.set_attribute("LSS_Zone_Entity", "memo", @memo)
					if @zone_type=="box"
						@zone_group.set_attribute("LSS_Zone_Entity", "floors_count", @floors_count)
					end
					# Materials
					if @zone_type=="room"
						@zone_group.set_attribute("LSS_Zone_Entity", "floor_material", @floor_material)
						@zone_group.set_attribute("LSS_Zone_Entity", "ceiling_material", @ceiling_material)
						@zone_group.set_attribute("LSS_Zone_Entity", "wall_material", @wall_material)
						@zone_group.set_attribute("LSS_Zone_Entity", "floor_area", @floor_area)
						@zone_group.set_attribute("LSS_Zone_Entity", "ceiling_area", @ceiling_area)
						@zone_group.set_attribute("LSS_Zone_Entity", "wall_area", @wall_area)
						@zone_group.set_attribute("LSS_Zone_Entity", "wall_int_ops_area", @wall_int_ops_area)
						@zone_group.set_attribute("LSS_Zone_Entity", "wall_ext_ops_area", @wall_ext_ops_area)
						@zone_group.set_attribute("LSS_Zone_Entity", "floor_int_ops_area", @floor_int_ops_area)
						@zone_group.set_attribute("LSS_Zone_Entity", "floor_ext_ops_area", @floor_ext_ops_area)
						@zone_group.set_attribute("LSS_Zone_Entity", "ceiling_int_ops_area", @ceiling_int_ops_area)
						@zone_group.set_attribute("LSS_Zone_Entity", "ceiling_ext_ops_area", @ceiling_ext_ops_area)
						@zone_group.set_attribute("LSS_Zone_Entity", "floor_refno", @floor_refno)
						@zone_group.set_attribute("LSS_Zone_Entity", "ceiling_refno", @ceiling_refno)
						@zone_group.set_attribute("LSS_Zone_Entity", "wall_refno", @wall_refno)
					end
					@zone_group.set_attribute("LSS_Zone_Entity", "zone_type", @zone_type)

					# Attach Labels
					if @labels_arr.nil?
						@labels_arr=[@default_label]
					end
					if @labels_arr.length==0
						@labels_arr=[@default_label]
					end
					layer_names=Array.new
					layers=@model.layers
					layers.each{|layer|
						layer_names<<layer.name
					}
					@labels_arr.each{|label|
						preset_name=label[0]
						label_template=label[1]
						label_layer=label[2]
						attr_dict=@zone_group.attribute_dictionary("LSS_Zone_Entity")
						label_txt="#{label_template}"
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
							label_txt.gsub!(attr_name, value.to_s)
						}
						txt_pos=@zone_group.bounds.center
						label_obj=@zone_group.entities.add_text(label_txt, txt_pos)
						if layer_names.include?(label_layer)==false
							layers.add(label_layer)
						end
						label_obj.set_attribute("LSS_Zone_Entity", "label_name", preset_name)
						label_obj.layer=label_layer
						dict_name="zone_label: "+preset_name
						@zone_group.set_attribute(dict_name, "preset_name", preset_name)
						@zone_group.set_attribute(dict_name, "label_template", label_template)
						@zone_group.set_attribute(dict_name, "label_layer", label_layer)
					}
					
					# Assign name to group. Added in ver. 1.1.0 22-Oct-13.
					@zone_group.name="LSS Zone"
					
				@model.commit_operation if stand_alone
				# If stand_alone==false, then method is called from another @model.start_operation
			end
			
			# This method erases duplicated points from @nodal_points array.
			# It is necessary, because sometimes initial @nodal_points array may
			# contain such points and it is not possible to add area, floor or
			# ceiling face using an array of points, which contains duplicated
			# points. Besides duplicated points causes wall elements of zero
			# area.
			
			def clear_dups
				inds2ignore=Array.new
				@nodal_points.each_index{|ind|
					pt=@nodal_points[ind]
					dup_inds=Array.new
					@nodal_points.each_index{|ind1|
						if ind1>ind
							chk_pt=@nodal_points[ind1]
							if chk_pt==pt
								inds2ignore<<ind1
							end
						end
					}
				}
				temp_arr=Array.new
				@nodal_points.each_index{|ind|
					if inds2ignore.include?(ind)==false
						temp_arr<<@nodal_points[ind]
					end
				}
				@nodal_points=temp_arr
			end
			
			def ensure_planar
				@floor_level=@nodal_points.first.z
				@nodal_points.each{|pt|
					pt.z=@floor_level
				}
			end
		end #class LSS_Zone_Entity
		
		# This is a service class, which is used by 'create_zone' method of 'LSS_Zone_Entity' class:
		# 'create_zone' method makes new instance of 'LSS_Element_Group' each time when it is necessary
		# to add new element to a zone group (floor, ceiling, wall etc).
		
		class LSS_Element_Group
			attr_accessor :face_points
			attr_accessor :type								#types: area, floor, wall, ceiling, other
			attr_accessor :zone_group
			attr_accessor :material
			attr_accessor :element_face
			
			attr_accessor :area
			attr_accessor :perimeter
			
			attr_accessor :assign_material2group
			
			def initialize(face_points, type, material, zone_group)
				@face_points=face_points
				@type=type
				@material=material
				@zone_group=zone_group
				@area=0
				@perimeter=0
				@assign_material2group=false
				# Added in ver. 1.1.0 25-Oct-13.
				@zone_layers=LSS_Zone_Layers.new
				if @zone_layers.lss_zone_layer.nil?
					@zone_layers.create_layers
				end
			end
			
			def create
				@element_group=@zone_group.entities.add_group
				@element_face=@element_group.entities.add_face(@face_points.uniq)
				materials=Sketchup.active_model.materials
				if @assign_material2group
					@element_group.material=materials[@material] if @material and @material!=""
				else
					@element_face.material=materials[@material] if @material and @material!=""
				end
				@element_face.set_attribute("LSS_Zone_Element", "type", @type)
				@element_face.layer=@zone_layers.lss_zone_layer # Added in ver. 1.1.0 25-Oct-13.
				@element_group.set_attribute("LSS_Zone_Element", "type", @type)
				
				@area=@element_face.area
				@element_face.edges.each{|edg|
					@perimeter+=edg.length
				}
				# Assign name to the group. Added in ver. 1.1.0 22-Oct-13
				@element_group.name="#{@type} element"
				@element_group
			end
		end #class LSS_Element_Group
		
		# This is a service class, which is used by 'create_zone' method of 'LSS_Zone_Entity' class
		# when it is necessary to add 'volume' element.
		
		class LSS_Volume_Group
			def initialize(floor_face_points, height, material, zone_group)
				@floor_face_points=floor_face_points
				@height=height
				@material=material
				@zone_group=zone_group
				@volume=0
				# Added in ver. 1.1.0 25-Oct-13.
				@zone_layers=LSS_Zone_Layers.new
				if @zone_layers.lss_zone_layer.nil?
					@zone_layers.create_layers
				end
			end
			
			def create
				@element_group=@zone_group.entities.add_group
				bottom_face=@element_group.entities.add_face(@floor_face_points)
				bottom_face.layer=@zone_layers.lss_zone_layer # Added in ver. 1.1.0 26-Oct-13.
				ceiling_points=Array.new
				@floor_face_points.each{|pt|
					top_pt=Geom::Point3d.new(pt.x, pt.y, pt.z+@height.to_f)
					ceiling_points<<top_pt
				}
				top_face=@element_group.entities.add_face(ceiling_points.reverse)
				top_face.layer=@zone_layers.lss_zone_layer # Added in ver. 1.1.0 26-Oct-13.
				for i in 0..@floor_face_points.length-1
					pt1=@floor_face_points[i-1]
					pt2=@floor_face_points[i]
					pt3=ceiling_points[i]
					pt4=ceiling_points[i-1]
					side_face=@element_group.entities.add_face(pt1, pt2, pt3, pt4)
					side_face.layer=@zone_layers.lss_zone_layer # Added in ver. 1.1.0 25-Oct-13.
				end
				materials=Sketchup.active_model.materials
				if @material and @material!=""
					@element_group.material=materials[@material]
				end
				@element_group.set_attribute("LSS_Zone_Element", "type", "volume")
				# Assign name to the group. Added in ver. 1.1.0 22-Oct-13
				@element_group.name="volume element"
				@element_group
			end
		end #class LSS_Volume_Group
	end #module LSS_Zone_Extension
end #module LSS_Extensions