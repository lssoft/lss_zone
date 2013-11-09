# lss_zone_utils.rb ver. 1.1.2 beta 09-Nov-13
# File with some utility classes:
# - LSS_Geom
# - LSS_Math
# - LSS_Progr_Bar
# - LSS_Dirs
# - LSS_Color
# - LSS_Zone_Tools_Observer
# - LSS_Zone_Selection_Observer
# - LSS_Zone_App_Observer

# (C) 2013, Links System Software
# Feedback information
# E-mail1: designer@ls-software.ru
# E-mail2: kirill2007_77@mail.ru (search this e-mail to add skype contact)

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

module LSS_Extensions
	module LSS_Zone_Extension
	
		# This is a class, which contains some geometric calculation methods

		class LSS_Geom

			# Calculate the area of triangle by 3 given vertices
			def calc_triangle_area(pt1,pt2,pt3)
				a=pt1.distance(pt2)
				b=pt2.distance(pt3)
				c=pt3.distance(pt1)
				p=(a+b+c)/2.0
				formula=p*(p-a)*(p-b)*(p-c)
				if formula>0
					Math.sqrt(p*(p-a)*(p-b)*(p-c))
				else
					0
				end
			end

			# Transfer from polar coordinates to cartesian
			def cartesian(r, a_ang, b_ang)
				[r*Math.cos(a_ang)*Math.sin(b_ang), r*Math.sin(a_ang)*Math.sin(b_ang), r*Math.cos(b_ang)]
			end
			
			# Split 2D boundary, which was passed as an array of points, into triangles
			def triangulate_poly(pts)
				poly_pts=pts.uniq
				
				# Check for vertices coincidence
				for i in 0..poly_pts.length-1
					pt1=poly_pts[i]
					for j in 0..poly_pts.length-1
						if j!=i
							pt2=poly_pts[j]
							if pt1==pt2
								return nil
							end
						end
					end
				end
				
				# Check for self intersections
				for i in 0..poly_pts.length-1
					pt1=poly_pts[i]
					pt2=poly_pts[i-1]
					edg1=[pt1, pt2]
					for j in 0..poly_pts.length-1
						if j!=i
							pt3=poly_pts[j]
							pt4=poly_pts[j-1]
							edg2=[pt3, pt4]
							int_pt=Geom.intersect_line_line(edg1, edg2)
							if int_pt
								dist1=pt1.distance(int_pt)
								dist2=pt2.distance(int_pt)
								sum_dist1=dist1+dist2
								dist3=pt3.distance(int_pt)
								dist4=pt4.distance(int_pt)
								sum_dist2=dist3+dist4
								if dist1>0 and dist2>0 and dist3>0 and dist4>0
									if pt1.distance(pt2)==sum_dist1 and pt3.distance(pt4)==sum_dist2
										return nil
									end
								end
							end
						end
					end
				end
				
				# Estimate polygon normal
				# Find a convex vertex (the one with minimal x and y is guaranteed to be convex)
				min_x=Float::MAX
				poly_pts.each{|pt|
					min_x=pt.x if pt.x<min_x
				}
				min_x_pts=Array.new
				poly_pts.each{|pt|
					min_x_pts<<pt if pt.x==min_x
				}
				conv_pt=min_x_pts.min{|a, b| a.y<=>b.y}
				conv_ind=poly_pts.index(conv_pt)
				if conv_ind<poly_pts.length-1
					adj_pt1=poly_pts[conv_ind+1]
					adj_pt2=poly_pts[conv_ind-1]
				else
					adj_pt1=poly_pts[0]
					adj_pt2=poly_pts[conv_ind-1]
				end
				vec1=adj_pt2.vector_to(conv_pt)
				vec2=conv_pt.vector_to(adj_pt1)
				norm=vec1.cross(vec2)
				if norm.length==0
					for i in 1..poly_pts.length-1
						adj_pt2=poly_pts[conv_ind-i]
						vec1=adj_pt2.vector_to(conv_pt)
						norm=vec1.cross(vec2)
						if norm.length>0
							break
						end
					end
				end
				if norm.length==0
					return nil
				end
				triangles=Array.new
				init_len=poly_pts.length
				for j in 0..init_len
					pt1=nil; pt2=nil; pt3=nil
					for i in 0..poly_pts.length-1
						pt1=poly_pts[i]
						pt2=poly_pts[i-1]
						pt3=poly_pts[i+1]
						if pt1 and pt2 and pt3
							triang_pts=[pt1, pt2, pt3]
							tri_area=self.calc_triangle_area(pt1,pt2,pt3)
							if tri_area==0
								triangles<<triang_pts
								poly_pts.delete(pt1)
								break
							else
								# Check triangle orientation
								chk_vec1=pt2.vector_to(pt1)
								chk_vec2=pt1.vector_to(pt3)
								chk_norm=chk_vec1.cross(chk_vec2)
								if chk_norm.length==0
									return nil
								end
								if chk_norm.samedirection?(norm)
									# Check for chord
									chord=[pt1, pt3]
									valid=true
									for ind1 in 0..poly_pts.length-1
										chk_pt=poly_pts[ind1]
										if ind1!=i and ind1!=i+1 and ind1!=i-1
											inside_triang=self.is_inside_triangle?(chk_pt, triang_pts)
											if inside_triang
												valid=false
												break
											end
										end
									end
									if valid
										triangles<<triang_pts
										poly_pts.delete(pt1)
										break
									end
								end
							end
						end
					end
				end
				triangles
			end
			
			# Check if the given point is inside or outside a triangle
			def is_inside_triangle?(pt, pts)
				vec1=pt.vector_to(pts[0])
				vec2=pt.vector_to(pts[1])
				vec3=pt.vector_to(pts[2])
				ang1=vec1.angle_between(vec2)
				ang2=vec2.angle_between(vec3)
				ang3=vec3.angle_between(vec1)
				sum_ang=ang1+ang2+ang3
				if (2.0*(Math::PI)-sum_ang).abs<0.1
					is_inside=true
				else
					is_inside=false
				end
				is_inside
			end
			
			# Return an array of 12 2D points, which lie on a circle r=1.0 and center at [0, 0]
			def circle_pts12
				pt1=[1.0, 0]
				pt2=[0.87, 0.5]
				pt3=[0.5, 0.87]
				pt4=[0, 1.0]
				pt5=[-0.5, 0.87]
				pt6=[-0.87, 0.5]
				pt7=[-1.0, 0]
				pt8=[-0.87, -0.5]
				pt9=[-0.5, -0.87]
				pt10=[0, -1.0]
				pt11=[0.5, -0.87]
				pt12=[0.87, -0.5]
				pts=[pt1, pt2, pt3, pt4, pt5, pt6, pt7, pt8, pt9, pt10, pt11, pt12]
			end
		end #class Lss_Geom
		
		class LSS_Math
			def format_volume(value)
				one_unit=Sketchup.parse_length("1")
				one_cubic_unit=one_unit**3
				volume_in_units=value.to_f/one_cubic_unit
				options=Sketchup.active_model.options
				units_options=options["UnitsOptions"]
				length_precision=units_options["LengthPrecision"]
				volume_rounded=(volume_in_units*(10.0**length_precision)).round.to_f/(10.0**length_precision)
				vol_str=volume_rounded.to_s
				# Decimal separator 
				chk_str=Sketchup.format_length(0.5)
				if chk_str.include?(",")
					vol_str.gsub!(".", ",")
				end
				# Unit suffix
				supress_units=units_options["SuppressUnitsDisplay"]
				if supress_units==false
					area_str=Sketchup.format_area(0.5)
					unit_str=area_str.split(" ")[1]
					sup_cube=["00B3".hex].pack("U")
					vol_str+=" #{unit_str} #{sup_cube}"
				end
				vol_str
			end
			
			def parse_area(area_str) # Added in ver. 1.1.0, 23-Oct-13
				one_unit=Sketchup.parse_length("1")
				one_sq_unit=one_unit**2
				area_in_units=area_str.to_f
				area=area_in_units*one_sq_unit
				area
			end
			
			def parse_volume(volume_str) # Added in ver. 1.1.0, 23-Oct-13
				one_unit=Sketchup.parse_length("1")
				one_cubic_unit=one_unit**3
				volume_in_units=volume_str.to_f
				volume=volume_in_units*one_cubic_unit
				volume
			end
		end #class LSS_Math

		# This is a class, which contains small progress bar string generation

		class LSS_Progr_Bar
			attr_accessor :percents_ready
			attr_accessor :progr_string

			# Read input parameters
			def initialize(tot_cnt,progr_char,rest_char,scale_coeff)
				@scale_coeff=scale_coeff
				@scale_coeff=2 if @scale_coeff==nil or @scale_coeff==0
				if tot_cnt
					@tot_cnt=tot_cnt
					@tot_cnt=1 if @tot_cnt==0
				end
				@progr_char=progr_char
				@rest_char=rest_char
				@percents_ready=0
			end

			# Generate progress bar string using given input parameters
			def update(curr_cnt)
				@curr_cnt=curr_cnt
				@percents_ready=(100*@curr_cnt/(@tot_cnt)).round
				if 100/@scale_coeff-(@percents_ready/@scale_coeff)>= 0
					progr_str=@progr_char*((@percents_ready/@scale_coeff).round)+@rest_char*(100/@scale_coeff-(@percents_ready/@scale_coeff).round)
				else
					progr_str=@progr_char*((100/@scale_coeff).round)
				end
				@progr_string="#{@percents_ready}% #{progr_str}"
			end
		end #class Lss_Progr_Bar
		
		# This is a class whith methods to return some support directory names
		
		class LSS_Dirs
			def resource_path
				resource_dir = File.join( File.dirname(__FILE__), "Resources", Sketchup.get_locale )
				su_ver=Sketchup.version
				if su_ver.split(".")[0].to_i>=14
					chk_path = ("#{resource_dir}/lss_zone.strings").force_encoding("UTF-8")
				else
					chk_path = "#{resource_dir}/lss_zone.strings"
				end
				if File.exists?(chk_path)
					puts "Localized resource file successfully found!"
				else
					resource_dir = File.join( File.dirname(__FILE__), "Resources", Sketchup.get_locale.split("-")[0] )
					chk_path = "#{resource_dir}/lss_zone.strings"
					if su_ver.split(".")[0].to_i>=14
						chk_path = ("#{resource_dir}/lss_zone.strings").force_encoding("UTF-8")
					else
						chk_path = "#{resource_dir}/lss_zone.strings"
					end
					if File.exists?(chk_path)
						puts "Localized resource file successfully found in an alternative location!"
					else
						resource_dir = File.join( File.dirname(__FILE__), "Resources", "en-US" )
						chk_path = "#{resource_dir}/lss_zone.strings"
						if su_ver.split(".")[0].to_i>=14
							chk_path = ("#{resource_dir}/lss_zone.strings").force_encoding("UTF-8")
						else
							chk_path = "#{resource_dir}/lss_zone.strings"
						end
						if File.exists?(chk_path)
							puts "Localized resource file not found. File from 'en-US' folder loaded."
						else
							resource_dir = File.join( File.dirname(__FILE__), "Resources", "en" )
							if su_ver.split(".")[0].to_i>=14
								resource_dir = resource_dir.force_encoding("UTF-8")
							end
							puts "Localized resource file not found. File from 'en' folder loaded."
						end
					end
				end
				resource_dir
			end
		end #class LSS_Dirs
		
		class LSS_Color
			def hsv2rgb(h, s, v)
				h=h/60.0
				i=h.floor
				f = h - i.to_f
				p = v * ( 1.0 - s )
				q = v * ( 1.0 - s * f )
				t = v * ( 1.0 - s * ( 1.0 - f ) )
				case i
					when 0
					r = v
					g = t
					b = p
					when 1
					r = q
					g = v
					b = p
					when 2
					r = p
					g = v
					b = t
					when 3
					r = p
					g = q
					b = v
					when 4
					r = t
					g = p
					b = v
					when 5
					r = v
					g = p
					b = q
				end
				r=(255.0*r).to_i
				g=(255.0*g).to_i
				b=(255.0*b).to_i
				col=[r, g, b]
				col
			end
		end #class LSS_Color
		
		# This class is not in use anywhere for now
		class LSS_Zone_Tools_Observer < Sketchup::ToolsObserver
			def initialize(web_dial)
				@dial=web_dial
				@prev_state=0
			end
			
			def onActiveToolChanged(tools, tool_name, tool_id)
				#~ UI.messagebox("onActiveToolChanged: " + tool_name.to_s)
			end

			def onToolStateChanged(tools, tool_name, tool_id, tool_state)
				#~ 21013 = 3DTextTool
				#~ 21065 = ArcTool
				#~ 21096 = CircleTool
				#~ 21013 = ComponentTool
				#~ 21126 = ComponentCSTool
				#~ 21019 = EraseTool
				#~ 21031 = FreehandTool
				#~ 21525 = ExtrudeTool
				#~ 21126 = SketchCSTool
				#~ 21048 = MoveTool
				#~ 21100 = OffsetTool
				#~ 21074 = PaintTool
				#~ 21095 = PolyTool
				#~ 21041 = PushPullTool
				#~ 21094 = RectangleTool
				#~ 21129 = RotateTool
				#~ 21236 = ScaleTool
				#~ 21022 = SelectionTool
				#~ 21020 = SketchTool
				if tool_id==21236 or tool_id==21048
					if @prev_state==1
						self.handle_tool_change(tool_id)
					end
				end
				@prev_state=tool_state
			end
			
			def handle_tool_change(tool_id)
				# ScaleTool 21236 causes crash
				lss_zone_rebuild=LSS_Zone_Rebuild_Tool.new
				lss_zone_rebuild.tool_nil=false
				lss_zone_rebuild.process_selection
				js_command="refresh_data()"
				@dial.execute_script(js_command)
			end

		end #class LSS_Tools_Observer
		
		# This class contains implementation of selection observer which becomes active, when 'Properties' dialog is opened.
		# This observer sends information about selection changes to 'Properties' dialog, so dialog displays relevant information.
		# 'Filter Zones' dialog also uses this class the same way as 'Properties' dialog.
		
		class LSS_Zone_Selection_Observer < Sketchup::SelectionObserver # Moved to lss_zone_utils.rb in ver. 1.1.0 22-Oct-13.
			def initialize(web_dial)
				@web_dial=web_dial
			end
			
			def onSelectionBulkChange(selection)
				js_command="refresh_data()"
				@web_dial.execute_script(js_command)
				if selection.count>1
					Sketchup.status_text=$lsszoneStrings.GetString("There are ") + selection.count.to_s + $lsszoneStrings.GetString(" entities selected.")
				end
			end
			
			def onSelectionCleared(selection)
				js_command="refresh_data()"
				@web_dial.execute_script(js_command)
				Sketchup.status_text=$lsszoneStrings.GetString("It is necessary to select a zone to view/edit its properties.")
			end
		end #class LSS_Zone_Selection_Observer
		
		# This application observer just closes 'Properties' dialog in case if new model created, another
		# existing model is opened or application is closed.
		# It is necessary to save defaults and what is more important to disable selection observer, which
		# is active while 'Properties' dialog is opened.
		
		class LSS_Zone_App_Observer < Sketchup::AppObserver # Moved to lss_zone_utils.rb in ver. 1.1.0 22-Oct-13.
			def initialize(web_dial)
				@web_dial=web_dial
			end
			def onNewModel(model)
				if @web_dial
					if @web_dial.visible?
						@web_dial.close
					end
				end
			end
			def onQuit()
				if @web_dial
					if @web_dial.visible?
						@web_dial.close
					end
				end
			end
			def onOpenModel(model)
				if @web_dial
					if @web_dial.visible?
						@web_dial.close
					end
				end
			end
		end #class LSS_Zone_App_Observer
		
	end #module LSS_Zone_Extension
end #module LSS_Extensions