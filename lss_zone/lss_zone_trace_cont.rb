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
			attr_accessor :aperture_pts
			attr_accessor :chk_pt
			attr_accessor :init_pt
			attr_accessor :int_pt
			attr_accessor :int_pt_chk_hgt
			attr_accessor :is_tracing
			attr_accessor :is_ready
			def initialize
				@int_pt=Geom::Point3d.new
				@floor_level=@int_pt.z
				@int_pt_chk_hgt=100.0
				@nodal_points=Array.new
				@chk_pt=Geom::Point3d.new(int_pt)
				@chk_pt.z=@floor_level+@int_pt_chk_hgt.to_f
				@init_pt=nil
				@init_ent=nil
				@aperture_size=2.0
				@model=Sketchup.active_model
				@apertrue_pts=Array.new
				@is_tracing=false
				@is_ready=false
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
					@init_pt=Geom::Point3d.new(res[0])
					if @init_ent.is_a?(Sketchup::Face)
						@norm=@init_ent.normal
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
					# Perform checking just for the sake of filling aperture points array
					@move_res=self.check_point(@init_pt, @norm) if @norm
				end
			end
			
			def trace
				@is_ready=false
				return if @norm.nil?
				view=Sketchup.active_model.active_view
				UI.stop_timer(@tracing_timer_id) if @tracing_timer_id
				@is_tracing=false
				self.one_step(true)
				@is_tracing=true
				@tracing_timer_id=UI.start_timer(0, true){
					if @move_res.nil?
						UI.stop_timer(@tracing_timer_id)
						@is_tracing=false
						puts "no intersections"
					else
						self.one_step(false)
					end
					view.invalidate
				}
			end
			
			def one_step(first_step)
				new_res=@move_res[0]
				hit_ray=@move_res[1]
				new_init_vec=hit_ray[1]
				new_init_pt=new_res[0]
				new_ent=new_res[1].last
				if new_ent==@init_ent and new_init_pt.distance(@init_pt)<=@aperture_size and first_step==false
					UI.stop_timer(@tracing_timer_id)
					@is_tracing=false
					@is_ready=true
				end
				if new_ent!=@prev_ent
					if new_ent.is_a?(Sketchup::Face)
						new_norm=new_ent.normal
						new_chk_ang=new_norm.angle_between(new_init_vec)
						if new_chk_ang<Math::PI/2.0
							new_norm.reverse!
						end
						line1=[@prev_init_pt, @prev_norm.cross(@z_vec)]
						line2=[new_init_pt, new_norm.cross(@z_vec)]
						int_pt=Geom.intersect_line_line(line1, line2)
						if int_pt
							nodal_pt=Geom::Point3d.new(int_pt)
						else
							nodal_pt=Geom::Point3d.new(new_init_pt)
						end
						nodal_pt.z=@floor_level
						@nodal_points<<nodal_pt
						@move_res=self.check_point(new_init_pt, new_norm, @prev_ent)
						@prev_init_pt=Geom::Point3d.new(new_init_pt)
						@prev_norm=Geom::Vector3d.new(new_norm)
						@prev_ent=new_ent
					end
				else
					@move_res=self.check_point(new_init_pt, @prev_norm)
					@prev_init_pt=Geom::Point3d.new(new_init_pt)
					nodal_pt=Geom::Point3d.new(new_init_pt)
					nodal_pt.z=@floor_level
					if @nodal_points.length>0
						@nodal_points[@nodal_points.length-1]=nodal_pt
					else
						@nodal_points<<nodal_pt
					end
				end
			end
			
			def check_point(init_pt, norm, prev_ent=nil)
				# Initialize
				vec1=Geom::Vector3d.new(norm)
				vec1.length=@aperture_size/2.0
				vec2=vec1.cross(@z_vec)
				vec2.length=@aperture_size
				vec3=vec1.reverse
				vec3.length=@aperture_size
				vec4=vec2.reverse
				vec5=vec1
				pt1=Geom::Point3d.new(init_pt); pt2=init_pt.offset(vec1); pt3=pt2.offset(vec2); pt4=pt3.offset(vec3); pt5=pt4.offset(vec4)
				@aperture_pts=[pt2, pt3, pt4, pt5]
				ray1=[pt1, vec1]; ray2=[pt2, vec2]; ray3=[pt3, vec3]; ray4=[pt4, vec4]; ray5=[pt5, vec5]
				@rays_arr=[ray1, ray2, ray3, ray4, ray5]
				
				# Move
				final_res=nil
				@rays_arr.each{|ray|
					res=@model.raytest(ray, true)
					if res
						chk_ent=res[1].last
						if chk_ent!=prev_ent
							int_pt=res[0]
							chk_dist=int_pt.distance(ray[0])
							if chk_dist<@aperture_size
								final_res=[res, ray]
								break
							end
						end
					end
				}
				final_res
			end
		end #class LSS_Zone_Trace_Cont
	end #module LSS_Zone_Extension
end #module LSS_Extensions	