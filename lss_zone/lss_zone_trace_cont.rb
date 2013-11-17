# lss_zone_trace_cont.rb ver. 1.2.0 alpha 17-Nov-13
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
			def initialize(int_pt, int_pt_chk_hgt)
				@int_pt=Geom::Point3d.new(int_pt)
				@floor_level=@int_pt.z
				@int_pt_chk_hgt=int_pt_chk_hgt
				@nodal_points=Array.new
				@chk_pt=Geom::Point3d.new(int_pt)
				@chk_pt.z=@floor_level+@int_pt_chk_hgt.to_f
				@init_pt=nil
				@init_ent=nil
				@aperture_size=2.0
				@model=Sketchup.active_model
			end
			
			def stop_tracing
				UI.stop_timer(@tracing_timer_id) if @tracing_timer_id
				puts "tracing cancelled"
			end
			
			def trace
				view=Sketchup.active_model.active_view
				UI.stop_timer(@tracing_timer_id) if @tracing_timer_id
				norm=nil
				z_vec=Geom::Vector3d.new(0,0,1)
				init_vec=Geom::Vector3d.new(1,0,0)
				init_ray=[@chk_pt, init_vec]
				res=@model.raytest(init_ray, true)
				if res
					@init_ent=res[1].last
					@init_pt=Geom::Point3d.new(res[0])
					if @init_ent.is_a?(Sketchup::Face)
						norm=@init_ent.normal
						chk_ang=norm.angle_between(init_vec)
						if chk_ang<Math::PI/2.0
							norm.reverse!
						end
						prev_init_pt=Geom::Point3d.new(@init_pt)
						prev_norm=Geom::Vector3d.new(norm)
						prev_ent=@init_ent
					end
					if norm
						nodal_pt=Geom::Point3d.new(@init_pt)
						nodal_pt.z=@floor_level
						@nodal_points<<nodal_pt
						tracing_spot=LSS_Zone_Tracing_Spot.new(@init_pt, norm, @aperture_size)
						step=0
						@tracing_timer_id=UI.start_timer(0.01, true){
							move_res=tracing_spot.make_move
							if move_res.nil?
								UI.stop_timer(@tracing_timer_id)
								puts "no intersections"
							else
								new_res=move_res[0]
								hit_ray=move_res[1]
								new_init_vec=hit_ray[1]
								new_init_pt=new_res[0]
								new_ent=new_res[1].last
								if new_ent==@init_ent and new_init_pt.distance(@init_pt)<=@aperture_size and step>0
									UI.stop_timer(@tracing_timer_id)
									puts "contour closed"
								end
								if new_ent!=prev_ent
									if new_ent.is_a?(Sketchup::Face)
										new_norm=new_ent.normal
										new_chk_ang=new_norm.angle_between(new_init_vec)
										if new_chk_ang<Math::PI/2.0
											new_norm.reverse!
										end
										line1=[prev_init_pt, prev_norm.cross(z_vec)]
										line2=[new_init_pt, new_norm.cross(z_vec)]
										int_pt=Geom.intersect_line_line(line1, line2)
										if int_pt
											nodal_pt=Geom::Point3d.new(int_pt)
										else
											nodal_pt=Geom::Point3d.new(new_init_pt)
										end
										nodal_pt.z=@floor_level
										@nodal_points<<nodal_pt
										prev_init_pt=Geom::Point3d.new(new_init_pt)
										prev_norm=Geom::Vector3d.new(new_norm)
										prev_ent=new_ent
										tracing_spot=LSS_Zone_Tracing_Spot.new(new_init_pt, new_norm, @aperture_size)
									end
								else
									tracing_spot=LSS_Zone_Tracing_Spot.new(new_init_pt, prev_norm, @aperture_size)
									nodal_pt=Geom::Point3d.new(new_init_pt)
									nodal_pt.z=@floor_level
									# @nodal_points<<nodal_pt
									@nodal_points[@nodal_points.length-1]=nodal_pt
								end
							end
							step+=1
							view.invalidate
						}
					end
				end
			end
		end #class LSS_Zone_Trace_Cont
		
		class LSS_Zone_Tracing_Spot
			def initialize(init_pt, norm, aperture_size)
				@model=Sketchup.active_model
				@aperture_size=aperture_size
				@init_pt=Geom::Point3d.new(init_pt)
				@z_vec=Geom::Vector3d.new(0,0,1)
				vec1=Geom::Vector3d.new(norm)
				vec1.length=@aperture_size/2.0
				vec2=vec1.cross(@z_vec)
				vec2.length=@aperture_size
				vec3=vec1.reverse
				vec3.length=@aperture_size
				vec4=vec2.reverse
				vec5=vec1
				pt1=@init_pt; pt2=@init_pt.offset(vec1); pt3=pt2.offset(vec2); pt4=pt3.offset(vec3); pt5=pt4.offset(vec4)
				ray1=[pt1, vec1]; ray2=[pt2, vec2]; ray3=[pt3, vec3]; ray4=[pt4, vec4]; ray5=[pt5, vec5]
				@rays_arr=[ray1, ray2, ray3, ray4, ray5]
			end
			
			def make_move
				final_res=nil
				@rays_arr.each{|ray|
					res=@model.raytest(ray, true)
					if res
						int_pt=res[0]
						chk_dist=int_pt.distance(ray[0])
						if chk_dist<@aperture_size
							final_res=[res, ray]
							break
						end
					end
				}
				final_res
			end
		end #class LSS_Zone_Tracing_Spot
	end #module LSS_Zone_Extension
end #module LSS_Extensions	