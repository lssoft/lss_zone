# lss_zone_trace_cont.rb ver. 1.2.0 alpha 24-Nov-13
# The script, which contains a class with contour tracing implementation.

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
		
		# This class contains contour tracing implementaion.
		
		class LSS_Zone_Trace_Cont
			attr_accessor :nodal_points
			attr_accessor :aperture_pts
			attr_accessor :openings_arr
			
			attr_accessor :room_height
			attr_accessor :int_pt_chk_hgt
			attr_accessor :aperture_size
			attr_accessor :min_wall_offset
			attr_accessor :op_trace_offset
			attr_accessor :trace_openings
			attr_accessor :use_materials
			
			attr_accessor :chk_pt
			attr_accessor :init_pt
			attr_accessor :int_pt
			
			attr_accessor :is_tracing
			attr_accessor :is_ready
			
			attr_accessor :norm
			attr_accessor :wall_mat
			
			def initialize
				@model=Sketchup.active_model
				
				@int_pt=Geom::Point3d.new
				@floor_level=@int_pt.z
				
				@int_pt_chk_hgt=100.0
				@room_height=nil
				@aperture_size=4.0
				@min_wall_offset=5.0
				@op_trace_offset=2.0
				@trace_openings="true"
				@use_materials="true"
				
				@is_tracing=false
				@is_ready=false
				
				@nodal_points=Array.new
				@chk_pt=Geom::Point3d.new(int_pt)
				@chk_pt.z=@floor_level+@int_pt_chk_hgt.to_f
				@init_pt=nil
				@init_ent=nil

				@apertrue_pts=Array.new
				@wall_mat=nil
				@op_faces_arr=Array.new
				@openings_arr=Array.new

				@zone_layers=LSS_Zone_Layers.new
				@wall_layer=@zone_layers.wall_layer
				@openings_layer=@zone_layers.openings_layer
				@volume_layer=@zone_layers.volume_layer
				
				@z_vec=Geom::Vector3d.new(0,0,1)
				@init_vec=Geom::Vector3d.new(1,0,0)
			end
			
			def stop_tracing
				UI.stop_timer(@tracing_timer_id) if @tracing_timer_id
				@is_tracing=false
				@is_ready=true
				puts "tracing cancelled"
			end
			
			def init_check
				if @room_height==nil
					@room_height=@int_pt_chk_hgt
				end
				@wall_visibility=@wall_layer.visible? if @wall_layer
				@openings_visibility=@openings_layer.visible? if @openings_layer
				@volume_visibility=@volume_layer.visible? if @volume_layer
				@wall_layer.visible=false if @wall_layer
				@openings_layer.visible=false if @openings_layer
				@volume_layer.visible=false if @volume_layer
				@openings_arr=Array.new if trace_openings=="true"
				@op_faces_arr=Array.new
				@is_ready=false
				@chk_pt=Geom::Point3d.new(@int_pt)
				@floor_level=@int_pt.z
				@chk_pt.z=@floor_level+@int_pt_chk_hgt.to_f
				@nodal_points=Array.new
				@norm=nil
				@init_pt=nil
				@init_ray=[@chk_pt, @init_vec]
				res=@model.raytest(@init_ray, true)
				if res
					@init_ent=res[1].last
					if @init_ent.respond_to?("material")
						@wall_mat=@init_ent.material
					end
					@init_pt=Geom::Point3d.new(res[0])
					if @init_ent.is_a?(Sketchup::Face)
						@norm=@init_ent.normal
						res[1].each{|level|
							if level.respond_to?("transformation")
								@norm.transform!(level.transformation)
							end
						}
						chk_ang=@norm.angle_between(@init_vec)
						if chk_ang<Math::PI/2.0
							@norm.reverse!
						end
						@prev_norm=Geom::Vector3d.new(@norm)
						@prev_ent=@init_ent
					end
				end
				if @init_pt
					nodal_pt=Geom::Point3d.new(@init_pt)
					nodal_pt.z=@floor_level
					@nodal_points<<nodal_pt
					@zone_tracer=LSS_Contour_Tracer.new
					@zone_tracer.init_pt=@init_pt
					@zone_tracer.init_ent=@init_ent
					@zone_tracer.nodal_points=@nodal_points
					@zone_tracer.aperture_size=@aperture_size
					@zone_tracer.z_axis=@z_vec
					@zone_tracer.proj_plane=[@int_pt, @z_vec]
					# Perform checking just for the sake of filling aperture points array
					@move_res=@zone_tracer.check_point(@init_pt, @norm) if @norm
					@aperture_pts=@zone_tracer.aperture_pts
					@zone_tracer.move_res=@move_res
					@zone_tracer.prev_norm=@prev_norm
					@zone_tracer.prev_ent=@prev_ent
				end
			end
			
			def trace
				@pseudo_progr_str=""
				@is_ready=false
				return if @norm.nil?
				view=Sketchup.active_model.active_view
				UI.stop_timer(@tracing_timer_id) if @tracing_timer_id
				@is_tracing=false
				@move_res=@zone_tracer.one_step(true)
				@is_tracing=true
				@tracing_timer_id=UI.start_timer(0, true){
					if @move_res.nil?
						UI.stop_timer(@tracing_timer_id)
						@is_tracing=false
						puts "no intersections"
						# Restore layers visibility
						@wall_layer.visible=@wall_visibility if @wall_layer
						@openings_layer.visible=@openings_visibility if @openings_layer
						@volume_layer.visible=@volume_visibility if @volume_layer
					else
						if @zone_tracer.is_tracing
							@move_res=@zone_tracer.one_step(false)
							@nodal_points=@zone_tracer.nodal_points
							@aperture_pts=@zone_tracer.aperture_pts
							if @trace_openings=="true"
								self.check_for_openings
							end
						else
							UI.stop_timer(@tracing_timer_id)
							@nodal_points=@zone_tracer.nodal_points
							@is_tracing=false
							@is_ready=true
							# Restore layers visibility
							@wall_layer.visible=@wall_visibility if @wall_layer
							@openings_layer.visible=@openings_visibility if @openings_layer
							@volume_layer.visible=@volume_visibility if @volume_layer
						end
					end
					view.invalidate
				}
			end
			
			def hidden_trace
				@pseudo_progr_str=""
				@is_tracing=true
				@move_res=@zone_tracer.one_step(true)
				@is_ready=false
				return if @norm.nil?
				while @zone_tracer.is_tracing
					if @move_res.nil?
						break
					end
					@move_res=@zone_tracer.one_step(false)
					if @trace_openings=="true"
						self.check_for_openings
					end
				end
				@is_ready=true
				# Restore layers visibility
				@wall_layer.visible=@wall_visibility
				@openings_layer.visible=@openings_visibility
				@volume_layer.visible=@volume_visibility if @volume_layer
			end
			
			def check_for_openings
				pt=@move_res[0][0]
				vec=@move_res[1][1]
				len=@op_trace_offset.to_f
				dir_vec=@zone_tracer.prev_norm.cross(@z_vec).reverse
				dir_vec.length=2.0*@aperture_size.to_f
				if vec
					if vec.length>0
						vec.length=len
						chk_pt=pt.offset(vec)
						chk_pt.z=@floor_level.to_f+@room_height.to_f
						# Make an array of init points for openings tracing
						# down_ray may hit more, than one opening so it is necessary to store
						# all hits into an array for further processing.
						openings_init_arr=Array.new
						while chk_pt.z>@floor_level.to_f
							down_ray=[chk_pt, @z_vec.reverse]
							hit_res=@model.raytest(down_ray, true)
							if hit_res
								if hit_res[1].last.is_a?(Sketchup::Face)
									if hit_res[0].z>@floor_level.to_f
										if @op_faces_arr.include?(hit_res[1].last)==false
											empty_test_pt=Geom::Point3d.new(hit_res[0])
											empty_test_pt.z-=@aperture_size.to_f/4.0
											empty_test_vec=@zone_tracer.prev_norm
											empty_test_ray=[empty_test_pt, empty_test_vec]
											empty_test_res=@model.raytest(empty_test_ray, true)
											is_empty=true
											if empty_test_res
												empty_dist=empty_test_res[0].distance(empty_test_pt)
												if empty_dist<@op_trace_offset.to_f+@min_wall_offset.to_f
													is_empty=false
												end
											end
											if is_empty
												@op_faces_arr<<hit_res[1].last
												openings_init_arr<<hit_res
											end
										end
									end
								end
							end
							break if hit_res.nil?
							chk_pt.z=hit_res[0].z if hit_res
						end
						
						# Now process array of hit results
						openings_init_arr.each{|hit_res|
							@op_faces_arr<<hit_res[1].last
							op_hash=Hash.new
							@openings_arr<<op_hash
							op_pts=Array.new
							op_proj_plane=[@zone_tracer.move_res[0][0], @zone_tracer.prev_norm]
							first_pt=hit_res[0].project_to_plane(op_proj_plane)
							op_pts<<first_pt
							op_pts<<first_pt
							op_hash["points"]=op_pts
							# Trace opening
							op_init_ent=hit_res[1].last
							norm=nil
							if op_init_ent.is_a?(Sketchup::Face)
								norm=op_init_ent.normal
								hit_res[1].each{|level|
									if level.respond_to?("transformation")
										norm.transform!(level.transformation)
									end
								}
							end
							
							op_tracer=LSS_Contour_Tracer.new
							op_tracer.nodal_points=op_pts
							op_tracer.init_pt=hit_res[0].offset(dir_vec)
							op_tracer.init_ent=op_init_ent
							op_tracer.aperture_size=@aperture_size
							op_tracer.z_axis=Geom::Vector3d.new(@zone_tracer.prev_norm)
							op_tracer.proj_plane=op_proj_plane
							if norm
								op_move_res=op_tracer.check_point(hit_res[0], norm)
							else
								op_move_res=op_tracer.check_point(hit_res[0], @z_vec.reverse)
							end
							op_tracer.move_res=op_move_res
							op_tracer.prev_norm=norm
							op_tracer.prev_ent=op_init_ent
							
							op_move_res=op_tracer.one_step(true)
							while op_tracer.is_tracing
								op_move_res=op_tracer.one_step(false)
								if op_move_res
									res=op_move_res[0]
									current_hit=res[1].last
									if @op_faces_arr.include?(current_hit)==false
										@op_faces_arr<<current_hit
									end
								else
									break
								end
							end
							op_pts=op_tracer.nodal_points
							op_hash["points"]=op_pts
							@openings_arr[@openings_arr.length-1]=op_hash
						}
					end
				end
			end
		end #class LSS_Zone_Trace_Cont
		
		class LSS_Contour_Tracer
			attr_accessor :nodal_points
			attr_accessor :aperture_size
			attr_accessor :aperture_pts
			attr_accessor :init_pt
			attr_accessor :init_ent
			attr_accessor :tracing_timer_id
			# It is a vector representing normal of aperture plane
			attr_accessor :z_axis
			attr_accessor :move_res
			attr_accessor :is_tracing
			attr_accessor :prev_norm
			attr_accessor :prev_ent
			attr_accessor :proj_plane
			
			def initialize
				@init_pt=nil
				@init_ent=nil
				@aperture_size=4.0
				@model=Sketchup.active_model
				@apertrue_pts=Array.new
				@z_axis=Geom::Vector3d.new(0,0,1) # It is a vector representing normal of aperture plane, can be altered using attribute accessor
				@tracing_timer_id=nil
				@move_res=nil
				@is_tracing=true
				@segm_cnt=0
				@prev_norm=nil
				@prev_ent=nil
				@nodal_points=Array.new
				@pseudo_progr_str=""
				@proj_plane=nil
			end
			
			def one_step(first_step)
				if @move_res.nil?
					@is_tracing=false
					return
				end
				new_res=@move_res[0]
				hit_ray=@move_res[1]
				new_init_vec=hit_ray[1]
				new_init_pt=new_res[0]
				new_ent=new_res[1].last
				
				if new_ent==@init_ent and new_init_pt.distance(@init_pt)<=@aperture_size and first_step==false
					@nodal_points.pop
					@is_tracing=false
					@is_ready=true
					view=Sketchup.active_model.active_view
					view.invalidate
					return @move_res
				end
				
				# Check if new_ent coincides with @prev_ent (lies in the same plane)
				if @prev_init_pt and @prev_norm
					chk_plane=[@prev_init_pt, @prev_norm]
					dist2plane=new_init_pt.distance_to_plane(chk_plane)
					if dist2plane<0.00001
						new_ent=@prev_ent
					end
				end
				
				if new_ent!=@prev_ent
					@segm_cnt+=1
					if new_ent.is_a?(Sketchup::Face)
						new_norm=new_ent.normal
						new_res[1].each{|level|
							if level.respond_to?("transformation")
								new_norm.transform!(level.transformation)
							end
						}
						new_chk_ang=new_norm.angle_between(new_init_vec)
						if new_chk_ang<Math::PI/2.0
							new_norm.reverse!
						end
						line1=[@prev_init_pt, @prev_norm.cross(@z_axis)]
						line2=[new_init_pt, new_norm.cross(@z_axis)]
						begin
							int_pt=Geom.intersect_line_line(line1, line2)
						rescue
							# One of lines has invalid point
							int_pt=Geom::Point3d.new(new_init_pt)
						end
						if int_pt
							nodal_pt=Geom::Point3d.new(int_pt)
						else
							nodal_pt=Geom::Point3d.new(new_init_pt)
						end
						if @proj_plane
							nodal_pt=nodal_pt.project_to_plane(@proj_plane)
						end
						if @nodal_points.include?(nodal_pt)
							@is_tracing=false
							return
						end
						@nodal_points.pop
						@nodal_points<<nodal_pt
						@nodal_points<<nodal_pt
						@move_res=self.check_point(new_init_pt, new_norm, @prev_ent)
						@prev_init_pt=Geom::Point3d.new(new_init_pt)
						@prev_norm=Geom::Vector3d.new(new_norm)
						@prev_ent=new_ent
					else
						# Move half step back, because ray hit an edge
						dir_vec=@prev_norm.cross(@z_vec)
						dir_vec.length=@aperture_size/2.0
						@move_res=self.check_point(new_init_pt.offset(dir_vec.reverse), @prev_norm)
						@prev_init_pt=Geom::Point3d.new(new_init_pt.offset(dir_vec.reverse))
						nodal_pt=Geom::Point3d.new(new_init_pt.offset(dir_vec.reverse))
						if @proj_plane
							nodal_pt=nodal_pt.project_to_plane(@proj_plane)
						end
						if @nodal_points.length>0
							@nodal_points[@nodal_points.length-1]=nodal_pt
						else
							@nodal_points<<nodal_pt
						end
					end
				else
					@move_res=self.check_point(new_init_pt, @prev_norm)
					@prev_init_pt=Geom::Point3d.new(new_init_pt)
					nodal_pt=Geom::Point3d.new(new_init_pt)
					if @proj_plane
						nodal_pt=nodal_pt.project_to_plane(@proj_plane)
					end
					if @nodal_points.length>0
						@nodal_points[@nodal_points.length-1]=nodal_pt
					else
						@nodal_points<<nodal_pt
					end
				end
				@pseudo_progr_str+="_"
				@pseudo_progr_str="" if @pseudo_progr_str.length>20
				Sketchup.status_text=$lsszoneStrings.GetString("Segments traced: ")+@segm_cnt.to_s+" "+@pseudo_progr_str
				@move_res
			end
			
			def check_point(init_pt, norm, prev_ent=nil)
				# Initialize
				@aperture_size=@aperture_size.to_f
				vec1=Geom::Vector3d.new(norm)
				vec1.length=@aperture_size/2.0
				vec2=vec1.cross(@z_axis)
				if vec2.length==0
					return nil
				end
				vec2.length=@aperture_size.to_f
				vec3=vec1.reverse
				vec3.length=@aperture_size
				vec4=vec2.reverse
				vec5=vec1
				pt1=Geom::Point3d.new(init_pt); pt2=init_pt.offset(vec1); pt3=pt2.offset(vec2); pt4=pt3.offset(vec3); pt5=pt4.offset(vec4)
				@aperture_pts=[pt2, pt3, pt4, pt5]
				ray1=[pt1, vec1]; ray2=[pt2, vec2]; ray3=[pt3, vec3]; ray4=[pt4, vec4]; ray5=[pt5, vec5]
				rays_arr=[ray1, ray2, ray3, ray4, ray5]

				final_res=nil
				rays_arr.each{|ray|
					res=@model.raytest(ray, true)
					if res
						int_pt=res[0]
						chk_ent=res[1].last
						if chk_ent!=prev_ent
							chk_dist=int_pt.distance(ray[0])
							if chk_dist<=@aperture_size
								final_res=[res, ray]
								break
							end
						end
					end
				}
				final_res
			end
		end #class LSS_Zone_Tracer
	end #module LSS_Zone_Extension
end #module LSS_Extensions	