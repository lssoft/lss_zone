# lss_zone_trace_cont.rb ver. 1.2.1 beta 03-Jan-14
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
			
			attr_accessor :is_traced
			
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
				@openings_bnds_arr=Array.new			# Accessory array, which is used to check for openings duplication

				@zone_layers=LSS_Zone_Layers.new
				@wall_layer=@zone_layers.wall_layer
				@openings_layer=@zone_layers.openings_layer
				@volume_layer=@zone_layers.volume_layer
				
				@z_vec=Geom::Vector3d.new(0,0,1)
				@init_vec=Geom::Vector3d.new(1,0,0)
				
				@is_traced=false
				@opening_cancelled=false
			end
			
			# This method forcibly stops tracing timer.
			# 'LSS_Zone_Tool' uses this method to stop tracing process after Esc key hit
			
			def stop_tracing
				UI.stop_timer(@tracing_timer_id) if @tracing_timer_id
				@is_tracing=false
				@is_ready=true
				puts "tracing cancelled"
			end
			
			# This method performs initial check of a contour:
			# - hide elements, which may confuse contour tracing
			# - calculate coordinates of @chk_pt (check point) using given @int_pt (internal point) coordinates and given @int_pt_chk_hgt (check height)
			# - perform initial ray test (ray from calculated check point along X axis)
			# - if ray hit some face in an active model, then read material of this face and its normal and store a point where hit took place as @init_pt
			# (zone tool uses obtained material to set as walls material)
			# - if ray hit took place and @init_pt was obtained, then make @zone_tracer instance of LSS_Contour_Tracer class
			
			def init_check
				# Ensure that @room_height is initialized
				# It is necessary to set it equal to @int_pt_chk_hgt in case if it's nil.
				# It might be nil when zone type is 'flat' (since 'flat' type has no height attribute).
				if @room_height==nil
					@room_height=@int_pt_chk_hgt
				end
				
				# Read visibility of wall, openings and volume layers
				@wall_visibility=@wall_layer.visible? if @wall_layer
				@openings_visibility=@openings_layer.visible? if @openings_layer
				@volume_visibility=@volume_layer.visible? if @volume_layer
				
				# Hide wall, openings and volume layers, because elements of those layers may
				# confuse contour tracing process.
				@wall_layer.visible=false if @wall_layer
				@openings_layer.visible=false if @openings_layer
				@volume_layer.visible=false if @volume_layer
				
				# Initialize arrays for openings processing
				if trace_openings=="true"
					@openings_arr=Array.new
					@op_faces_arr=Array.new
					@openings_bnds_arr=Array.new			# Accessory array, which is used to check for openings duplication
				end
				
				# Inform that tracing is not ready yet
				@is_ready=false
				
				# Calculate check point coordinates
				@chk_pt=Geom::Point3d.new(@int_pt)
				@floor_level=@int_pt.z
				@chk_pt.z=@floor_level+@int_pt_chk_hgt.to_f
				
				# Initialize nodal points array
				@nodal_points=Array.new
				@norm=nil
				
				# Initialize first point, from wich zone's contour tracing will begin
				@init_pt=nil
				
				# Make ray parrallel to an active model's X axis, which begins at check point
				@init_ray=[@chk_pt, @init_vec]
				
				# Perform ray test
				res=@model.raytest(@init_ray, true)
				if res
					# Store entity, which was hit by initial ray
					@init_ent=res[1].last
					
					# Set coordinates of an initial point, from wich zone's contour tracing will begin
					@init_pt=Geom::Point3d.new(res[0])
					if @init_ent.is_a?(Sketchup::Face)
						
						# Get normal of a face
						@norm=@init_ent.normal
						
						# Face might be inside several groups and or components, so it is necessary to
						# take in account transformation of all parent entities in order to get normal direction
						# relatively to model context (initially normal direction is relative to first parent of 
						# a face, which was hit by initial ray)
						res[1].each{|level|
							if level.respond_to?("transformation")
								@norm.transform!(level.transformation)
							end
						}
						
						# Adjust normal direction to ensure that it is faced to the side where check point is located
						chk_ang=@norm.angle_between(@init_vec)
						if chk_ang<Math::PI/2.0
							@norm.reverse!
							# Store material, so zone tool may use this material to set as zone's walls material
							if @init_ent.respond_to?("back_material")
								@wall_mat=@init_ent.back_material
							else
								if @init_ent.respond_to?("material")
									@wall_mat=@init_ent.material
								end
							end
						else
							# Store material, so zone tool may use this material to set as zone's walls material
							if @init_ent.respond_to?("material")
								@wall_mat=@init_ent.material
							end
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
			
			# This method performs zone's contour tracing using timer.
			# Zone tool uses this method to show results of tracing process during its performing.
			# Method makes the following basic steps:
			# - make first tracing step
			# - start tracing timer
			# - finish tracing timer, when aperture reaches the initial point
			# - restore layers visibility after tracing finish
			
			def trace
				@is_ready=false
				return if @norm.nil?
				view=Sketchup.active_model.active_view
				
				# Stop previously started timer if any before starting new one
				UI.stop_timer(@tracing_timer_id) if @tracing_timer_id
				@is_tracing=false
				
				# Make first tracing step
				# The reason for indicating first step is that #one_step method always checks if the initial
				# point (the first point at which tracing was started) is inside current aperture position,
				# and stops tracing if so (because it assumes, that contour is closed).
				# But during the first step the initial point is obviously inside aperture position, because aperture
				# starts tracing from this point, so it is necessary to make the first step without mentioned above checking
				# in order to prevent immediate exit from tracing process.
				
				@move_res=@zone_tracer.one_step(true) # Argument is true, so 'one_step' method knows that it is the first step.
				@is_tracing=true
				
				# Start tracing timer.
				# Repeat tracinig procedure until aperture reaches the point where tracing was started (normal scenario) or
				# until some other certain breaks (rescue scenario).
				
				@tracing_timer_id=UI.start_timer(0, true){
					if @move_res.nil?
						# Stop tracing in case if no hits were detected
						UI.stop_timer(@tracing_timer_id)
						@is_tracing=false
						puts "no intersections"
						# Restore layers visibility
						@wall_layer.visible=@wall_visibility if @wall_layer
						@openings_layer.visible=@openings_visibility if @openings_layer
						@volume_layer.visible=@volume_visibility if @volume_layer
					else
						if @zone_tracer.is_tracing
							# Make yet another step of tracing, i.e. move 'aperture' along tracing
							# direction over a distance equal to 'aperture' size and perform
							# intersections checking again.
							@move_res=@zone_tracer.one_step(false)
							# Get nodal points from instance of LSS_Contour_Tracer
							@nodal_points=@zone_tracer.nodal_points
							# Get an array of aperture points (zone tool uses this point to display
							# aperture square during tracing process)
							@aperture_pts=@zone_tracer.aperture_pts
							if @trace_openings=="true"
								# Perform openings tracing
								self.check_for_openings
								if @opening_cancelled
									UI.stop_timer(@tracing_timer_id)
									@nodal_points=@zone_tracer.nodal_points
									@is_tracing=false
									# Restore layers visibility
									@wall_layer.visible=@wall_visibility if @wall_layer
									@openings_layer.visible=@openings_visibility if @openings_layer
									@volume_layer.visible=@volume_visibility if @volume_layer
								end
							end
						else
							# Stop tracing if @zone_tracer tell, that tracing is finished.
							# Normally it happens after aperture reaches the initial point coordinates,
							# i.e. contour appears to be closed.
							UI.stop_timer(@tracing_timer_id)
							@nodal_points=@zone_tracer.nodal_points
							@is_tracing=false
							@is_ready=true
							@is_traced=true if @zone_tracer.tracing_cancelled==false and @opening_cancelled==false
							# Restore layers visibility
							@wall_layer.visible=@wall_visibility if @wall_layer
							@openings_layer.visible=@openings_visibility if @openings_layer
							@volume_layer.visible=@volume_visibility if @volume_layer
						end
					end
					# Invalidate active view in order to display changes of nodal points, array of openings
					# and display aperture at a new position.
					view.invalidate
				}
			end
			
			# This method performs zone's contour tracing using 'while' loop. So tracing process is not observable by
			# a user.
			# Usually #rebuild method of 'LSS_Zone_Rebuild_Tool' class uses #hidden_trace.
			# Basic logic is almost the same as in #trace method:
			# - make first tracing step
			# - run 'while' tracing loop
			# - exit tracing loop, when aperture reaches the initial point
			# - restore layers visibility after tracing finish
			
			def hidden_trace
				return if @norm.nil?
				
				@is_tracing=true
				
				# Make first tracing step
				# The reason for indicating first step is that #one_step method always checks if the initial
				# point (the first point at which tracing was started) is inside current aperture position,
				# and stops tracing if so (because it assumes, that contour is closed).
				# But during the first step the initial point is obviously inside aperture position, because aperture
				# starts tracing from this point, so it is necessary to make the first step without mentioned above checking
				# in order to prevent immediate exit from tracing process.
				@move_res=@zone_tracer.one_step(true)
				@is_ready=false
				
				# Run tracing loop until aperture reaches the point where tracing was started (normal scenario) or
				# until some other certain breaks (rescue scenario).
				nodes_cnt=@zone_tracer.nodal_points.length
				while @zone_tracer.is_tracing
					if @move_res.nil?
						break
					end
					@move_res=@zone_tracer.one_step(false)
					if @trace_openings=="true"
						self.check_for_openings
					end
					if @opening_cancelled
						break
					end
				end
				@is_ready=true
				@is_tracing=false
				@is_traced=true if @zone_tracer.tracing_cancelled==false and @opening_cancelled==false
				# Restore layers visibility
				@wall_layer.visible=@wall_visibility
				@openings_layer.visible=@openings_visibility
				@volume_layer.visible=@volume_visibility if @volume_layer
			end
			
			# This method searches for openings below current aperture position:
			# - grab check point from current zone contour aperture position
			# - offset check point from current aperture position at a wall surface inside a wall at a distance equal to @op_trace_offset
			# - offset check point one step forvard along zone contour tracing direction
			# - set z coordinate of check point equal to room's ceiling z level
			# - make a ray starting in check point directed downwards
			# - make 'openings_init_arr' by checking opening emptiness condition at each intersection of this ray with model's geometry
			# (shoot a ray from a point which is a bit lower (@aperture_size/4.0), than intersection point and
			# 'looks' back normally in a direction of wall's surface, if this ray intersects some geometry in a
			# distance which is greater than @op_trace_offset.to_f+@min_wall_offset.to_f, then emptyness condition
			# is satisfied and intersection result goes to an array of initial openings points 'openings_init_arr')
			# - iterate through 'openings_init_arr' and perform tracing of an opening contour almost the same way
			# as tracing of zone contour using #hidden_trace method, but in a plane that is parallel to a face,
			# wich is currently under zone tracing aperture.
			
			def check_for_openings
				return if @move_res.nil?
				pt=@move_res[0][0]
				vec=@move_res[1][1]
				len=@op_trace_offset.to_f
				dir_vec=@zone_tracer.prev_norm.cross(@z_vec).reverse
				dir_vec.length=2.0*@aperture_size.to_f
				if vec
					if vec.length>0
						vec.length=len
						# Set check point for a vertical ray which will 'look' downwards searching for openings
						chk_pt=pt.offset(vec)
						chk_pt.z=@floor_level.to_f+@room_height.to_f
						
						# Make an array of init points for openings tracing, the point is that
						# down_ray may hit more, than one opening (one opening may be placed above another)
						# so it is necessary to store all hits into an array for further processing.
						openings_init_arr=Array.new
						
						# Each time when ray intersects something in a model, make new ray started from
						# intersection point and perform ray test again.
						# Stop this loop, when start of a ray (chk_pt) drops down lower than tracing zone's floor level
						# (i.e. picked internal point z coordinate).
						while chk_pt.z>@floor_level.to_f
							down_ray=[chk_pt, @z_vec.reverse]
							hit_res=@model.raytest(down_ray, true)
							if hit_res
								if hit_res[1].last.is_a?(Sketchup::Face)

									# Check if intersection is not lower than floor level of currently tracing zone.
									if hit_res[0].z>@floor_level.to_f

										# Perform additional check in order to ensure, that an opening
										# actually has enclosed contour and a contour is not lower, than room's floor level.
										control_shot_ray=[hit_res[0], @z_vec.reverse]
										control_shot_res=@model.raytest(control_shot_ray, true)
										if control_shot_res
											if control_shot_res[0].z<@floor_level.to_f
												break
											end
										else
											break
										end
										
										# Check if result of intersection is already present in an array
										# of faces, which were hit previously (in order to prevent openings
										# duplication). The point is that aperture makes small steps along
										# wall face direction, so ray, which searches for openings, may
										# intersect the same face several times and it is necessary to ignore
										# intersections, which took place after an opening was already processed.
										# Besides during each opening tracing faces, which bounds an opening
										# goes into @op_faces_arr either, so it helps to ignore openings, which
										# were already processed.
										if @op_faces_arr.include?(hit_res[1].last)==false
											
											# Grab a point to test opening emptyness from current ray hit point.
											empty_test_pt=Geom::Point3d.new(hit_res[0])
											
											# Shift emptyness test point a bit lower 
											empty_test_pt.z-=@aperture_size.to_f/4.0
											
											# Emptyness checking ray direction 'looks' towards wall's surface (normally to it).
											empty_test_vec=@zone_tracer.prev_norm
											empty_test_ray=[empty_test_pt, empty_test_vec]
											empty_test_res=@model.raytest(empty_test_ray, true)
											is_empty=true
											if empty_test_res
												empty_dist=empty_test_res[0].distance(empty_test_pt)
												
												# Check distance to intersection result.
												# The point is that wall's surface may have some elements as fascia or
												# some frame around an openings or anything else
												# and at the same time room may have narrow parts, so the practical way to assume
												# what was intersected (part of 'home' wall or surface of another wall) is to set
												# a limit of distance for such intersection.
												# This limit have to be greater than assumable offset of 'home' wall and smaller than
												# or equal to assumable distance between oposite walls.
												if empty_dist.to_f<@op_trace_offset.to_f+@min_wall_offset.to_f
													is_empty=false
												end
											end
											if is_empty

												# Add intersected face to an array of previously intersected faces
												# in order to prevent openings duplication.
												@op_faces_arr<<hit_res[1].last
												
												# Add intersection result to an array of initial points for openings tracing.
												openings_init_arr<<hit_res
											end
										end
									end
								end
							end
							
							# Break loop if there is no any intersections
							break if hit_res.nil?
							chk_pt.z=hit_res[0].z if hit_res
						end
						
						# Now process array of hit results
						openings_init_arr.each{|hit_res|
						
							# Add intersected face to an array of previously intersected faces
							# in order to prevent openings duplication.
							# @op_faces_arr<<hit_res[1].last
							
							# Initialize new opening hash
							op_hash=Hash.new
							@openings_arr<<op_hash
							op_pts=Array.new
							
							# Initialize opening projection plane.
							# It is coincide with a plane of a face currently being traced by zone tracer
							# (i.e. it is a plane of a wall surface, where opening is located).
							op_proj_plane=[@zone_tracer.move_res[0][0], @zone_tracer.prev_norm]
							
							# Initialize first point of an opening
							first_pt=hit_res[0].project_to_plane(op_proj_plane)
							
							# Add first point twice because opening tracer will move the second poind and finally it
							# pops it after tracing finish.
							op_pts<<first_pt
							op_pts<<first_pt
							op_hash["points"]=op_pts
							op_hash["type"]="wall_opening"
							
							# Trace opening
							
							# Get normal of first bounding face of an opening being traced.
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
							
							# Make our opening traces by creating an instance of LSS_Contour_Tracer
							op_tracer=LSS_Contour_Tracer.new
							op_tracer.nodal_points=op_pts
							
							# Offset init point along opening tracing direction in order to
							# move away from opening's corner (usually initial point locates
							# directly near opening's corner, so when tracing process finishes
							# this first corner becomes ignored, because it located inside
							# aperture of the initial point.
							op_tracer.init_pt=hit_res[0].offset(dir_vec)
							op_tracer.init_ent=op_init_ent
							op_tracer.aperture_size=@aperture_size
							
							# Set z axis of opening tracer equal to a normal of a face currently being traced
							# by zone tracer (i.e. normal to a wall surface).
							op_tracer.z_axis=Geom::Vector3d.new(@zone_tracer.prev_norm)
							op_tracer.proj_plane=op_proj_plane
							
							# In case if normal of first face, which bounds an opening is detected, use it as an argument.
							# In case if there was no normal detected (opening search ray hit an edge instead of face),
							# use vector directed oposite to model's z axis.
							if norm
								op_move_res=op_tracer.check_point(hit_res[0], norm)
							else
								op_move_res=op_tracer.check_point(hit_res[0], @z_vec.reverse)
							end
							
							# Set tracer's parameters
							op_tracer.move_res=op_move_res
							op_tracer.prev_norm=norm
							op_tracer.prev_ent=op_init_ent
							
							# Make first step of opening tracing.
							# The reason for indicating first step is that #one_step method always checks if the initial
							# point (the first point at which tracing was started) is inside current aperture position,
							# and stops tracing if so (because it assumes, that contour is closed in such case).
							# But during the first step the initial point is obviously inside aperture position, because aperture
							# starts tracing from this point, so it is necessary to make the first step without mentioned above checking
							# in order to prevent immediate exit from tracing process.
							op_move_res=op_tracer.one_step(true)
							
							# Run tracing loop until aperture reaches the point where tracing was started (normal scenario) or
							# until some other certain breaks (rescue scenario).
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
							if op_tracer.tracing_cancelled
								@opening_cancelled=true
								break
							end
							op_pts=op_tracer.nodal_points
							curr_bnds=Geom::BoundingBox.new
							curr_bnds.add(op_pts)
							not_coincide=true
							if @openings_bnds_arr.length>0
								@openings_bnds_arr.each{|chk_bnds|
									if curr_bnds.min==chk_bnds.min and curr_bnds.max==chk_bnds.max
										not_coincide=false
										break
									end
								}
							end
							if not_coincide
								op_hash["points"]=op_pts
								@openings_arr[@openings_arr.length-1]=op_hash
								@openings_bnds_arr<<curr_bnds
							else
								@openings_arr.delete_at(@openings_arr.length-1)
								puts "Duplicated opening was ignored."
							end
						}
					end
				end
			end
		end #class LSS_Zone_Trace_Cont
		
		class LSS_Contour_Tracer
			# Result of tracing
			attr_accessor :nodal_points
			
			# Size of tracing square aperture
			attr_accessor :aperture_size
			
			# Array of aperture points (parent tool uses it to display current aperture position during tracing process)
			attr_accessor :aperture_pts
			
			# Point, from which to start contour tracing process
			attr_accessor :init_pt
			
			# The initial entity (the initial point is located right on it)
			attr_accessor :init_ent

			# It is a vector representing normal of aperture plane
			attr_accessor :z_axis
			
			# Direct result of current tracing step
			attr_accessor :move_res
			
			# Flag, which shows if tracing is in progress or not
			# (instance of class, which uses tracer in a loop stops a loop immediately in case if @is_tacing==false).
			attr_accessor :is_tracing
			
			# Normal of previously traced face
			attr_accessor :prev_norm
			
			# Previously traced face
			attr_accessor :prev_ent
			
			# Plane where to project nodal points
			# (in case if it is a zone contour tracing, project plane coincides with a horizontal plane of room's floor level;
			# in case if it is an opening contour tracing, project plane coincides with a vertical plane of wall's internal surface)
			attr_accessor :proj_plane
			
			# This flag shows that tracing was cancelled after answering to a question of a warning message for example
			attr_accessor :tracing_cancelled
			
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
				@prev_ent_arr=nil
				@nodal_points=Array.new
				@pseudo_progr_str=""
				@proj_plane=nil
				
				# Segment tracing steps counter (in order to check if it exceeds segments tracing limit, which might happen
				# in case of small aperture size relatively to a size of a contour being traced)
				@segm_step=0
				
				# Limit of tracing steps along one straight segment (to prevent tracing hang during #hidden_trace)
				@segm_tracing_lim=Sketchup.read_default("LSS Zone Defaults", "segm_tracing_lim", 3000)
				@segm_tracing_lim=@segm_tracing_lim.to_i
				if @segm_tracing_lim.nil? or @segm_tracing_lim==0 or @segm_tracing_lim>100000
					@segm_tracing_lim=3000
				end
				
				# Flag to indicate status of warning messagebox.
				# It is used to prevent warning message duplication in case if contour tracer instance
				# is being called from timer (in case of 'while' loop this flag is unnecessary).
				@warn_mb_active=false
				
				@tracing_cancelled=false
			end
			
			# This method performs one tracing step. It has one argument: boolean flag to figure out is it a first tracing step or not.
			# The reason for indicating the first step is that #one_step method always checks if the initial
			# point (the first point at which tracing was started) is inside current aperture position,
			# and stops tracing if so (because it assumes, that contour is closed in such case).
			# But during the first step the initial point is obviously inside aperture position, because aperture
			# starts tracing from this point, so it is necessary to make the first step without mentioned above checking
			# in order to prevent immediate exit from tracing process.
			# Method's sequence:
			# - return if result of previous step is nil (i.e. no intersections with model's geometry detected)
			# 
			
			def one_step(first_step)
			
				# Inform caller, that it is necessary to stop tracing in case if there was no
				# intersections of aperture with model's geometry detected.
				if @move_res.nil?
					@is_tracing=false
					return
				end
				
				# Grab geometric results and previously detected face (or other entity) from previous step
				new_res=@move_res[0]
				hit_ray=@move_res[1]
				new_init_vec=hit_ray[1]
				new_init_pt=new_res[0]
				new_ent=new_res[1].last
				new_ent_arr=new_res[1]
				
				# Initial detection of new boundary face (it might be corrected later in case of geometrical
				# coincidence of planes of newly hitted face and previously hitted face).
				new_face_detected=false
				if new_ent_arr!=@prev_ent_arr and first_step==false
					new_face_detected=true
				end
				
				# Check if aperture reached the initial point on the initial face, where tracing started and inform caller of a method,
				# that it is necessary to stop tracing loop, because contour is closed.
				# Perform this check in case if this is not a very first step of tracing,
				# because if it is a first step, then aperture is obviously near the initial point
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
					if dist2plane<0.00001 # Comparison with zero sometimes may fail because of accuracy.
						new_ent=@prev_ent
						new_face_detected=false # Added in ver. 1.2.1 03-Jan-14.
					end
				end
				
				# Add new nodal point in case if aperture detected a new face on its way along previous bounding face.
				# This situation means, that aperture reached a corner of a room or any other bounding zone, that is
				# being traced.
				if new_face_detected
					@segm_cnt+=1
					
					# Reset segment tracing steps count, since new segment is started
					@segm_step=0
					
					if new_ent.is_a?(Sketchup::Face)
						
						# Grab a normal of newly detected boundary face
						new_norm=new_ent.normal
						
						# Face may be inside groups or components, so it is necessary to
						# take in account transformations of all containers.
						new_res[1].each{|level|
							if level.respond_to?("transformation")
								new_norm.transform!(level.transformation)
							end
						}
						
						# Adjust orientation of a normal so it faces internal bounded space
						new_chk_ang=new_norm.angle_between(new_init_vec)
						if new_chk_ang<Math::PI/2.0
							new_norm.reverse!
						end
						
						# Find precise corner location as an intersection of previous and current
						# tracing directions
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
						
						# Put result of intersection to a project plane
						# (in case if it is a room tracer, project plane is a horizontal plane of room's floor,
						# in case if it is an opening tracer, project plane is a vertical plane of wall's internal surface).
						if @proj_plane
							nodal_pt=nodal_pt.project_to_plane(@proj_plane)
						end
						
						# Check if an array of nodal points already has newly detected contour point in order
						# to insure against infinite loop (it is highly unlikely that such case may ever happen
						# if all settings have adequate values, but this check may be useful for #hidden_trace
						# because there is no way for user to interrupt such tracing).
						if @nodal_points.include?(nodal_pt)
							@is_tracing=false
							return
						end
						
						# Erase current position of an aperture from nodal points array
						@nodal_points.pop
						
						# Add computed result of bounding contour nodal point position twice,
						# because first point will stay,representing new corner of a contour being traced
						# while the second position will move step-by-step along a newly detected tracing direction.
						@nodal_points<<nodal_pt
						@nodal_points<<nodal_pt
						
						# Perform current step of tracing using newly detected initial point and new face normal.
						# Pass previous entity as an argument to #check_point method, so it may process acute angles
						# correctly.
						# The point is that the first thing, which will be most likely intersected by aperture right after
						# detecting of an acute angle is previous bounding face, so it is necessary to send previous
						# intersected entity to #check_point method in order to ignore aperture intersection with it.
						# In case if #check_point will not be aware of previously intersected entity, infinite loop
						# will take place right after acute angle detection.
						if new_ent!=@prev_ent
							@move_res=self.check_point(new_init_pt, new_norm, @prev_ent)
						else
							# Rare situation when new_face_detected is true, but new_ent==@prev_ent.
							# It may take place when bounds made of some copies (instances) of the same component definition
							# (component or a group) so face inside it has the same ID in any instance, that's why
							# new_ent becomes equal to @prev_ent despite the fact of their actual difference.
							# This additional check was added in ver. 1.2.1 03-Jan-14.
							@move_res=self.check_point(new_init_pt, new_norm)
						end
						
						# Refresh information about previous initial point, normal and intersected bounding face
						@prev_init_pt=Geom::Point3d.new(new_init_pt)
						@prev_norm=Geom::Vector3d.new(new_norm)
						@prev_ent=new_ent
						@prev_ent_arr=new_ent_arr
					
					# Hadle (most likely rare) situation, when aperture intersected an edge instead of face.
					else
						# Move half step back, because ray hit an edge
						dir_vec=@prev_norm.cross(@z_axis)
						dir_vec.length=@aperture_size/2.0
						
						# Perform checking again from this back-stepped position
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
					
				# Handle situation, when aperture crossed the same bounding face again.
				# It is actually the most common situation and it means, that aperture just have to
				# make yet another tracing step moving along current tracing direction and
				# continue searching for new bounding face.
				else
					# Increase segment tracing steps count, since aperture made a move along the same bounding segment
					@segm_step+=1

					# Check if segment steps count exceeded limit specified in 'Settings' dialog
					if @segm_step>@segm_tracing_lim
						if @warn_mb_active==false
							@warn_mb_active=true
							warn_str=$lsszoneStrings.GetString("It looks like aperture size is too small for a contour being traced. Contour tracing may take too long.")+"\n"
							warn_str+=$lsszoneStrings.GetString("It is recommended to open 'Settings' dialog and encrease aperture size.")+"\n"
							quest_str=$lsszoneStrings.GetString("Would you like to break tracing at this point for aperture size re-adjustment?")
							answer=UI.messagebox(warn_str+"\n"+quest_str, MB_YESNO)
							if answer==6
								@is_tracing=false
								@tracing_cancelled=true
							end
						end
					end
					
					# Perform checking at a new aperture position.
					@move_res=self.check_point(new_init_pt, @prev_norm)
					
					# Refresh previous initial point (that's how stepping forward along current direction goes on).
					@prev_init_pt=Geom::Point3d.new(new_init_pt)
					
					# Move last nodal point to a new aperture position.
					nodal_pt=Geom::Point3d.new(new_init_pt)
					if @proj_plane
						# If tracing project plane was given through an appropriate attribute accessor,
						# then stick nodal point to it.
						nodal_pt=nodal_pt.project_to_plane(@proj_plane)
					end
					
					# Just to ensure double-check the length of nodal points array
					# and add new point to it in case if it's empty.
					if @nodal_points.length>0
						@nodal_points[@nodal_points.length-1]=nodal_pt
					else
						@nodal_points<<nodal_pt
					end
				end
				
				# Tell that tracing process is going on, by indicating it within Sketchup's status bar.
				@pseudo_progr_str+="_"
				@pseudo_progr_str="" if @pseudo_progr_str.length>20
				Sketchup.status_text=$lsszoneStrings.GetString("Segments traced: ")+@segm_cnt.to_s+" "+@pseudo_progr_str
				
				# Return results of current step.
				@move_res
			end
			
			# This method performs checking for intersections of an aperture with model's geometry at a given initial point.
			# This method requires normal vector of a face, which is currently under aperture (second argument), in order to compute
			# tracing direction.
			# The third argument is optional. Method, which calls #check_point passes information about previous intersected face
			# in order to process acute angles of bounded contour properly.
			# The point is that the first thing, which will be most likely intersected by aperture right after
			# detecting of an acute angle is previous bounding face, so it is necessary to send previous
			# intersected entity to #check_point method in order to ignore aperture intersection with it.
			# In case if #check_point will not be aware of previously intersected entity, infinite loop
			# will take place right after acute angle detection.
			
			def check_point(init_pt, norm, prev_ent=nil)
				# Initialize
				@aperture_size=@aperture_size.to_f
				
				# First vector 'steps' back to a distance equal to a half of aperture size from surface of currently detected bounding face
				vec1=Geom::Vector3d.new(norm)
				vec1.length=@aperture_size/2.0
				
				# Second vector moves along tracing direction to a distance of an aperture size
				vec2=vec1.cross(@z_axis)
				if vec2.length==0
					# Return from method in a rare case of failure of tracing direction computing
					return nil
				end
				vec2.length=@aperture_size.to_f
				
				# Third vector moves directly towards the surface of currently detected face.
				# Most usual scenario is that this ray of aperture will intersect currently detected face again
				# at a point which is offset along tracing direction (i.e. vec2) to a distance equal to an aperture size.
				vec3=vec1.reverse
				vec3.length=@aperture_size
				
				# Forth vector moves back in the direction opposite to a current tracing direction to a distance equal to an aperture size.
				vec4=vec2.reverse
				
				# Last vector moves back to an initial point of an aperture, which is located at a surface of a face where the initial
				# point is located during current tracing step.
				vec5=vec1
				
				# Compute four corner points of aperture square according to previously calculated vectors
				pt1=Geom::Point3d.new(init_pt); pt2=init_pt.offset(vec1); pt3=pt2.offset(vec2); pt4=pt3.offset(vec3); pt5=pt4.offset(vec4)
				@aperture_pts=[pt2, pt3, pt4, pt5]
				
				# Store aperture tracing rays
				ray1=[pt1, vec1]; ray2=[pt2, vec2]; ray3=[pt3, vec3]; ray4=[pt4, vec4]; ray5=[pt5, vec5]
				rays_arr=[ray1, ray2, ray3, ray4, ray5]
				
				# Initialize aperture checking result
				final_res=nil
				
				# Check each stored tracing ray individually
				rays_arr.each{|ray|
					res=@model.raytest(ray, true)
					if res
						int_pt=res[0]
						chk_ent=res[1].last
						# Ensure that current aperture ray didn't intersect previous face
						# (it might take place in an acute angle) in order to avoid infinite loop
						# (jumping of aperture to a previous face, then intersection of a current face again and so on).
						if chk_ent!=prev_ent
							chk_dist=int_pt.distance(ray[0])
							# It is necessary to take in account only those intersections with model geometry,
							# which took place at distance less or equal to an aperture size.
							if chk_dist<=@aperture_size
								final_res=[res, ray]
								break
							end
						end
					end
				}
				
				# Return checking result at a given point.
				final_res
			end
		end #class LSS_Zone_Tracer
	end #module LSS_Zone_Extension
end #module LSS_Extensions	