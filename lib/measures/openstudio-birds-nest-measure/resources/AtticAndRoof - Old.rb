# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

#######################################################
# AtticAndRoofs
#######################################################

def build_roofs_array(idf, model, runner, user_arguments, sql)
	#create roofs array
	roofs = []
	
	#ONLY ROOF SURFACES - Get each surface and get information from each surface that is an attic or roof surface.
	model.getSurfaces.each do |surf|
		# initialize the insulations arrays.
		attic_roof_insulations = []
		attic_floor_insulations = []
		# Skip surfaces that aren't roofs. Ceilings are excluded by the outdoor boundary conditiond
		# Skip anything that are not roofs and ceilings
		next if not surf.surfaceType == 'RoofCeiling'	
		const = surf.construction
		#runner.registerInfo("Construction is #{const}.")  
		# Skip surfaces with no construction. 
		#Question: If there is no construction should we exclude it or assume basic internal design?
		next if const.empty?
		const = const.get
		# Convert construction base to construction
		const = const.to_Construction.get
		#runner.registerInfo("Construction is #{const}.")  
		
		# define construction standards to be used as a filtering mechanism
		construction_stds = const.standardsInformation
		#runner.registerInfo("Construction Standards Information is #{construction_stds}.")  
		
		# Skips everything but Roofs. Assumes construction_stds.intendedSurfaceType.is_initialized. Could error out if its not initialized...
		next if not construction_stds.intendedSurfaceType.to_s.include?('Roof')
		
		# Get the area of the roof surface
		area_m2 = surf.netArea
		#runner.registerInfo("Area is #{area_m2} m2.")  
		# Area (ft2)
		roof_area_ft2 = OpenStudio.convert(area_m2, 'm^2','ft^2').get
		#Get Surface Name
		roof_name = surf.name.get
		#runner.registerInfo("Surface Name is #{roof_name}.")  
		
		# Determine if the surface is an internal or external wall. If its internal, we may have to default the assembly design.
		# Check if the construction has measure tags. If so, then use those. Otherwise interpret the model.
		
		if construction_stds.intendedSurfaceType.is_initialized
			surface_type = construction_stds.intendedSurfaceType.to_s
			#runner.registerInfo("Construction Type = #{surface_type}.")
			if surface_type == 'ExteriorRoof'
				exterior_adjacent_to = 'AMBIENT'
			elsif surface_type == 'AtticRoof'
				exterior_adjacent_to = 'AMBIENT'
			elsif surface_type == 'DemisingRoof'
				exterior_adjacent_to = 'LIVING_SPACE'	
			elsif surface_type == 'GroundContactRoof'
				exterior_adjacent_to = 'GROUND'		
			else
				exterior_adjacent_to = 'OTHER_EXTERIOR_ADJACENT_TO'
			end
		else
			if surf.outsideBoundaryCondition == 'Outdoors'
				exterior_adjacent_to = 'AMBIENT'
			elsif surf.outsideBoundaryCondition == 'Ground' || 'Foundation'
				exterior_adjacent_to = 'GROUND'
			elsif surf.outsideBoundaryCondition == 'Zone' || 'Adiabatic' || 'Surface'
				exterior_adjacent_to = 'LIVING_SPACE'
			else
				exterior_adjacent_to = 'OTHER_EXTERIOR_ADJACENT_TO'
			end	
		end
		#runner.registerInfo("Exterior Adjacent To is #{exterior_adjacent_to}.")
		
		# Calculate pitch of roof surface
		# Use the tilt of the roof surface and convert to pitch value using the formula: tan(tilt)*12=pitch
		radians = surf.tilt.to_s.to_f
		#runner.registerInfo(" Radians = #{radians}.")
		surface_angle = radians * 57.295779513
		#runner.registerInfo(" Roof angle = #{surface_angle}.")	 # Tilt is in radians; 1 radian = 57.295779513 degrees
		pitch = Math.tan(radians) * 12 # pitch is the tangent of the radians multiplied by 12
		#runner.registerInfo(" Roof surface pitch = #{pitch}.")
		
		# Calculate the roof span
		#runner.registerInfo("finding  wall vertices.")
		vertices = surf.vertices
		# Find the distance between 2 points on the same z axis
		length = nil
		width = nil
		x0 = nil
		y0 = nil
		z0 = nil
		# Find the x and y differences
		vertices.each_with_index do |vertex, i|
			#Once the values are populated, skip the rest of the vertices.
			next if length != nil	
			if i == 0
				x0 = vertex.x
				y0 = vertex.y
				z0 = vertex.z
				#runner.registerInfo("Vertices = #{x0}, #{y0}, #{z0}.")
			else 
				if vertex.z == z0
					length = (x0 - vertex.x).abs
					width = (y0 - vertex.y).abs
					#runner.registerInfo("Vertices (m) = #{length}, #{width}.")				
				end
			end
		end
		#runner.registerInfo("Vertices = #{length}, #{width}.")
		#Use x and y differences to calculate the span.
		roof_span_m = Math.sqrt(length**2+width**2)
		roof_span_ft = OpenStudio.convert(roof_span_m, 'm','ft').get
		#runner.registerInfo(" Roof surface span = #{roof_span_ft}.")
		
		# Identify the name of the space for which the roof surface is attached to.
		space = surf.space.get
		roof_attached_to_space = space.name.to_s
		#runner.registerInfo(" Roof surface attached to space #{roof_attached_to_space}.")
		
		# TO DO: Update to get the width and length of the sloped roof surface
		#find roof width
		roof_z_max = -1000000000
		roof_z_min = 1000000000
		#runner.registerInfo("found subsurface vertices.")
		vertices.each do |vertex|
			z = vertex.z
			if z < roof_z_min
				roof_z_min = z
			else next
			end
			if z > roof_z_max
				roof_z_max = z
			else
			end
		end
		#runner.registerInfo("found max and min z vertices.")
		roof_height_m = roof_z_max - roof_z_min
		#runner.registerInfo("wall height = #{wall_height_m}.")
		#Convert to IP
		roof_height_ft = OpenStudio.convert(roof_height_m, 'm','ft').get	
		roof_length_ft = roof_area_ft2 / roof_height_ft
		
		# Get the layers from the construction
		layers = const.layers
		#runner.registerInfo("layers = #{layers}.")
		# Find the main structural layer. This is a function in construction.rb created by NREL
		sl_i = const.structural_layer_index
		
		# Skip and warn if we can't find a structural layer
		if sl_i.nil?
			runner.registerInfo("Cannot find structural layer in wall construction #{const.name}; this construction will not be included in the LCA calculations.  To ensure that the LCA calculations work, you must specify the Standards Information fields in the Construction and its constituent Materials.  Use the CEC2013 enumerations.")  
		next
		end
		
		#Find characteristics of the structural layer using Material Standard Information Measure Tags
		# Assumes a single structural layer. For example, does not capture SIPs manually defined by mutliple layers.
		# These are the tags for the structural layer.
		#roof_type = nil
		
		sli_stds = layers[sl_i].standardsInformation
		
		if sli_stds.standardsCategory.is_initialized
			category = sli_stds.standardsCategory.get.to_s
			#runner.registerInfo("Structural Layer Category = #{category}.")
		end
		if sli_stds.standardsIdentifier.is_initialized
			identifier = sli_stds.standardsIdentifier.get.to_s
			#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
		end
		if sli_stds.compositeFramingMaterial.is_initialized
			frame_mat = sli_stds.compositeFramingMaterial.get.to_s
			#runner.registerInfo("Structural Layer Framing Material = #{frame_mat}.")
		end
		if sli_stds.compositeFramingConfiguration.is_initialized
			frame_config = sli_stds.compositeFramingConfiguration.get.to_s
			#runner.registerInfo("Structural Layer Framing Config = #{frame_config}.")
		end
		if sli_stds.compositeFramingDepth.is_initialized
			frame_depth = sli_stds.compositeFramingDepth.get.to_s
			#runner.registerInfo("Structural Layer Framing Depth = #{frame_depth}.")
		end
		if sli_stds.compositeFramingSize.is_initialized
			frame_size = sli_stds.compositeFramingSize.get.to_s
			#runner.registerInfo("Structural Layer Framing Size = #{frame_size}.")
		end
		if sli_stds.compositeCavityInsulation.is_initialized
			cavity_ins = sli_stds.compositeCavityInsulation.get.to_i
			#runner.registerInfo("Structural Layer Cavity Insulation = #{cavity_ins}.")
		end
		
		# Find interior and exterior layer for the construction to define the finishes
		# Layers from exterior to interior
		il_identifier = nil
		el_identifier = nil
		roof_type = nil
		roof_interior_finish = nil
		vapor_barrier = nil
		air_barrier = false
		
		layers.each_with_index do |layer, i|
			# Skip fenestration, partition, and airwall materials
			layer = layer.to_OpaqueMaterial
			next if layer.empty?
			layer = layer.get
			#runner.registerInfo("layer = #{layer}.")
			if i == 0
				ext_layer = layer
				#runner.registerInfo("exterior layer = #{ext_layer}.")
				el_i_stds = layer.standardsInformation
				if el_i_stds.standardsCategory.is_initialized
					el_category = el_i_stds.standardsCategory.get.to_s
					#runner.registerInfo("Exterior Layer Category = #{el_category}.")
				end
				if el_i_stds.standardsIdentifier.is_initialized
					el_identifier = el_i_stds.standardsIdentifier.get.to_s
					#runner.registerInfo("Exterior Layer Identifier = #{el_identifier}.")
				end				
			else
				int_layer = layer
				#runner.registerInfo("interior layer = #{int_layer}.")
				il_i_stds = layer.standardsInformation
				if il_i_stds.standardsCategory.is_initialized
					il_category = il_i_stds.standardsCategory.get.to_s
					#runner.registerInfo("Interior Layer Category = #{il_category}.")
				end
				if il_i_stds.standardsIdentifier.is_initialized
					il_identifier = il_i_stds.standardsIdentifier.get.to_s
					#runner.registerInfo("Interior Layer Identifier = #{il_identifier}.")
				end
		  end
		end
		#runner.registerInfo("Interior Layer = #{il_identifier}.")
		#runner.registerInfo("Exterior Layer = #{el_identifier}.")
		
		
		# Convert identifiers to interior wall finish and wall siding for exterior walls.		
		# Interior Wall Finish
		# Category could be Bldg Board and Siding - Limited to gypsum board, otherwise its "other"
		if il_identifier != nil
			if il_identifier.include?('Gypsum Board - 1/2 in.') or il_identifier.include?('Gypsum Board - 3/8 in.')
				interior_wall_finish = 'GYPSUM_REGULAR_1_2'
			elsif il_identifier.include?('Gypsum Board - 3/4 in.') or il_identifier.include?('Gypsum Board - 5/8 in.')
				interior_wall_finish = 'GYPSUM_REGULAR_5_8'
			else
				interior_wall_finish = 'OTHER_FINISH'
			end
		else
			interior_wall_finish = 'NONE'
		end
		#runner.registerInfo("Interior Layer Thickness = #{interior_wall_finish}.")
		
		# Roof Type - Shingles, etc.
		# Category could be Bldg Board and Siding or Roofing or Concrete
		# Question: Should we consider CLT option?
		# Currently does not include EXPANDED_POLYSTYRENE_SHEATHING or PLASTIC_RUBBER_SYNTHETIC_SHEETING
		# These are not typical on a house.
		if el_identifier != nil
			if el_identifier.include?('Metal')					# Assumes metal is steel. Currently missing aluminum siding
				roof_type = 'METAL_SURFACING'
			elsif el_identifier.include?('Asphalt') and el_identifier.include?('Shingle')
				roof_type = 'ASPHALT_OR_FIBERGLASS_SHINGLES'
			elsif el_identifier.include?('Wood Shingles') or el_identifier.include?('Woods')
				roof_type = 'WOOD_SHINGLES_OR_SHAKES'
			elsif el_identifier.include?('Shingles')
				roof_type = 'SHINGLES'
			elsif el_identifier.include?('Concrete')
				roof_type = 'CONCRETE_ROOF'
			elsif el_identifier.include?('tile') or el_identifier.include?('Tile') or el_identifier.include?('Slate')
				roof_type = 'SLATE_OR_TILE_SHINGLES'	
			else
				roof_type = 'OTHER_ROOF_TYPE'
			end
		else
			roof_type = 'SHINGLES'
		end
		#runner.registerInfo("Roof Exterior Layer = #{roof_type}.")
		
		#Determine if there is a air barrier or vapor barrier
		# For roofs, this is assumed to be a radiant barrier.
		radiant_barrier = nil
		# Same code as for walls in case we want to expand to specific barrier materials in the future.		
		layers.each_with_index do |layer, i|
			# Skip fenestration, partition, and airwall materials
			layer = layer.to_OpaqueMaterial
			next if layer.empty?
			layer = layer.get
			#runner.registerInfo("layer = #{layer}.")
			barrier_stds = layer.standardsInformation
			if barrier_stds.standardsCategory.is_initialized
				barrier_category = barrier_stds.standardsCategory.get.to_s
				if barrier_category.include?('Building Membrane')
					#runner.registerInfo("Barrier Category = #{barrier_category}.")
					if barrier_stds.standardsIdentifier.is_initialized
						barrier_identifier = barrier_stds.standardsIdentifier.get.to_s
						#runner.registerInfo("Barrier Identifier = #{barrier_identifier}.")
						if barrier_identifier.include?('Vapor')		# Should we add custom identifiers?
							if barrier_identifier.include?('1/16')	# Need to update these values since even 6 mil is too small
								vapor_barrier = 'POLYETHELYNE_3_MIL'
							elsif barrier_identifier.include?('1/8')
								vapor_barrier = 'POLYETHELYNE_3_MIL'
							elsif barrier_identifier.include?('1/4')
								vapor_barrier = 'POLYETHELYNE_6_MIL'
							else
								vapor_barrier = 'PSK' # Default value
							end
						else	
							air_barrier = true
						end
					end				
				end
			end
		end
		#runner.registerInfo("Air Barrier = #{air_barrier}.")
		#runner.registerInfo("Vapor Barrier = #{vapor_barrier}.")
		if air_barrier == true or not vapor_barrier.nil?
			radiant_barrier = true
		else
			radiant_barrier = false
		end	
		
		#Inialize insulations array here because approach to insulation varies by wall type.
		insulations = []
	
		# Define roof framing type based on the measure tags	
		# missing match for ???
		
		# WOOD_STUD Wall Type
		if category.to_s.include?('Wood Framed') # Should only be Wood Framed Rafter Roof
			
			# define the wall type
			rafters_material = 'WOOD_RAFTER'
			
			# define the framing size
			if frame_size == '2x2'
				rafters_size = '_2X2'
			elsif frame_size == '2x3'
				rafters_size = '_2X3'	
			elsif frame_size == '2x4'
				rafters_size = '_2X4'
			elsif frame_size == '2x6'
				rafters_size = '_2X6'
			elsif frame_size == '2x8'
				rafters_size = '_2X8'
			elsif frame_size == '2x10'
				rafters_size = '_2X10'	
			elsif frame_size == '2x12'
				rafters_size = '_2X12'
			elsif frame_size == '2x14'
				rafters_size = '_2X14'
			elsif frame_size == '2x16'
				rafters_size = '_2X16'	
			else
				rafters_size = 'OTHER_SIZE'
			end
			#runner.registerInfo("Rafter Size = #{rafters_size}.")
			
			# define On Center
			#fc = frame_config.get.downcase
			#runner.registerInfo("OC = #{fc}.")
			on_center_in = /(\d+)/.match(frame_config).to_s.to_f
			#runner.registerInfo("OC = #{on_center_in}.")
			
			# Define framing cavity thickness
			if frame_depth == '3_5In'
				cav_thickness = 3.5
			elsif frame_depth == '5_5In'
				cav_thickness = 5.5
			elsif frame_depth == '7_25In'
				cav_thickness = 7.25
			elsif frame_depth == '9_25In'
				cav_thickness = 9.25
			elsif frame_depth == '11_25In'
				cav_thickness = 11.25	
			else
				cav_thickness = nil
			end
			#runner.registerInfo("Cavity Thickness = #{cav_thickness}.")
			
			# define the cavity insulation
			if cavity_ins.nil?
				cav_r_ip = 0
				ins_r_value_per_in = 0
			else
				cav_r_ip = cavity_ins
				#runner.registerInfo("Cavity R Value = #{cav_r_ip}.")
				if not cav_thickness.nil?
					ins_r_value_per_in = cav_r_ip / cav_thickness
				else
					ins_r_value_per_in = nil # If this occurs, there is something wrong.
				end
			end
			#runner.registerInfo("Cavity Insulation R is #{cav_r_ip}.") 
			#runner.registerInfo("Cavity Insulation R per Inch is #{ins_r_value_per_in}.")
			
			# Assume cavity insulation for wood framing is either fiberglass batt or cellulose; are there others to include?
			if not ins_r_value_per_in.nil?
				if ins_r_value_per_in < 0.1
					ins_mat = 'NONE'
				elsif ins_r_value_per_in < 3.6 and ins_r_value_per_in > 0.01
					ins_mat = 'BATT_FIBERGLASS'
				else
					ins_mat = 'LOOSE_FILL_CELLULOSE'
				end
			else
				ins_mat = 'UNKNOWN'
			end
			#runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
			if cav_r_ip > 0
				insulationCav = {
					'insulationMaterial' => ins_mat,
					'insulationThickness' => cav_thickness,
					'insulationNominalRValue' => cav_r_ip,
					'insulationInstallationType' => 'CAVITY',
					'insulationLocation' => 'INTERIOR'
				}
				#runner.registerInfo("Cavity Insulation = #{insulationCav}")
				insulations << insulationCav
			end
			
			concrete_value = {}
			
			clt_values = {}
			
		# Metal Framed Roof Type
		elsif category.to_s.include?('Metal Framed')
			# define the wall type
			rafters_material = 'METAL_RAFTER'
			
			# define the framing size
			if frame_size == '2x2'
				rafters_size = '_2X2'
			elsif frame_size == '2x3'
				rafters_size = '_2X3'	
			elsif frame_size == '2x4'
				rafters_size = '_2X4'
			elsif frame_size == '2x6'
				rafters_size = '_2X6'
			elsif frame_size == '2x8'
				rafters_size = '_2X8'
			elsif frame_size == '2x10'
				rafters_size = '_2X10'	
			elsif frame_size == '2x12'
				rafters_size = '_2X12'
			elsif frame_size == '2x14'
				rafters_size = '_2X14'
			elsif frame_size == '2x16'
				rafters_size = '_2X16'	
			else
				rafters_size = 'OTHER_SIZE'
			end
			#runner.registerInfo("Rafter Size = #{rafters_size}.")
			

			# define On Center
			#fc = frame_config.get.downcase
			#runner.registerInfo("OC = #{fc}.")
			on_center_in = /(\d+)/.match(frame_config).to_s.to_f
			#runner.registerInfo("OC = #{on_center_in}.")
			
			# Define framing cavity thickness
			if frame_depth == '3_5In'
				cav_thickness = 3.5
			elsif frame_depth == '5_5In'
				cav_thickness = 5.5
			elsif frame_depth == '7_25In'
				cav_thickness = 7.25
			elsif frame_depth == '9_25In'
				cav_thickness = 9.25
			elsif frame_depth == '11_25In'
				cav_thickness = 11.25	
			else
				cav_thickness = nil
			end
			#runner.registerInfo("Cavity Thickness = #{cav_thickness}.")
			
			# define the cavity insulation
			if cavity_ins.nil?
				cav_r_ip = 0
				ins_r_value_per_in = 0
			else
				cav_r_ip = cavity_ins
				#runner.registerInfo("Cavity R Value = #{cav_r_ip}.")
				if not cav_thickness.nil?
					ins_r_value_per_in = cav_r_ip / cav_thickness
				else
					ins_r_value_per_in = nil # If this occurs, there is something wrong.
				end
			end
			#runner.registerInfo("Cavity Insulation R is #{cav_r_ip}.") 
			#runner.registerInfo("Cavity Insulation R per Inch is #{ins_r_value_per_in}.")
			
			# Assume cavity insulation for wood framing is either fiberglass batt or cellulose; are there others to include?
			if not ins_r_value_per_in.nil?
				if ins_r_value_per_in < 0.1
					ins_mat = 'NONE'
				elsif ins_r_value_per_in < 3.6 and ins_r_value_per_in > 0.01
					ins_mat = 'BATT_FIBERGLASS'
				else
					ins_mat = 'LOOSE_FILL_CELLULOSE'
				end
			else
				ins_mat = 'UNKNOWN'
			end
			#runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
			
			if cav_r_ip > 0
				insulationCav = {
					'insulationMaterial' => ins_mat,
					'insulationThickness' => cav_thickness,
					'insulationNominalRValue' => cav_r_ip,
					'insulationInstallationType' => 'CAVITY',
					'insulationLocation' => 'INTERIOR'
				}
				#runner.registerInfo("Cavity Insulation = #{insulationCav}")
				insulations << insulationCav
			end

			concrete_value = {}
			
			clt_values = {}
			

		# SIPS Roof Type
		elsif category.to_s.include?('SIPS')
			# define the roof material type
			rafters_material = 'STRUCTURALLY_INSULATED_PANEL' 	# SIPs are not currently an option
			
			# define the framing size; there are no rafters for SIPs
			studs_size = 'OTHER_SIZE'
			#runner.registerInfo("Studs Size = #{studs_size}.")

			# define On Center
			#fc = frame_config.get.downcase
			#runner.registerInfo("OC = #{fc}.")
			on_center_in = 0
			#runner.registerInfo("OC = #{on_center_in}.")
			
			# parse the standard identifier;  eg SIPS - R55 - OSB Spline - 10 1/4 in.
			
			# find R value of the "cavity" of the SIP
			#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
			sips_r_value_ip =/(\d+)/.match(identifier).to_s.to_f
			#runner.registerInfo("SIPS R Value = #{sips_r_value_ip}.")
			
			# Define framing cavity thickness
			sips_thickness =/(\d+)\s(\d).(\d)/.match(identifier).to_s
			#runner.registerInfo("SIPs insulation thickness = #{sips_thickness}.")
			# assumes 7/16 OSB; missing metal splines and double splines
			if sips_thickness == '4 1/2'
				cav_thickness = (4.5 - 0.875)
			elsif sips_thickness == '6 1/2'
				cav_thickness = (6.5 - 0.875)
			elsif sips_thickness == '8 1/2'
				cav_thickness = (8.5 - 0.875)	
			elsif sips_thickness == '10 1/4'
				cav_thickness = (10.25 - 0.875)
			elsif sips_thickness == '12 1/4'
				cav_thickness = (12.25 - 0.875)	
			else
				cav_thickness = nil
			end
			#runner.registerInfo("SIPS Insulation Thickness = #{cav_thickness}.")
			
			# define the SIPs insulation
			if sips_r_value_ip.nil?
				cav_r_ip = 0
				ins_r_value_per_in = 0
			else
				cav_r_ip = sips_r_value_ip
				#runner.registerInfo("SIPs R Value = #{cav_r_ip}.")
				if not cav_thickness.nil?
					ins_r_value_per_in = cav_r_ip / cav_thickness
				else
					ins_r_value_per_in = nil # If this occurs, there is something wrong.
				end
			end
			#runner.registerInfo("SIPs Insulation R is #{cav_r_ip}.") 
			#runner.registerInfo("SIPs Insulation R per Inch is #{ins_r_value_per_in}.")
			
			# Assume rigid insulation for SIPs; are there others to include?
			if not ins_r_value_per_in.nil?
				if ins_r_value_per_in < 0.1
					ins_mat = 'NONE'
				elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
					ins_mat = 'RIGID_EPS'
				elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
					ins_mat = 'RIGID_XPS'
				elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
					ins_mat = 'RIGID_POLYISOCYANURATE'
				else
					ins_mat = 'RIGID_UNKNOWN'
				end
			else
				ins_mat = 'UNKNOWN'
			end
			#runner.registerInfo("SIPs Insulation is #{ins_mat}.")
			
			if cav_r_ip > 0
				insulationCav = {
					'insulationMaterial' => ins_mat,
					'insulationThickness' => cav_thickness,
					'insulationNominalRValue' => cav_r_ip,
					'insulationInstallationType' => 'CAVITY',
					'insulationLocation' => 'INTERIOR'
				}
				#runner.registerInfo("Cavity Insulation = #{insulationCav}")
				insulations << insulationCav
			end
			
			concrete_value = {}
			
			clt_values = {}


		elsif category.to_s.include?('Concrete') and not category.to_s.include?('Sandwich Panel')
			rafters_material = 'OTHER_MATERIAL'

			# solid concrete will not have framing or cavity insulation within the material
			studs_size = 'OTHER_SIZE'
			#runner.registerInfo("Studs Size = #{studs_size}.")
			on_center_in = 0
			#runner.registerInfo("OC = #{on_center_in}.")
			# Define concrete thickness
			concrete_thickness =/(\d+)\sin/.match(identifier).to_s
			#runner.registerInfo("Concrete thickness string = #{concrete_thickness}.")
			if concrete_thickness == '6 in'
				cav_thickness = 6
			elsif concrete_thickness == '8 in'
				cav_thickness = 8
			elsif concrete_thickness == '10 in'
				cav_thickness = 10	
			elsif concrete_thickness == '12 in'
				cav_thickness = 12
			else
				cav_thickness = nil
			end
			#runner.registerInfo("Concrete Thickness = #{cav_thickness}.")
			ins_mat = 'NONE'
			#runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
			# Currently creating the cavity insulation object, but could be deleted.
			# TO DO: How do we handle framing on the inside of the concrete wall?
			cav_r_ip = 0
			if cav_r_ip > 0
				insulationCav = {
					'insulationMaterial' => ins_mat,
					'insulationThickness' => cav_thickness,
					'insulationNominalRValue' => cav_r_ip,
					'insulationInstallationType' => 'CAVITY',
					'insulationLocation' => 'INTERIOR'
				}
				#runner.registerInfo("Cavity Insulation = #{insulationCav}")
				insulations << insulationCav
			end

			#Find concrete strength and reinforcement from standards identifier
			#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
			concrete_name = identifier.to_s
			#runner.registerInfo("Concrete Name = #{concrete_name}.")
			density =/(\d+)/.match(identifier).to_s.to_f
			#runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
			compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
			#runner.registerInfo("PSI = #{compressive_strength_value}.")

			# Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
			if compressive_strength_value < 2000
				compressive_strength = 'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
			elsif 	compressive_strength_value > 2000 and compressive_strength_value < 2750
				compressive_strength = '_2500_PSI'
			elsif 	compressive_strength_value > 2750 and compressive_strength_value < 3500
				compressive_strength = '_3000_PSI'
			elsif 	compressive_strength_value > 3500 and compressive_strength_value < 4500
				compressive_strength = '_4000_PSI'
			elsif 	compressive_strength_value > 4500 and compressive_strength_value < 5500
				compressive_strength = '_5000_PSI'
			elsif 	compressive_strength_value > 5500 and compressive_strength_value < 7000
				compressive_strength = '_6000_PSI'
			elsif 	compressive_strength_value > 7000
				compressive_strength = '_8000_PSI'
			else
				compressive_strength = 'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
    		end
			
			# Define reinforcement - defaulted to 5 
			rebar_number = 5  # defaulted to 5 for no particular reason
			
			# Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
			if rebar_number = 4
				reinforcement = 'REBAR_NO_4'
			elsif rebar_number = 5
				reinforcement = 'REBAR_NO_5'
			elsif rebar_number = 6
				reinforcement = 'REBAR_NO_6'
			else
				reinforcement = 'UNSPECIFIED_CONCRETE_REINFORCEMENT'
			end
      	
			concrete_value = {
				'concreteName' => concrete_name,
				'compressiveStrength' => compressive_strength,
				'reinforcement' => reinforcement
			}
			#runner.registerInfo("Concrete value = #{concrete_value}")
			
			clt_values = {}

		# Masonry Unit Walls - Assume concrete; ignores clay masonry; excludes block fill
		elsif category.to_s.include?('Masonry Units')
			wall_type = 'CONCRETE_MASONRY_UNIT'
			
			#Provide details on the masonry fill; currently not used for anything.
			if category.to_s.include?('Hollow')
				wall_fill_unused = 'HOLLOW'
			elsif category.to_s.include?('Solid')
				wall_fill_unused = 'SOLID'
			elsif category.to_s.include?('Fill')
				wall_fill_unused = 'FILL'
			else
				wall_fill_unused = 'UNKNOWN'
			end
			
			# ICF wall will not have framing or cavity insulation within the material
			studs_size = 'OTHER_SIZE'
			#runner.registerInfo("Studs Size = #{studs_size}.")
			on_center_in = 0
			#runner.registerInfo("OC = #{on_center_in}.")
			
			# Define thickness of the block
			cmu_thickness =/(\d+)\sin/.match(identifier).to_s
			#runner.registerInfo("CMU thickness string = #{cmu_thickness}.")
			if cmu_thickness == '6 in'
				cav_thickness = 6
			elsif cmu_thickness == '8 in'
				cav_thickness = 8
			elsif cmu_thickness == '10 in'
				cav_thickness = 10	
			elsif cmu_thickness == '12 in'
				cav_thickness = 12
			else
				cav_thickness = nil
			end
			#runner.registerInfo("CMU Thickness = #{cav_thickness}.")
			
			ins_mat = 'NONE'
			#runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
			# Currently creating the cavity insulation object, but could be deleted.
			# TO DO: How do we handle framing on the inside of the concrete wall?
			cav_r_ip = 0
			if cav_r_ip > 0
				insulationCav = {
					'insulationMaterial' => ins_mat,
					'insulationThickness' => cav_thickness,
					'insulationNominalRValue' => cav_r_ip,
					'insulationInstallationType' => 'CAVITY',
					'insulationLocation' => 'INTERIOR'
				}
				#runner.registerInfo("Cavity Insulation = #{insulationCav}")
				insulations << insulationCav
			end

			#Find concrete strength and reinforcement from standards identifier
			#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
			concrete_name = identifier.to_s
			#runner.registerInfo("Concrete Name = #{concrete_name}.")
			density =/(\d+)/.match(identifier).to_s.to_f
			#runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
			compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
			#runner.registerInfo("PSI = #{compressive_strength_value}.")

			# Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
			if compressive_strength_value < 2000
				compressive_strength = 'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
			elsif 	compressive_strength_value > 2000 and compressive_strength_value < 2750
				compressive_strength = '_2500_PSI'
			elsif 	compressive_strength_value > 2750 and compressive_strength_value < 3500
				compressive_strength = '_3000_PSI'
			elsif 	compressive_strength_value > 3500 and compressive_strength_value < 4500
				compressive_strength = '_4000_PSI'
			elsif 	compressive_strength_value > 4500 and compressive_strength_value < 5500
				compressive_strength = '_5000_PSI'
			elsif 	compressive_strength_value > 5500 and compressive_strength_value < 7000
				compressive_strength = '_6000_PSI'
			elsif 	compressive_strength_value > 7000
				compressive_strength = '_8000_PSI'
			else
				compressive_strength = 'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
    		end
			
			# Define reinforcement - defaulted to 5 
			rebar_number = 5  # defaulted to 5 for no particular reason
			
			# Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
			if rebar_number = 4
				reinforcement = 'REBAR_NO_4'
			elsif rebar_number = 5
				reinforcement = 'REBAR_NO_5'
			elsif rebar_number = 6
				reinforcement = 'REBAR_NO_6'
			else
				reinforcement = 'UNSPECIFIED_CONCRETE_REINFORCEMENT'
			end
			
			concrete_value = {
				'concreteName' => concrete_name,
				'compressiveStrength' => compressive_strength,
				'reinforcement' => reinforcement
			}
			#runner.registerInfo("Concrete value = #{concrete_value}")
			
			clt_values = {}
		
		elsif category.to_s.include?('ICF')
			wall_type = 'INSULATED_CONCRETE_FORMS'
			
			# solid concrete will not have framing or cavity insulation within the material
			studs_size = 'OTHER_SIZE'
			#runner.registerInfo("Studs Size = #{studs_size}.")
			on_center_in = 0
			#runner.registerInfo("OC = #{on_center_in}.")
			
			# Insulating Concrete Forms - 1 1/2 in. Polyurethane Ins. each side - concrete 8 in.
			# Define thickness of the concrete
			concrete_thickness =/(\d+)\sin/.match(identifier).to_s
			#runner.registerInfo("ICF thickness string = #{concrete_thickness}.")
			if concrete_thickness == '6 in'
				cav_thickness = 6
			elsif concrete_thickness == '8 in'
				cav_thickness = 8
			else
				cav_thickness = nil
			end
			#runner.registerInfo("Concrete Thickness = #{cav_thickness}.")
			
			# define the ICF insulation type
			icf_ins = identifier.to_s
			#runner.registerInfo("ICF String = #{icf_ins}.")
			
			if identifier.to_s.include?('XPS')
				ins_mat = 'RIGID_XPS'
				ins_r_value_per_in = 5.0
			elsif identifier.to_s.include?('EPS')
				ins_mat = 'RIGID_EPS'
				ins_r_value_per_in = 5.0
			elsif identifier.to_s.include?('Polyurethane')
				ins_mat = 'SPRAY_FOAM_CLOSED_CELL'
				ins_r_value_per_in = 5.0
			elsif identifier.to_s.include?('Polyiso')
				ins_mat = 'RIGID_POLYISOCYANURATE' 
				ins_r_value_per_in = 5.0
			else
				ins_mat = 'UNKNOWN'
				ins_r_value_per_in = 0
			end
			#runner.registerInfo("ICF Insulation is #{ins_mat}.")
			#runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")
			
			# define the ICF insulation thickness; concrete is always thicker than the insulation
			if identifier.to_s.include?('1 1/2 in.')
				cav_thickness = 1.5
			elsif identifier.to_s.include?('2 in.')
				cav_thickness = 2
			elsif identifier.to_s.include?('2 1/2 in.')
				cav_thickness = 2.5
			elsif identifier.to_s.include?('3 in.')
				cav_thickness = 3
			elsif identifier.to_s.include?('4 in.')
				cav_thickness = 4	
			elsif identifier.to_s.include?('4 1/2 in.')
				cav_thickness = 4.5
			else
				cav_thickness = nil
			end
			#runner.registerInfo("ICF Thickness = #{cav_thickness}.")
			cav_r_ip = cav_thickness * ins_r_value_per_in
			#runner.registerInfo("ICF Insulation R Value = #{cav_r_ip}.")

			if cav_r_ip > 0
				insulationCav = {
					'insulationMaterial' => ins_mat,
					'insulationThickness' => cav_thickness,
					'insulationNominalRValue' => cav_r_ip,
					'insulationInstallationType' => 'CAVITY',
					'insulationLocation' => 'INTERIOR'
				}
				#runner.registerInfo("Cavity Insulation = #{insulationCav}")
				insulations << insulationCav
			end

			##Find concrete strength and reinforcement from standards identifier
			#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
			concrete_name = identifier.to_s
			#runner.registerInfo("Concrete Name = #{concrete_name}.")
			density =/(\d+)/.match(identifier).to_s.to_f
			#runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
			compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
			#runner.registerInfo("PSI = #{compressive_strength_value}.")

			# Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
			if compressive_strength_value < 2000
				compressive_strength = 'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
			elsif 	compressive_strength_value > 2000 and compressive_strength_value < 2750
				compressive_strength = '_2500_PSI'
			elsif 	compressive_strength_value > 2750 and compressive_strength_value < 3500
				compressive_strength = '_3000_PSI'
			elsif 	compressive_strength_value > 3500 and compressive_strength_value < 4500
				compressive_strength = '_4000_PSI'
			elsif 	compressive_strength_value > 4500 and compressive_strength_value < 5500
				compressive_strength = '_5000_PSI'
			elsif 	compressive_strength_value > 5500 and compressive_strength_value < 7000
				compressive_strength = '_6000_PSI'
			elsif 	compressive_strength_value > 7000
				compressive_strength = '_8000_PSI'
			else
				compressive_strength = 'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
    		end
			
			# Define reinforcement - defaulted to 5 
			rebar_number = 5  # defaulted to 5 for no particular reason
			
			# Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
			if rebar_number = 4
				reinforcement = 'REBAR_NO_4'
			elsif rebar_number = 5
				reinforcement = 'REBAR_NO_5'
			elsif rebar_number = 6
				reinforcement = 'REBAR_NO_6'
			else
				reinforcement = 'UNSPECIFIED_CONCRETE_REINFORCEMENT'
			end
			
			concrete_value = {
				'concreteName' => concrete_name,
				'compressiveStrength' => compressive_strength,
				'reinforcement' => reinforcement
			}
			#runner.registerInfo("Concrete value = #{concrete_value}")
			
			clt_values = {}
		
		# Concrete Sandwich Panel Walls; matched to ICF because the material take-off approach is the same
		elsif category.to_s.include?('Concrete Sandwich Panel')
			rafters_material = 'OTHER_MATERIAL'
			# solid concrete will not have framing or cavity insulation within the material
			studs_size = 'OTHER_SIZE'
			#runner.registerInfo("Studs Size = #{studs_size}.")
			on_center_in = 0
			#runner.registerInfo("OC = #{on_center_in}.")
			
			# Concrete Sandwich Panel - 100% Ins. Layer - No Steel in Ins. - Ins. 1 1/2 in.
			# Concrete Sandwich Panel - 100% Ins. Layer - Steel in Ins. - Ins. 1 1/2 in.
			# Concrete Sandwich Panel - 90% Ins. Layer - No Steel in Ins. - Ins. 2 in.
			
			# Define thickness of the concrete
			concrete_thickness = 3 * 2 # Defaulted to 3 in wythes of concrete 
			
			# define the CSP insulation thickness
			if identifier.to_s.include?('1 1/2 in.')
				ins_thickness = 1.5
			elsif identifier.to_s.include?('2 in.')
				ins_thickness = 2
			elsif identifier.to_s.include?('3 in.')
				ins_thickness = 3
			elsif identifier.to_s.include?('4 in.')
				ins_thickness = 4	
			elsif identifier.to_s.include?('5 in.')
				ins_thickness = 5
			elsif identifier.to_s.include?('6 in.')
				ins_thickness = 6
			else
				ins_thickness = nil
			end
			#runner.registerInfo("Insulation Thickness = #{ins_thickness}.")
			
			# define the ICF insulation type and R value
			ins_mat = 'RIGID_EPS'
			ins_r_value_per_in = 5
			#runner.registerInfo("ICF Insulation is #{ins_mat}.")
			#runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")
			
			# Calculate total Cavity R value
			cav_r_ip = ins_thickness * ins_r_value_per_in
			#runner.registerInfo("CSP Insulation R Value = #{cav_r_ip}.")
			
			# calculate structural layer thickness
			cav_thickness = concrete_thickness + ins_thickness
			
			if cav_r_ip > 0
				insulationCav = {
					'insulationMaterial' => ins_mat,
					'insulationThickness' => cav_thickness,
					'insulationNominalRValue' => cav_r_ip,
					'insulationInstallationType' => 'CAVITY',
					'insulationLocation' => 'INTERIOR'
				}
				#runner.registerInfo("Cavity Insulation = #{insulationCav}")
				insulations << insulationCav
			end

			#Find concrete strength and reinforcement from standards identifier
			#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
			concrete_name = identifier.to_s
			#runner.registerInfo("Concrete Name = #{concrete_name}.")
			density =/(\d+)/.match(identifier).to_s.to_f
			#runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
			compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
			#runner.registerInfo("PSI = #{compressive_strength_value}.")

			# Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
			if compressive_strength_value < 2000
				compressive_strength = 'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
			elsif 	compressive_strength_value > 2000 and compressive_strength_value < 2750
				compressive_strength = '_2500_PSI'
			elsif 	compressive_strength_value > 2750 and compressive_strength_value < 3500
				compressive_strength = '_3000_PSI'
			elsif 	compressive_strength_value > 3500 and compressive_strength_value < 4500
				compressive_strength = '_4000_PSI'
			elsif 	compressive_strength_value > 4500 and compressive_strength_value < 5500
				compressive_strength = '_5000_PSI'
			elsif 	compressive_strength_value > 5500 and compressive_strength_value < 7000
				compressive_strength = '_6000_PSI'
			elsif 	compressive_strength_value > 7000
				compressive_strength = '_8000_PSI'
			else
				compressive_strength = 'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
    		end
			
			# Define reinforcement - defaulted to 5 
			rebar_number = 5  # defaulted to 5 for no particular reason
			
			# Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
			if rebar_number = 4
				reinforcement = 'REBAR_NO_4'
			elsif rebar_number = 5
				reinforcement = 'REBAR_NO_5'
			elsif rebar_number = 6
				reinforcement = 'REBAR_NO_6'
			else
				reinforcement = 'UNSPECIFIED_CONCRETE_REINFORCEMENT'
			end
			
			concrete_value = {
				'concreteName' => concrete_name,
				'compressiveStrength' => compressive_strength,
				'reinforcement' => reinforcement
			}
			#runner.registerInfo("Concrete value = #{concrete_value}")
			
			clt_values = {}

		# Metal Insulated Panel Walls; metal SIPs
		elsif category.to_s.include?('Metal Insulated Panel Wall')
			rafters_material = 'STRUCTURALLY_INSULATED_PANEL'
		
			# Metal Insulated Panels - 2 1/2 in.
			# metal is assumed to be 26 gauge steel at 0.02 in thick for a total of 0.04 in of steel.
			# Currently assume metal thickness is additional to defined thickness
			
			# define the panel thickness
			if identifier.to_s.include?('2 in.')
				cav_thickness = 2
			elsif identifier.to_s.include?('2 1/2 in.')
				cav_thickness = 2.5
			elsif identifier.to_s.include?('3 in.')
				cav_thickness = 3
			elsif identifier.to_s.include?('4 in.')
				cav_thickness = 4	
			elsif identifier.to_s.include?('5 in.')
				cav_thickness = 5
			elsif identifier.to_s.include?('6 in.')
				cav_thickness = 6
			else
				cav_thickness = nil
			end
			#runner.registerInfo("Insulation Thickness = #{cav_thickness}.")
			
			# define the insulation type and R value; assume EPS at R-5/in
			ins_mat = 'RIGID_EPS'
			ins_r_value_per_in = 5
			#runner.registerInfo("Metal Panel Wall Insulation is #{ins_mat}.")
			#runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")
			
			# Calculate total Cavity R value
			cav_r_ip = cav_thickness * ins_r_value_per_in
			#runner.registerInfo("CSP Insulation R Value = #{cav_r_ip}.")
			
			if cav_r_ip > 0
				insulationCav = {
					'insulationMaterial' => ins_mat,
					'insulationThickness' => cav_thickness,
					'insulationNominalRValue' => cav_r_ip,
					'insulationInstallationType' => 'CAVITY',
					'insulationLocation' => 'INTERIOR'
				}
				#runner.registerInfo("Cavity Insulation = #{insulationCav}")
				insulations << insulationCav
			end
			
			concrete_value = {}
			
			clt_values = {}
		
		# Cross Laminated Timber (CLT) Walls - does not include any insulation.
		# User must manually add a standards category and standards identifier
		# Category = CLT; Identifier Format = X in. 50/75/100 psf Live Load
		elsif category.to_s.include?('CLT')	or 	category.to_s.include?('Cross Laminated Timber') or category.to_s.include?('Woods')	# not a tag option at the moment
			rafters_material = 'CROSS_LAMINATED_TIMBER'
		
			# define the framing size; there are no rafters for SIPs
			studs_size = 'OTHER_SIZE'
			#runner.registerInfo("Studs Size = #{studs_size}.")

			# define On Center
			#fc = frame_config.get.downcase
			#runner.registerInfo("OC = #{fc}.")
			on_center_in = 0
			#runner.registerInfo("OC = #{on_center_in}.")
			
			# parse the standard identifier;  eg CLT - 2x4 - 3 Layers
			
			# find R value of the "cavity" of the SIP
			#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
			live_load = 50
			if not category.nil?
				live_load =/(\d+)\spsf/.match(identifier).to_s.to_f
			end
			#runner.registerInfo("Live Load = #{live_load}.")
			
			# Define framing cavity thickness
			clt_thickness =/(\d+)\sin./.match(identifier).to_s
			#runner.registerInfo("CLT thickness = #{clt_thickness}.")
			value, unit = clt_thickness.split(' ')
			cav_thickness = value.to_f
			#runner.registerInfo("CLT Thickness = #{cav_thickness}.")
	
			cav_r_ip = 0
			ins_r_value_per_in = 0
			ins_r_value_per_in = 0
			ins_mat = 'NONE'
			
			if cav_r_ip > 0
				insulationCav = {
					'insulationMaterial' => ins_mat,
					'insulationThickness' => cav_thickness,
					'insulationNominalRValue' => cav_r_ip,
					'insulationInstallationType' => 'CAVITY',
					'insulationLocation' => 'INTERIOR'
				}
				#runner.registerInfo("Cavity Insulation = #{insulationCav}")
				insulations << insulationCav
			end
			
			concrete_value = {}
			
			# Define supported span using wall length and stories - defaulted to 1 for residential
			supported_span = wall_length_ft #equal to the width of the wall; what is the max span?
			supported_stories = 1	#assume 1 story for residential.
			
			# Define supported element
			clt_supported_element_type = 'ROOF'	#if surface is first floor then assume "floor", if 2nd floor assume "roof"
		
			clt_values = {
				'liveLoad' => live_load,	#kPa
				'supportedSpan' => supported_span,	#the length of wall unless it exceeds the maximum
				'supportedElementType' => clt_supported_element_type,
				'supportedStories' => supported_stories
			}
		
		else								# Includes Spandrel Panels Curtain Walls and straw bale wall; 
			rafters_material = 'OTHER_MATERIAL'
			# define the framing size; there are no studs for SIPs
			studs_size = 'OTHER_SIZE'
			#runner.registerInfo("Studs Size = #{studs_size}.")

			# define On Center
			#fc = frame_config.get.downcase
			#runner.registerInfo("OC = #{fc}.")
			on_center_in = 0
			#runner.registerInfo("OC = #{on_center_in}.")
			
			cav_r_ip = 0
			ins_r_value_per_in = 0
			ins_r_value_per_in = 0
			ins_mat = 'NONE'

			if cav_r_ip > 0
				insulationCav = {
					'insulationMaterial' => ins_mat,
					'insulationThickness' => cav_thickness,
					'insulationNominalRValue' => cav_r_ip,
					'insulationInstallationType' => 'CAVITY',
					'insulationLocation' => 'INTERIOR'
				}
				#runner.registerInfo("Cavity Insulation = #{insulationCav}")
				insulations << insulationCav
			end
			
			concrete_value = {}
			
			clt_values = {}
			
		end
		
		
		# Additional insulation either interior or exterior to the structural layer (composite framing layer, SIPs, CIFs, CLTs)
		# Use structural layer as base to find other insulation.
		
		# Interior rigid insulation r-value
		rigid_ins_int = const.rigid_insulation_values(sl_i, 'interior')
		int_r = rigid_ins_int[0].to_s.to_f
		int_t = rigid_ins_int[1].to_s.to_f
		#This is an R Value, but we need to determine the material.
		if rigid_ins_int.nil?
			int_r_ip = 0
			interior_rigid_thickness = 0
		else
			int_r_ip = int_r
			interior_rigid_thickness = int_t
			ins_r_value_per_in = int_r / int_t
			
			if ins_r_value_per_in < 0.1
				ins_mat = 'NONE'
			elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
				ins_mat = 'RIGID_EPS'
			elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
				ins_mat = 'RIGID_XPS'
			elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
				ins_mat = 'RIGID_POLYISOCYANURATE'
			else
				ins_mat = 'RIGID_UNKNOWN'
			end
		end
		#runner.registerInfo("Insulation R is #{int_r_ip}.")
		#runner.registerInfo("Insulation Type is #{ins_mat}.")
		#runner.registerInfo("Insulation Thickness is #{interior_rigid_thickness}.")
		if int_r_ip > 0
			insulationInt = {
				'insulationMaterial' => ins_mat,
				'insulationThickness' => interior_rigid_thickness.round(1),
				'insulationNominalRValue' => int_r_ip.round(1),
				'insulationInstallationType' => 'CONTINUOUS',
				'insulationLocation' => 'INTERIOR'
			}
			#runner.registerInfo("Insulation = #{insulationInt}")
			insulations << insulationInt
		end
		
		# Exterior rigid insulation r-value		
		rigid_ins_ext = const.rigid_insulation_values(sl_i, 'exterior')
		ext_r = rigid_ins_ext[0].to_s.to_f
		ext_t = rigid_ins_ext[1].to_s.to_f
		#This is an R Value, but we need to determine the material.
		if rigid_ins_ext.nil?
			ext_r_ip = 0
			exterior_rigid_thickness = 0
		else
			ext_r_ip = ext_r
			exterior_rigid_thickness = ext_t
			ins_r_value_per_in = ext_r / ext_t
			
			if ins_r_value_per_in < 0.1
				ins_mat = 'NONE'
			elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
				ins_mat = 'RIGID_EPS'
			elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
				ins_mat = 'RIGID_XPS'
			elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
				ins_mat = 'RIGID_POLYISOCYANURATE'
			else
				ins_mat = 'RIGID_UNKNOWN'
			end
		end
		#runner.registerInfo("Insulation R is #{ext_r_ip}.")
		#runner.registerInfo("Insulation Type is #{ins_mat}.")
		#runner.registerInfo("Insulation Thickness is #{exterior_rigid_thickness}.")
		if ext_r_ip > 0
			insulationExt = {
				'insulationMaterial' => ins_mat,
				'insulationThickness' => exterior_rigid_thickness.round(1),
				'insulationNominalRValue' => ext_r_ip.round(1),
				'insulationInstallationType' => 'CONTINUOUS',
				'insulationLocation' => 'EXTERIOR'
			}
			#runner.registerInfo("Insulation = #{insulationExt}")
			insulations << insulationExt
		end
		# Find the Floor Decking Type
		roof_decking_type = 'NONE' # Defaulted to None in case no decking is found.
		deck_identifier = nil
		deck_category = nil
		
		layers.each_with_index do |layer, i|
			# Skip fenestration, partition, and airwall materials
			next if roof_decking_type == 'WOOD' or roof_decking_type == 'METAL'
			layer = layer.to_OpaqueMaterial
			next if layer.empty?
			deck_layer = layer.get
			deck_stds = deck_layer.standardsInformation
			next if not deck_stds.standardsIdentifier.is_initialized				
			deck_identifier = deck_stds.standardsIdentifier.get.to_s
			deck_identifier = deck_identifier.downcase
			#runner.registerInfo("Deck Layer Identifier = #{deck_identifier}.")
			if deck_identifier.include?('osb') or deck_identifier.include?('plywood')
				roof_decking_type = 'WOOD'
			elsif deck_identifier.include?('Metal Deck')
				roof_decking_type = 'METAL'
			else
				roof_decking_type = 'NONE'
			end					
		end
		#runner.registerInfo("Frame Floor Decking = #{roof_decking_type}.")
		
		# define roof construction type
		if rafters_material == 'WOOD_RAFTER'		
			roof_construction_type = 'RAFTER'		# Ignores TRUSS for now.
		elsif rafters_material == 'METAL_RAFTER'
			roof_construction_type = 'RAFTER'		# Ignores TRUSS for now.
		elsif category.include?('Concrete') or category.include?('ICF')
			roof_construction_type = 'CONCRETE_DECK' #
		else 										# Handles all 'OTHER_MATERIAL'
			roof_construction_type = 'OTHER'		# There is no rafter or truss for CLT, concrete, ICF, SIPs, or MIPs
		end
		
		#Need to find all subsurfaces on a roof surface and determine which are skylights.
		#Then pull the information for each to add to the array.
		#This will require a do loop through each wall surface.
		skylights = []

		#if subsurface is a skylight, then populate the skylight object.
		#Only need to populate the physical components or the performance specs. Use performance specs from OSM.
		#Can I pull this info from OSM or do I have to go through each E+ skylight object, match the surface name, and pull specs?
		
		#runner.registerInfo("finding all skylights in this roof surface.")
		surf.subSurfaces.each do |ss|
			#if ss is a skylight, else its a door.
			#runner.registerInfo("found subsurface.")
			subsurface_type = ss.subSurfaceType
			#runner.registerInfo("found subsurface type: #{subsurface_type}.")
			# Determine if the subsurface is a skylight or other
			if subsurface_type == 'Skylight'
				operable = false		# hard code to No
				skylight_name = ss.name
				#runner.registerInfo("found subsurface #{skylight_name}.")
				skylight_area_m2 = ss.grossArea
				#runner.registerInfo("found subsurface #{skylight_name} with area #{skylight_area}.")
				skylight_area_ft2 = OpenStudio.convert(skylight_area_m2, 'm^2','ft^2').get
				skylight_z_max = -1000000000
				skylight_z_min = 1000000000
				#runner.registerInfo("finding subsurface vertices.")
				vertices = ss.vertices
				#runner.registerInfo("found subsurface vertices.")
				vertices.each do |vertex|
					z = vertex.z
					if z < skylight_z_min
						skylight_z_min = z
					else next
					end					
					if z > skylight_z_max
						skylight_z_max = z
					else
					end
				end
				#runner.registerInfo("found max and min z vertices.")
				skylight_height_m = skylight_z_max - skylight_z_min
				#runner.registerInfo("skylight height = #{skylight_height_m}.")
				#Convert to IP
				skylight_height_ft = OpenStudio.convert(skylight_height_m, 'm','ft').get

				# Use construction standards for subsurface to find window characteristics
				# Default all the characteristics to NONE
				frame_type = 'NONE_FRAME_TYPE'
				glass_layer = 'NONE_GLASS_LAYERS'
				glass_type =  'NONE_GLASS_TYPE'
				gas_fill = 'NONE_GAS_FILL'
				
				# Find the construction of the window
				sub_const = ss.construction
				next if sub_const.empty?
				sub_const = sub_const.get
				# Convert construction base to construction
				sub_const = sub_const.to_Construction.get
				runner.registerInfo("Window Construction is #{sub_const}.")  
				# Check if the construction has measure tags.
				sub_const_stds = sub_const.standardsInformation
				runner.registerInfo("Window Const Stds Info is #{sub_const_stds}.")  
				
				# Find number of panes. Does not account for storm windows. Quad panes is not in enumerations.
				if sub_const_stds.fenestrationNumberOfPanes.is_initialized
					number_of_panes = sub_const_stds.fenestrationNumberOfPanes.get.downcase.to_s
					if number_of_panes.include?('single')
						glass_layer = 'SINGLE_PANE'
					elsif number_of_panes.include?('double')
						glass_layer = 'DOUBLE_PANE'
					elsif number_of_panes.include?('triple')
						glass_layer = 'TRIPLE_PANE'
					elsif number_of_panes.include?('quadruple')
						glass_layer = 'MULTI_LAYERED'
					elsif number_of_panes.include?('glass block')
						glass_layer = 'NONE_GLASS_LAYERS'
					else
						glass_layer = 'NONE_GLASS_LAYERS'
					end	
				end
				runner.registerInfo("Glass Layers = #{glass_layer}.")
				
				# Find frame type. Does not account for wood, aluminum, vinyl, or fiberglass.
				if sub_const_stds.fenestrationFrameType.is_initialized
					os_frame_type = sub_const_stds.fenestrationFrameType.get.downcase.to_s
					if os_frame_type.include?('non-metal')
						frame_type = 'COMPOSITE'
					elsif os_frame_type.include?('metal framing thermal')
						frame_type = 'METAL_W_THERMAL_BREAK'
					elsif os_frame_type.include?('metal framing')
						frame_type = 'METAL'
					else
						frame_type = 'NONE_FRAME_TYPE'
					end	
				end
				runner.registerInfo("Frame Type = #{frame_type}.")
				
				# Find tint and low e coating. Does not account for reflective.
				os_low_e = sub_const_stds.fenestrationLowEmissivityCoating
				runner.registerInfo("low e = #{os_low_e}.")
				if sub_const_stds.fenestrationTint.is_initialized
					os_tint = sub_const_stds.fenestrationTint.get.downcase.to_s
					if os_low_e == true
						glass_type = 'LOW_E'	
					else
						if os_tint.include?('clear')
							glass_type = 'NONE_GLASS_TYPE'
						elsif os_tint.include?('tinted') or os_tint.include?('green') or os_tint.include?('blue') or os_tint.include?('grey') or os_tint.include?('bronze')
							glass_type = 'TINTED'
						else
							glass_type = 'NONE_GLASS_TYPE'
						end	
					end
				elsif not sub_const_stds.fenestrationTint.is_initialized
					if os_low_e == true
						glass_type = 'LOW_E'	
					else
						glass_type = 'NONE_GLASS_TYPE'
					end
				end
				runner.registerInfo("Glass Type = #{glass_type}.")
	
				# Find gas fill. Enumerations missing krypton - matches to argon.
				if sub_const_stds.fenestrationGasFill.is_initialized
					os_gas_fill = sub_const_stds.fenestrationGasFill.get.downcase.to_s
					if os_gas_fill.include?('air')
						gas_fill = 'AIR'
					elsif os_gas_fill.include?('argon') or os_tint.include?('krypton')
						gas_fill = 'ARGON'
					else
						gas_fill = 'NONE_GAS_FILL'
					end	
				end
				runner.registerInfo("Gas Fill = #{gas_fill}.")
				
				
				# Take skylight name and use it to find the specs.
				# Parse the skylight name, upcase the letters, and then put back together. The periods are causing the problem.
				skylight_name_string = skylight_name.to_s
				#runner.registerInfo("skylight name now string: #{skylight_name_string}.")
				skylight_name_capped = skylight_name_string.upcase
				#runner.registerInfo("skylight name capped: #{skylight_name_capped}.")
				# query the SQL file including the row name being a variable. Treat like its in a runner.
				# U-Factor Query
				query = "SELECT Value
				  FROM tabulardatawithstrings
				  WHERE ReportName='EnvelopeSummary'
				  AND ReportForString= 'Entire Facility'
				  AND TableName='Exterior Fenestration'
				  AND ColumnName='Glass U-Factor'
				  AND RowName='#{skylight_name_capped}'
				  AND Units='W/m2-K'"       
				#runner.registerInfo("Query is #{query}.")
				u_si = sql.execAndReturnFirstDouble(query)
				#runner.registerInfo("U-SI value was found: #{u_si}.")
				if u_si.is_initialized
				  u_si = u_si.get
				else
				  u_si = 0
				end
				u_ip = OpenStudio.convert(u_si, 'W/m^2*K','Btu/hr*ft^2*R').get
				# SHGC Query
				query = "SELECT Value
				  FROM tabulardatawithstrings
				  WHERE ReportName='EnvelopeSummary'
				  AND ReportForString= 'Entire Facility'
				  AND TableName='Exterior Fenestration'
				  AND ColumnName='Glass SHGC'
				  AND RowName='#{skylight_name_capped}'"       
				#runner.registerInfo("Query is #{query}.")
				shgc = sql.execAndReturnFirstDouble(query)
				#runner.registerInfo("SHGC value was found: #{shgc}.")
				if shgc.is_initialized
				  shgc = shgc.get
				else
				  shgc = 0
				end
				
				# VT Query
				query = "SELECT Value
				  FROM tabulardatawithstrings
				  WHERE ReportName='EnvelopeSummary'
				  AND ReportForString= 'Entire Facility'
				  AND TableName='Exterior Fenestration'
				  AND ColumnName='Glass Visible Transmittance'
				  AND RowName='#{skylight_name_capped}'"       
				#runner.registerInfo("Query is #{query}.")
				vt = sql.execAndReturnFirstDouble(query)
				#runner.registerInfo("U-SI value was found: #{vt}.")
				if vt.is_initialized
				  vt = vt.get
				else
				  vt = 0
				end
				
				skylight = {
					'name'=> skylight_name,
					'operable'=> operable,
					'area'=> skylight_area_ft2.round(2),
					'height' => skylight_height_ft.round(2),	# TO DO  - need to add to enumerations
					'quantity'=> 1,			# Hard coded until we introduce HPXML
					'frameType'=> frame_type,		
					'glassLayer'=> glass_layer,		
					'glassType'=> glass_type,		
					'gasFill'=> gas_fill,
					'shgc'=> shgc.round(4),
					'visualTransmittance'=> vt.round(4),
					'uFactor'=> u_ip.round(4)
				}
				#runner.registerInfo("skylight = #{skylight}")
				skylights << skylight				
			else	
				#runner.registerInfo("subsurface type is not a skylight and will be skipped: #{subsurface_type}.")
			end
		end
		
		#Populate the surface object
		#runner.registerInfo("Creating Roof object.")
		roof = {
			'roofName' => roof_name,
			'attachedToSpace' => roof_attached_to_space,# attic space to which the roof surface belongs
			'roofInsulations' => insulations,			# Array of the insulations just like walls
			'deckType' => roof_decking_type,			# roof deck material - wood default
			'roofType' => roof_type,					# roof finishing material (shingles, etc)
			'radiantBarrier' => radiant_barrier,		# defaulted to yes; search roof layers for barrier
			'roofArea' => roof_area_ft2.round(2),		# sum of roof surfaces for the specific zone
			'roofConstructionType' => roof_construction_type, 	# rafter or truss	
			'raftersSize' => rafters_size,				# defined in composite layer standard information
			'rafterSpacing' => on_center_in,			# rafters framing - OC
			'raftersMaterials' => rafters_material,		# defined in composite layer standard information
			'pitch' => pitch.round(1),					# defined by using the slope of the roof surfaces
			'roofSpan' => roof_span_ft.round(2),		# use the longest axis of the roof
			'skyLights' => skylights					# all skylights subsurfaces in all roof surfaces 
		}
		#runner.registerInfo("Roof = #{roof}")
		roofs << roof
	end

	return roofs
end

def get_attics(idf, model, runner, user_arguments, sql)
	# Currently cannot handle the complex roof on the NZERTF where the colonial home 
	# has more floor area on the top floor than in the attic and small areas of the ceiling are actually roof surfaces.
	
    # Attic
	# Define variables and call on user inputs.
	attics = []
	attic_type = runner.getStringArgumentValue('attic_type',user_arguments)
	
	model.getSpaces.each do |space|
		# define reused variables for each space
		attic_floors = []
		attic_roofs = []
		#space_is_attic = false
		attic_name = nil
		#define attic floor area
		attic_floor_area = 0
		attic_roof_area = 0
		attic_roof_span = 0
		attic_floor_span = 0
		# define space name
		space_name = space.name.get.to_s
		#runner.registerInfo("Space is #{space_name}.")
		# search surfaces in the space for roof surface 
		space.surfaces.each do |surf|
			#add the surface if its a attic roof or attic floor.
			const = surf.construction
			const = const.get
			const = const.to_Construction.get
			construction_stds = const.standardsInformation
			#runner.registerInfo("Surface is in the Space being considered.") 
			if surf.surfaceType == 'RoofCeiling' and construction_stds.intendedSurfaceType.to_s.include?('AtticRoof')		
				#runner.registerInfo("Surface construction is AtticRoof.")
				#space_is_attic = true
				attic_name = space_name
				roof_name = surf.name.get
				attic_roofs << roof_name
				#runner.registerInfo("Attic Roof list is: #{attic_roofs}.")
				# Add surface floor area to attic roof area
				surface_roof_area_m2 = surf.netArea
				#runner.registerInfo("Floor Area is #{floor_area_m2} m2.")  
				surface_roof_area_ft2 = OpenStudio.convert(surface_roof_area_m2, 'm^2','ft^2').get
				attic_roof_area = attic_roof_area + surface_roof_area_ft2
				# Calculate the roof span by saving the longest 
				#runner.registerInfo("finding  wall vertices.")
				vertices = surf.vertices
				# Find the distance between 2 points on the same z axis
				length = nil
				width = nil
				x0 = nil
				y0 = nil
				z0 = nil
				# Find the x and y differences
				vertices.each_with_index do |vertex, i|
					#Once the values are populated, skip the rest of the vertices.
					if i == 0
						x0 = vertex.x
						y0 = vertex.y
						z0 = vertex.z
						#runner.registerInfo("Vertices = #{x0}, #{y0}, #{z0}.")
					else 
						if vertex.z == z0
							length = (x0 - vertex.x).abs
							width = (y0 - vertex.y).abs
							#runner.registerInfo("Vertices (m) = #{length}, #{width}.")				
						end
					end
				end
				#runner.registerInfo("Vertices = #{length}, #{width}.")
				#Use x and y differences to calculate the span.
				roof_span_m = Math.sqrt(length**2+width**2)
				roof_span_ft = OpenStudio.convert(roof_span_m, 'm','ft').get
				runner.registerInfo(" Roof surface span = #{roof_span_ft}.")
				if roof_span_ft > attic_roof_span
					attic_roof_span = roof_span_ft
				end
			end
			if surf.surfaceType == 'Floor' and construction_stds.intendedSurfaceType.to_s.include?('AtticFloor')
				# Skips everything but Roofs. Assumes construction_stds.intendedSurfaceType.is_initialized. Could error out if its not initialized...					
				#space_is_attic = true
				runner.registerInfo("Surface is Attic Floor.")
				floor_name = surf.name.get
				attic_floors << floor_name
				runner.registerInfo("Attic Floor list is: #{attic_floors}.")
				# Add surface floor area to attic floor area
				surface_floor_area_m2 = surf.netArea
				#runner.registerInfo("Floor Area is #{floor_area_m2} m2.")  
				surface_floor_area_ft2 = OpenStudio.convert(surface_floor_area_m2, 'm^2','ft^2').get
				attic_floor_area = attic_floor_area + surface_floor_area_ft2
				# Calculate the floor span by saving the longest 
				#runner.registerInfo("finding  wall vertices.")
				vertices = surf.vertices
				# Find the distance between 2 points on the same z axis
				length = nil
				width = nil
				x0 = nil
				y0 = nil
				z0 = nil
				# Find the x and y differences
				vertices.each_with_index do |vertex, i|
					#Once the values are populated, skip the rest of the vertices.
					if i == 0
						x0 = vertex.x
						y0 = vertex.y
						z0 = vertex.z
						#runner.registerInfo("Vertices = #{x0}, #{y0}, #{z0}.")
					else 
						if vertex.z == z0
							length = (x0 - vertex.x).abs
							width = (y0 - vertex.y).abs
							#runner.registerInfo("Vertices (m) = #{length}, #{width}.")				
						end
					end
				end
				runner.registerInfo("Vertices = #{length}, #{width}.")
				#Use x and y differences to calculate the span.
				floor_span_m = Math.sqrt(length**2+width**2)
				floor_span_ft = OpenStudio.convert(floor_span_m, 'm','ft').get
				#runner.registerInfo(" Floor surface span = #{floor_span_ft}.")
				if floor_span_ft > attic_floor_span
					attic_floor_span = floor_span_ft
				end
			end
		end
		#runner.registerInfo("Attic Roof list is: #{attic_roofs}.")
		#runner.registerInfo("Attic Floor list is: #{attic_floors}.")
		#runner.registerInfo("Attic Floor Area = #{attic_floor_area}.")
		#runner.registerInfo("Attic Floor Area = #{attic_roof_area}.")
		
		if 	not attic_name.nil? or not attic_roofs == []
			attic = {
			'atticName' => attic_name,
			'atticType' => attic_type,
			'atticArea' => attic_floor_area.round(2),
			'atticLength' => attic_floor_span.round(2),
			'roofArea' => attic_roof_area.round(2),
			'roofSpan' => attic_roof_span.round(2),
			'attachedToFrameFloors' => attic_floors,
			'attachedToRoofs' => attic_roofs
			}
			#runner.registerInfo("Attic is: #{attic}.")
			attics << attic
		end	
	end
	return attics
end

def get_atticandroof(idf, model, runner, user_arguments, sql)

    # AtticAndRoofs
	atticAndRoofs = [] #Used for the new code, which are the 2nd set of obejcts reported.
	counter = 0 # Limits the number of objects to be created to 2.
	
	#ONLY ATTIC AND ROOF SURFACES - Get each surface and get information from each surface that is an attic or roof surface.
	model.getSurfaces.each do |surf|
		# Skip surfaces that aren't attics or roofs (changed the old code to allow for internal walls)
		next if surf.surfaceType == 'Wall'
		# Skip surfaces with no construction. 
		#Question: If there is no construction should we exclude it or assume basic internal design?
		const = surf.construction
		next if const.empty?
		const = const.get
		# Convert construction base to construction
		const = const.to_Construction.get
		#runner.registerInfo("Construction is #{const}.")  
		# Get the area
		area_m2 = surf.netArea
		#runner.registerInfo("Area is #{area_m2} m2.")  
		# Area (ft2)
		area_ft2 = OpenStudio.convert(area_m2, 'm^2','ft^2').get
		#Get Surface Name
		wall_name = surf.name.get
		#runner.registerInfo("Surface Name is #{wall_name}.")  
		# Determine if the surface is an internal or external wall. If its internal, we may have to default the assembly design.
		if surf.outsideBoundaryCondition == 'Outdoors'
			exterior_adjacent_to = 'Ambient'
		elsif surf.outsideBoundaryCondition == 'Ground' || 'Foundation'
			exterior_adjacent_to = 'Ground'
		elsif surf.outsideBoundaryCondition == 'Zone' || 'Adiabatic' || 'Surface'
			exterior_adjacent_to = 'Living Space'
		else
			exterior_adjacent_to = 'OTHER_EXTERIOR_ADJACENT_TO'
		end
		#runner.registerInfo("Exterior Adjacent To is #{exterior_adjacent_to}.")  
		
		# Get the layers from the construction
		layers = const.layers
		# Find the main stud layer. This is a function in construction.rb created by NREL
		sl_i = const.structural_layer_index
		# Skip and warn if we can't find a structural layer
		if sl_i.nil?
			runner.registerInfo("Cannot find structural layer in wall construction #{const.name}; this construction will not be included in the LCA calculations.  To ensure that the LCA calculations work, you must specify the Standards Information fields in the Construction and its constituent Materials.  Use the CEC2013 enumerations.")  
		next
		end
		
		#Inialized insulations array.
		insulations = []
		
		#Find characteristics of the surface.
		
		# Thickness of the wall
		thickness_in = layers[sl_i].nist_thickness_inches
		
		# Interior rigid insulation r-value
		#This is an R Value, but we need to determine the material.
		if const.rigid_insulation_r_value(sl_i, 'interior').nil?
			int_r_ip = 0
		else
			int_r_ip = const.rigid_insulation_r_value(sl_i, 'interior')
		end
		#runner.registerInfo("Insulation R is #{int_r_ip}.")  
		interior_rigid_thickness = int_r_ip / 5 # Assumes XPS and R=5 per inch.
		
		if int_r_ip > 0
			insulationInt = {
				'insulationMaterial' => ins_mat,
				'insulationThickness' => interior_rigid_thickness.round(1),
				'insulationNominalRValue' => int_r_ip.round(1),
				'insulationInstallationType' => 'CONTINUOUS',
				'insulationLocation' => 'INTERIOR'
			}
			#runner.registerInfo("Insulation = #{insulationInt}")
			insulations << insulationInt
		end
		
		# Cavity R-value. We need to determine the material.		
		if layers[sl_i].nist_cavity_insulation_r_value.nil?
			cav_r_ip = 0
		else
			cav_r_ip = layers[sl_i].nist_cavity_insulation_r_value
		end
		#runner.registerInfo("Interior Rigid Insulation R is #{cav_r_ip}.")  
		interior_cavity_thickness = cav_r_ip / 3.71 # Assumes fiberglass batt and R=3.71 per inch. 
		
		if cav_r_ip > 0
			insulationCav = {
				'insulationMaterial' => ins_mat,
				'insulationThickness' => cav_thickness,
				'insulationNominalRValue' => cav_r_ip,
				'insulationInstallationType' => 'CAVITY',
				'insulationLocation' => 'INTERIOR'
			}
			#runner.registerInfo("Cavity Insulation = #{insulationCav}")
			insulations << insulationCav
		end
		
		# Exterior rigid insulation r-value		
		if const.rigid_insulation_r_value(sl_i, 'exterior') .nil?
			ext_r_ip = 0
		else
			ext_r_ip = const.rigid_insulation_r_value(sl_i, 'exterior') 
		end
		#runner.registerInfo("Exterior Rigid Insulation R is #{ext_r_ip}.")  
		exterior_rigid_thickness = ext_r_ip / 6 # Assumes polyiso and R-6 per inch.
		
		if ext_r_ip > 0
			insulationExt = {
				'insulationMaterial' => ins_mat,
				'insulationThickness' => exterior_rigid_thickness.round(1),
				'insulationNominalRValue' => ext_r_ip.round(1),
				'insulationInstallationType' => 'CONTINUOUS',
				'insulationLocation' => 'EXTERIOR'
			}
			#runner.registerInfo("Insulation = #{insulationExt}")
			insulations << insulationExt
		end
		
		#Hard coded the insulation to all 3. Need to change this.
		attic_roof_insulations = insulations
		attic_floor_insulations = insulations
		attic_ceiling_insulations = insulations
		
		# Stud spacing (only applies to framed walls)
		oc_in = layers[sl_i].nist_stud_spacing_inches      
		
		# Material is a limited list used to identify the wall type (wood, steel, concrete).
		# This is no sufficient for the new list.
		mat = layers[sl_i].nist_wall_material
		#runner.registerInfo("Roof Structure Material = #{mat}")
		
		#Need to find all subsurfaces on a wall surface and determine which are skylights.
		#Then pull the information for each to add to the array.
		#This will require a do loop through each wall surface.
		skylights = []

		#if subsurface is a skylight, then populate the skylight object.
		#Only need to populate the physical components or the performance specs. Use performance specs from OSM.
		#Can I pull this info from OSM or do I have to go through each E+ skylight object, match the surface name, and pull specs?
		
		#runner.registerInfo("finding all skylights in this attic/roof.")
		surf.subSurfaces.each do |ss|
			#if ss is a skylight, else its a door.
			#runner.registerInfo("found subsurface.")
			subsurface_type = ss.subSurfaceType
			#runner.registerInfo("found subsurface type: #{subsurface_type}.")
			# Determine if the subsurface is a skylight or other
			if subsurface_type == 'Skylight'
				operable = false		# hard code to No
				skylight_name = ss.name
				runner.registerInfo("found subsurface #{skylight_name}.")
				skylight_area_m2 = ss.grossArea
				#runner.registerInfo("found subsurface #{skylight_name} with area #{skylight_area}.")
				skylight_area_ft2 = OpenStudio.convert(skylight_area_m2, 'm^2','ft^2').get
				skylight_z_max = -1000000000
				skylight_z_min = 1000000000
				#runner.registerInfo("finding subsurface vertices.")
				vertices = ss.vertices
				#runner.registerInfo("found subsurface vertices.")
				vertices.each do |vertex|
					z = vertex.z
					if z < skylight_z_min
						skylight_z_min = z
					else next
					end					
					if z > skylight_z_max
						skylight_z_max = z
					else
					end
				end
				#runner.registerInfo("found max and min z vertices.")
				skylight_height_m = skylight_z_max - skylight_z_min
				runner.registerInfo("skylight height = #{skylight_height_m}.")
				#Convert to IP
				skylight_height_ft = OpenStudio.convert(skylight_height_m, 'm','ft').get

				# Take skylight name and use it to find the specs.
				# Parse the skylight name, upcase the letters, and then put back together. The periods are causing the problem.
				skylight_name_string = skylight_name.to_s
				runner.registerInfo("skylight name now string: #{skylight_name_string}.")
				skylight_name_capped = skylight_name_string.upcase
				runner.registerInfo("skylight name capped: #{skylight_name_capped}.")
				# query the SQL file including the row name being a variable. Treat like its in a runner.
				# U-Factor Query
				query = "SELECT Value
				  FROM tabulardatawithstrings
				  WHERE ReportName='EnvelopeSummary'
				  AND ReportForString= 'Entire Facility'
				  AND TableName='Exterior Fenestration'
				  AND ColumnName='Glass U-Factor'
				  AND RowName='#{skylight_name_capped}'
				  AND Units='W/m2-K'"       
				#runner.registerInfo("Query is #{query}.")
				u_si = sql.execAndReturnFirstDouble(query)
				runner.registerInfo("U-SI value was found: #{u_si}.")
				if u_si.is_initialized
				  u_si = u_si.get
				else
				  u_si = 0
				end
				u_ip = OpenStudio.convert(u_si, 'W/m^2*K','Btu/hr*ft^2*R').get
				# SHGC Query
				query = "SELECT Value
				  FROM tabulardatawithstrings
				  WHERE ReportName='EnvelopeSummary'
				  AND ReportForString= 'Entire Facility'
				  AND TableName='Exterior Fenestration'
				  AND ColumnName='Glass SHGC'
				  AND RowName='#{skylight_name_capped}'"       
				#runner.registerInfo("Query is #{query}.")
				shgc = sql.execAndReturnFirstDouble(query)
				runner.registerInfo("SHGC value was found: #{shgc}.")
				if shgc.is_initialized
				  shgc = shgc.get
				else
				  shgc = 0
				end
				
				# VT Query
				query = "SELECT Value
				  FROM tabulardatawithstrings
				  WHERE ReportName='EnvelopeSummary'
				  AND ReportForString= 'Entire Facility'
				  AND TableName='Exterior Fenestration'
				  AND ColumnName='Glass Visible Transmittance'
				  AND RowName='#{skylight_name_capped}'"       
				#runner.registerInfo("Query is #{query}.")
				vt = sql.execAndReturnFirstDouble(query)
				runner.registerInfo("U-SI value was found: #{vt}.")
				if vt.is_initialized
				  vt = vt.get
				else
				  vt = 0
				end
				
				skylight = {
					'name'=> skylight_name,
					'operable'=> operable,
					'area'=> skylight_area_ft2.round(2),
					'height' => skylight_height_ft.round(2),	# TO DO  - need to add to enumerations
					'quantity'=> 1,			# Hard coded until we introduce HPXML
					'frameType'=> 'NONE_FRAME_TYPE',		# Hard coded until we introduce Construction Fenstration Information option
					'glassLayer'=> 'NONE_GLASS_LAYERS',		# Hard coded until we introduce Construction Fenstration Information option
					'glassType'=> 'NONE_GLASS_TYPE',		# Hard coded until we introduce Construction Fenstration Information option
					'gasFill'=> 'NONE_GAS_FILL',			# Hard coded until we introduce Construction Fenstration Information option
					'shgc'=> shgc.round(4),
					'visualTransmittance'=> vt.round(4),
					'uFactor'=> u_ip.round(4)
				}
				#runner.registerInfo("skylight = #{skylight}")
				skylights << skylight				
			else	
				runner.registerInfo("subsurface type is not a skylight and will be skipped: #{subsurface_type}.")
			end
		end

		deck_type = 'WOOD'
		roof_type = 'SHINGLES'
		roof_area = 30
		pitch = 8
		roof_area_ft2 = 600 		
		rafters_size = '_2X8'
		rafters_mat = 'WOOD_RAFTER'
		roof_span = 35
		attic_type = 'VENTING_UNKNOWN_ATTIC'
		attic_area_ft2 = 300
		attic_length_ft = 30
		attic_and_roof_name = 'Test Name'
		
		#Populate the surface object
		#runner.registerInfo("Creating Attic and Roof object.")
		atticAndRoof = {
			'atticFloorInsulations'=> attic_floor_insulations,		# Array of the insulations just like walls - only used if 
			'atticRoofInsulations'=> attic_roof_insulations,		# Array of the insulations just like walls
			'atticCeilingInsulations'=> attic_ceiling_insulations,	# Array of the insulations just like walls - only used if ceiling is not the roof
			'atticAndRoofName' => attic_and_roof_name,				# Name should the Attic/Roof N where N is a counter.
			'deckType' => deck_type,								# roof deck material - wood default
			'roofType' => roof_type,								# roof finishing material (shingles, etc)
			'radiantBarrier' => true,								# defaulted to yes; search roof layers for barrier
			'roofArea' => roof_area_ft2.round(2),					# sum of roof surfaces for the specific zone
			'raftersSize' => rafters_size,							# defined in composite layer standard information
			'raftersMaterials' => rafters_mat,						# defined in composite layer standard information
			'pitch' => pitch,										# defined by using the slope of the roof surfaces
			'roofSpan' => roof_span,								# use the longest axis of the roof 
			'atticType' => attic_type,								# User defined? How to deduce?
			'atticArea' => attic_area_ft2.round(2),					# floor area for the attic zone
			'atticLength' => attic_length_ft.round(2),				# use the longest axis of the zone
			'skyLights' => skylights,								# all skylights subsurfaces in all roof surfaces 
		}
		#runner.registerInfo("Attic/Roof = #{atticAndRoof}")
		counter = counter + 1
		#Add surface to the object
		if counter < 2 # Remove counter once we update this object creation.
			atticAndRoofs << atticAndRoof
		else
		end
    end
	
	return atticAndRoofs
	
end

def get_atticandroof2(idf, model, runner, user_arguments, sql)

    # AtticAndRoofs2
	# This updates the old atticandroof to provide actual results.
	atticAndRoofs = [] #Used for the new code, which are the 2nd set of obejcts reported.
	atticFloors = []
	atticRoofs = []
	# Define variables and call on user inputs.
	attic_type = runner.getStringArgumentValue('attic_type',user_arguments)
	# Identify the spaces that are Attics
	
	model.getSpaces.each do |space|
		attic_name = nil
		#define attic floor areas and spans
		# These will be populated from a combination of all roof and floor surfaces in the attic space.
		# define reused variables for each space
		attic_floor_area = 0
		attic_roof_area = 0
		attic_roof_span = 0
		attic_floor_span = 0
		attic_floors = []
		attic_roofs = []
		attic_skylights = []
		attic_floor_insulations = []
		attic_roof_insulations = []
		attic_ceiling_insulations = []
		attic_deck_type = nil
		attic_roof_type = nil
		attic_radiant_barrier = nil
		attic_rafters_size = nil
		attic_rafters_mat = nil
		attic_pitch = nil
		#space_is_attic = false
		attic_name = nil
		# define space name
		space_name = space.name.get.to_s
		runner.registerInfo("Space is #{space_name}.")
		# search surfaces in the space for roof surface 
		model.getSurfaces.each do |surf|
			surface_space_object = surf.space.get
			#runner.registerInfo("Surface is located in object: #{surface_space_object}.") 
			surface_space = surface_space_object.name.get.to_s
			#runner.registerInfo("Surface is located in #{surface_space}.")  
			# If the surface is in the space, add the surface if its a attic roof or attic floor.
			if space_name == surface_space
				# Define the construction
				const = surf.construction
				const = const.get
				const = const.to_Construction.get
				# Define the Measure Tags Set
				construction_stds = const.standardsInformation
				#Get Surface Name
				surface_name = surf.name.get
				# Get the area
				area_m2 = surf.netArea
				#runner.registerInfo("Area is #{area_m2} m2.")  
				# Area (ft2)
				area_ft2 = OpenStudio.convert(area_m2, 'm^2','ft^2').get
				#runner.registerInfo("Surface is in the Space being considered.")
				
				# For the given surface in the given space, determine if its an attic roof or attic floor.
				if surf.surfaceType == 'RoofCeiling' and construction_stds.intendedSurfaceType.to_s.include?('AtticRoof')		
					#runner.registerInfo("Surface construction is AtticRoof.")
					attic_name = space_name
					roof_name = surface_name
					roof_area_ft2 = area_ft2
					# Add to attic floor area.
					attic_roof_area = attic_roof_area + roof_area_ft2
					# Get the layers from the construction
					layers = const.layers
					# Find the main stud layer. This is a function in construction.rb created by NREL
					sl_i = const.structural_layer_index
					# Skip and warn if we can't find a structural layer
					if sl_i.nil?
						runner.registerInfo("Cannot find structural layer in wall construction #{const.name}; this construction will not be included in the LCA calculations.  To ensure that the LCA calculations work, you must specify the Standards Information fields in the Construction and its constituent Materials.  Use the CEC2013 enumerations.")  
					next
					end	
		
					# Determine if the surface is an internal or external wall. If its internal, we may have to default the assembly design.
					# Check if the construction has measure tags. If so, then use those. Otherwise interpret the model.
					
					if construction_stds.intendedSurfaceType.is_initialized
						surface_type = construction_stds.intendedSurfaceType.to_s
						#runner.registerInfo("Construction Type = #{surface_type}.")
						if surface_type == 'ExteriorRoof'
							exterior_adjacent_to = 'AMBIENT'
						elsif surface_type == 'AtticRoof'
							exterior_adjacent_to = 'AMBIENT'
						elsif surface_type == 'DemisingRoof'
							exterior_adjacent_to = 'LIVING_SPACE'	
						elsif surface_type == 'GroundContactRoof'
							exterior_adjacent_to = 'GROUND'		
						else
							exterior_adjacent_to = 'OTHER_EXTERIOR_ADJACENT_TO'
						end
					else
						if surf.outsideBoundaryCondition == 'Outdoors'
							exterior_adjacent_to = 'AMBIENT'
						elsif surf.outsideBoundaryCondition == 'Ground' || 'Foundation'
							exterior_adjacent_to = 'GROUND'
						elsif surf.outsideBoundaryCondition == 'Zone' || 'Adiabatic' || 'Surface'
							exterior_adjacent_to = 'LIVING_SPACE'
						else
							exterior_adjacent_to = 'OTHER_EXTERIOR_ADJACENT_TO'
						end	
					end
					#runner.registerInfo("Exterior Adjacent To is #{exterior_adjacent_to}.")
					
					# Calculate pitch of roof surface
					# Use the tilt of the roof surface and convert to pitch value using the formula: tan(tilt)*12=pitch
					radians = surf.tilt.to_s.to_f
					#runner.registerInfo(" Radians = #{radians}.")
					surface_angle = radians * 57.295779513
					#runner.registerInfo(" Roof angle = #{surface_angle}.")	 # Tilt is in radians; 1 radian = 57.295779513 degrees
					pitch = Math.tan(radians) * 12 # pitch is the tangent of the radians multiplied by 12
					#runner.registerInfo(" Roof surface pitch = #{pitch}.")
					
					# Calculate the roof span
					#runner.registerInfo("finding  wall vertices.")
					vertices = surf.vertices
					# Find the distance between 2 points on the same z axis
					length = nil
					width = nil
					x0 = nil
					y0 = nil
					z0 = nil
					# Find the x and y differences
					vertices.each_with_index do |vertex, i|
						#Once the values are populated, skip the rest of the vertices.
						next if length != nil	
						if i == 0
							x0 = vertex.x
							y0 = vertex.y
							z0 = vertex.z
							#runner.registerInfo("Vertices = #{x0}, #{y0}, #{z0}.")
						else 
							if vertex.z == z0
								length = (x0 - vertex.x).abs
								width = (y0 - vertex.y).abs
								#runner.registerInfo("Vertices (m) = #{length}, #{width}.")				
							end
						end
					end
					#runner.registerInfo("Vertices = #{length}, #{width}.")
					#Use x and y differences to calculate the span.
					roof_span_m = Math.sqrt(length**2+width**2)
					roof_span_ft = OpenStudio.convert(roof_span_m, 'm','ft').get
					#runner.registerInfo(" Roof surface span = #{roof_span_ft}.")
					
					#set surface roof span equal to the attic roof span.
					if attic_roof_span < roof_span_ft
						attic_roof_span = roof_span_ft
					end
					
					# Identify the name of the space for which the roof surface is attached to.
					space = surf.space.get
					roof_attached_to_space = space.name.to_s
					#runner.registerInfo(" Roof surface attached to space #{roof_attached_to_space}.")
					
					# TO DO: Update to get the width and length of the sloped roof surface
					#find roof width
					roof_z_max = -1000000000
					roof_z_min = 1000000000
					#runner.registerInfo("found subsurface vertices.")
					vertices.each do |vertex|
						z = vertex.z
						if z < roof_z_min
							roof_z_min = z
						else next
						end
						if z > roof_z_max
							roof_z_max = z
						else
						end
					end
					#runner.registerInfo("found max and min z vertices.")
					roof_height_m = roof_z_max - roof_z_min
					#runner.registerInfo("wall height = #{wall_height_m}.")
					#Convert to IP
					roof_height_ft = OpenStudio.convert(roof_height_m, 'm','ft').get	
					roof_length_ft = roof_area_ft2 / roof_height_ft
					
					#Find characteristics of the structural layer using Material Standard Information Measure Tags
					# Assumes a single structural layer. For example, does not capture SIPs manually defined by mutliple layers.
					# These are the tags for the structural layer.
					
					sli_stds = layers[sl_i].standardsInformation
					
					if sli_stds.standardsCategory.is_initialized
						category = sli_stds.standardsCategory.get.to_s
						#runner.registerInfo("Structural Layer Category = #{category}.")
					end
					if sli_stds.standardsIdentifier.is_initialized
						identifier = sli_stds.standardsIdentifier.get.to_s
						#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
					end
					if sli_stds.compositeFramingMaterial.is_initialized
						frame_mat = sli_stds.compositeFramingMaterial.get.to_s
						#runner.registerInfo("Structural Layer Framing Material = #{frame_mat}.")
					end
					if sli_stds.compositeFramingConfiguration.is_initialized
						frame_config = sli_stds.compositeFramingConfiguration.get.to_s
						#runner.registerInfo("Structural Layer Framing Config = #{frame_config}.")
					end
					if sli_stds.compositeFramingDepth.is_initialized
						frame_depth = sli_stds.compositeFramingDepth.get.to_s
						#runner.registerInfo("Structural Layer Framing Depth = #{frame_depth}.")
					end
					if sli_stds.compositeFramingSize.is_initialized
						frame_size = sli_stds.compositeFramingSize.get.to_s
						#runner.registerInfo("Structural Layer Framing Size = #{frame_size}.")
					end
					if sli_stds.compositeCavityInsulation.is_initialized
						cavity_ins = sli_stds.compositeCavityInsulation.get.to_i
						#runner.registerInfo("Structural Layer Cavity Insulation = #{cavity_ins}.")
					end
					
					# Find interior and exterior layer for the construction to define the finishes
					# Layers from exterior to interior
					il_identifier = nil
					el_identifier = nil
					roof_type = nil
					roof_interior_finish = nil
					vapor_barrier = nil
					air_barrier = false
					
					layers.each_with_index do |layer, i|
						# Skip fenestration, partition, and airwall materials
						layer = layer.to_OpaqueMaterial
						next if layer.empty?
						layer = layer.get
						#runner.registerInfo("layer = #{layer}.")
						if i == 0
							ext_layer = layer
							#runner.registerInfo("exterior layer = #{ext_layer}.")
							el_i_stds = layer.standardsInformation
							if el_i_stds.standardsCategory.is_initialized
								el_category = el_i_stds.standardsCategory.get.to_s
								#runner.registerInfo("Exterior Layer Category = #{el_category}.")
							end
							if el_i_stds.standardsIdentifier.is_initialized
								el_identifier = el_i_stds.standardsIdentifier.get.to_s
								#runner.registerInfo("Exterior Layer Identifier = #{el_identifier}.")
							end				
						else
							int_layer = layer
							#runner.registerInfo("interior layer = #{int_layer}.")
							il_i_stds = layer.standardsInformation
							if il_i_stds.standardsCategory.is_initialized
								il_category = il_i_stds.standardsCategory.get.to_s
								#runner.registerInfo("Interior Layer Category = #{il_category}.")
							end
							if il_i_stds.standardsIdentifier.is_initialized
								il_identifier = il_i_stds.standardsIdentifier.get.to_s
								#runner.registerInfo("Interior Layer Identifier = #{il_identifier}.")
							end
					  end
					end
					#runner.registerInfo("Interior Layer = #{il_identifier}.")
					#runner.registerInfo("Exterior Layer = #{el_identifier}.")
					
					
					# Convert identifiers to interior wall finish and wall siding for exterior walls.		
					# Interior Wall Finish
					# Category could be Bldg Board and Siding - Limited to gypsum board, otherwise its "other"
					if il_identifier != nil
						if il_identifier.include?('Gypsum Board - 1/2 in.') or il_identifier.include?('Gypsum Board - 3/8 in.')
							interior_wall_finish = 'GYPSUM_REGULAR_1_2'
						elsif il_identifier.include?('Gypsum Board - 3/4 in.') or il_identifier.include?('Gypsum Board - 5/8 in.')
							interior_wall_finish = 'GYPSUM_REGULAR_5_8'
						else
							interior_wall_finish = 'OTHER_FINISH'
						end
					else
						interior_wall_finish = 'NONE'
					end
					#runner.registerInfo("Interior Layer Thickness = #{interior_wall_finish}.")
					
					# Roof Type - Shingles, etc.
					# Category could be Bldg Board and Siding or Roofing or Concrete
					# Question: Should we consider CLT option?
					# Currently does not include EXPANDED_POLYSTYRENE_SHEATHING or PLASTIC_RUBBER_SYNTHETIC_SHEETING
					# These are not typical on a house.
					if el_identifier != nil
						if el_identifier.include?('Metal')					# Assumes metal is steel. Currently missing aluminum siding
							roof_type = 'METAL_SURFACING'
						elsif el_identifier.include?('Asphalt') and el_identifier.include?('shingles')
							roof_type = 'ASPHALT_OR_FIBERGLASS_SHINGLES'
						elsif el_identifier.include?('Wood Shingles') or el_identifier.include?('Woods')
							roof_type = 'WOOD_SHINGLES_OR_SHAKES'
						elsif el_identifier.include?('Shingles')
							roof_type = 'SHINGLES'
						elsif el_identifier.include?('Concrete')
							roof_type = 'CONCRETE_ROOF'
						elsif el_identifier.include?('tile') or el_identifier.include?('Tile') or el_identifier.include?('Slate')
							roof_type = 'SLATE_OR_TILE_SHINGLES'	
						else
							roof_type = 'OTHER_ROOF_TYPE'
						end
					else
						roof_type = 'SHINGLES'
					end
					#runner.registerInfo("Roof Exterior Layer = #{roof_type}.")
					
					#Determine if there is a air barrier or vapor barrier
					# For roofs, this is assumed to be a radiant barrier.
					radiant_barrier = nil
					# Same code as for walls in case we want to expand to specific barrier materials in the future.		
					layers.each_with_index do |layer, i|
						# Skip fenestration, partition, and airwall materials
						layer = layer.to_OpaqueMaterial
						next if layer.empty?
						layer = layer.get
						#runner.registerInfo("layer = #{layer}.")
						barrier_stds = layer.standardsInformation
						if barrier_stds.standardsCategory.is_initialized
							barrier_category = barrier_stds.standardsCategory.get.to_s
							if barrier_category.include?('Building Membrane')
								#runner.registerInfo("Barrier Category = #{barrier_category}.")
								if barrier_stds.standardsIdentifier.is_initialized
									barrier_identifier = barrier_stds.standardsIdentifier.get.to_s
									#runner.registerInfo("Barrier Identifier = #{barrier_identifier}.")
									if barrier_identifier.include?('Vapor')		# Should we add custom identifiers?
										if barrier_identifier.include?('1/16')	# Need to update these values since even 6 mil is too small
											vapor_barrier = 'POLYETHELYNE_3_MIL'
										elsif barrier_identifier.include?('1/8')
											vapor_barrier = 'POLYETHELYNE_3_MIL'
										elsif barrier_identifier.include?('1/4')
											vapor_barrier = 'POLYETHELYNE_6_MIL'
										else
											vapor_barrier = 'PSK' # Default value
										end
									else	
										air_barrier = true
									end
								end				
							end
						end
					end
					#runner.registerInfo("Air Barrier = #{air_barrier}.")
					#runner.registerInfo("Vapor Barrier = #{vapor_barrier}.")
					if air_barrier == true or not vapor_barrier.nil?
						radiant_barrier = true
					else
						radiant_barrier = false
					end	
					
					#Inialize insulations array here because approach to insulation varies by wall type.
					insulations = []
				
					# Define roof framing type based on the measure tags	
					# missing match for ???
					
					# WOOD_STUD Wall Type
					if category.to_s.include?('Wood Framed') # Should only be Wood Framed Rafter Roof
						
						# define the wall type
						rafters_material = 'WOOD_RAFTER'
						
						# define the framing size
						if frame_size == '2x2'
							rafters_size = '_2X2'
						elsif frame_size == '2x3'
							rafters_size = '_2X3'	
						elsif frame_size == '2x4'
							rafters_size = '_2X4'
						elsif frame_size == '2x6'
							rafters_size = '_2X6'
						elsif frame_size == '2x8'
							rafters_size = '_2X8'
						elsif frame_size == '2x10'
							rafters_size = '_2X10'	
						elsif frame_size == '2x12'
							rafters_size = '_2X12'
						elsif frame_size == '2x14'
							rafters_size = '_2X14'
						elsif frame_size == '2x16'
							rafters_size = '_2X16'	
						else
							rafters_size = 'OTHER_SIZE'
						end
						#runner.registerInfo("Rafter Size = #{rafters_size}.")
						
						# define On Center
						#fc = frame_config.get.downcase
						#runner.registerInfo("OC = #{fc}.")
						on_center_in = /(\d+)/.match(frame_config).to_s.to_f
						#runner.registerInfo("OC = #{on_center_in}.")
						
						# Define framing cavity thickness
						if frame_depth == '3_5In'
							cav_thickness = 3.5
						elsif frame_depth == '5_5In'
							cav_thickness = 5.5
						elsif frame_depth == '7_25In'
							cav_thickness = 7.25
						elsif frame_depth == '9_25In'
							cav_thickness = 9.25
						elsif frame_depth == '11_25In'
							cav_thickness = 11.25	
						else
							cav_thickness = nil
						end
						#runner.registerInfo("Cavity Thickness = #{cav_thickness}.")
						
						# define the cavity insulation
						if cavity_ins.nil?
							cav_r_ip = 0
							ins_r_value_per_in = 0
						else
							cav_r_ip = cavity_ins
							#runner.registerInfo("Cavity R Value = #{cav_r_ip}.")
							if not cav_thickness.nil?
								ins_r_value_per_in = cav_r_ip / cav_thickness
							else
								ins_r_value_per_in = nil # If this occurs, there is something wrong.
							end
						end
						#runner.registerInfo("Cavity Insulation R is #{cav_r_ip}.") 
						#runner.registerInfo("Cavity Insulation R per Inch is #{ins_r_value_per_in}.")
						
						# Assume cavity insulation for wood framing is either fiberglass batt or cellulose; are there others to include?
						if not ins_r_value_per_in.nil?
							if ins_r_value_per_in < 0.1
								ins_mat = 'NONE'
							elsif ins_r_value_per_in < 3.6 and ins_r_value_per_in > 0.01
								ins_mat = 'BATT_FIBERGLASS'
							else
								ins_mat = 'LOOSE_FILL_CELLULOSE'
							end
						else
							ins_mat = 'UNKNOWN'
						end
						#runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
						
						if cav_r_ip > 0
							insulationCav = {
								'insulationMaterial' => ins_mat,
								'insulationThickness' => cav_thickness,
								'insulationNominalRValue' => cav_r_ip,
								'insulationInstallationType' => 'CAVITY',
								'insulationLocation' => 'INTERIOR'
							}
							#runner.registerInfo("Cavity Insulation = #{insulationCav}")
							insulations << insulationCav
						end
						
						concrete_value = {}
						
						clt_values = {}
						
					# Metal Framed Roof Type
					elsif category.to_s.include?('Metal Framed')
						# define the wall type
						rafters_material = 'METAL_RAFTER'
						
						# define the framing size
						if frame_size == '2x2'
							rafters_size = '_2X2'
						elsif frame_size == '2x3'
							rafters_size = '_2X3'	
						elsif frame_size == '2x4'
							rafters_size = '_2X4'
						elsif frame_size == '2x6'
							rafters_size = '_2X6'
						elsif frame_size == '2x8'
							rafters_size = '_2X8'
						elsif frame_size == '2x10'
							rafters_size = '_2X10'	
						elsif frame_size == '2x12'
							rafters_size = '_2X12'
						elsif frame_size == '2x14'
							rafters_size = '_2X14'
						elsif frame_size == '2x16'
							rafters_size = '_2X16'	
						else
							rafters_size = 'OTHER_SIZE'
						end
						#runner.registerInfo("Rafter Size = #{rafters_size}.")
						

						# define On Center
						#fc = frame_config.get.downcase
						#runner.registerInfo("OC = #{fc}.")
						on_center_in = /(\d+)/.match(frame_config).to_s.to_f
						#runner.registerInfo("OC = #{on_center_in}.")
						
						# Define framing cavity thickness
						if frame_depth == '3_5In'
							cav_thickness = 3.5
						elsif frame_depth == '5_5In'
							cav_thickness = 5.5
						elsif frame_depth == '7_25In'
							cav_thickness = 7.25
						elsif frame_depth == '9_25In'
							cav_thickness = 9.25
						elsif frame_depth == '11_25In'
							cav_thickness = 11.25	
						else
							cav_thickness = nil
						end
						#runner.registerInfo("Cavity Thickness = #{cav_thickness}.")
						
						# define the cavity insulation
						if cavity_ins.nil?
							cav_r_ip = 0
							ins_r_value_per_in = 0
						else
							cav_r_ip = cavity_ins
							#runner.registerInfo("Cavity R Value = #{cav_r_ip}.")
							if not cav_thickness.nil?
								ins_r_value_per_in = cav_r_ip / cav_thickness
							else
								ins_r_value_per_in = nil # If this occurs, there is something wrong.
							end
						end
						#runner.registerInfo("Cavity Insulation R is #{cav_r_ip}.") 
						#runner.registerInfo("Cavity Insulation R per Inch is #{ins_r_value_per_in}.")
						
						# Assume cavity insulation for wood framing is either fiberglass batt or cellulose; are there others to include?
						if not ins_r_value_per_in.nil?
							if ins_r_value_per_in < 0.1
								ins_mat = 'NONE'
							elsif ins_r_value_per_in < 3.6 and ins_r_value_per_in > 0.01
								ins_mat = 'BATT_FIBERGLASS'
							else
								ins_mat = 'LOOSE_FILL_CELLULOSE'
							end
						else
							ins_mat = 'UNKNOWN'
						end
						#runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
						
						if cav_r_ip > 0
							insulationCav = {
								'insulationMaterial' => ins_mat,
								'insulationThickness' => cav_thickness,
								'insulationNominalRValue' => cav_r_ip,
								'insulationInstallationType' => 'CAVITY',
								'insulationLocation' => 'INTERIOR'
							}
							#runner.registerInfo("Cavity Insulation = #{insulationCav}")
							insulations << insulationCav
						end

						concrete_value = {}
						
						clt_values = {}
						

					# SIPS Roof Type
					elsif category.to_s.include?('SIPS')
						# define the roof material type
						rafters_material = 'STRUCTURALLY_INSULATED_PANEL' 	# SIPs are not currently an option
						
						# define the framing size; there are no rafters for SIPs
						studs_size = 'OTHER_SIZE'
						#runner.registerInfo("Studs Size = #{studs_size}.")

						# define On Center
						#fc = frame_config.get.downcase
						#runner.registerInfo("OC = #{fc}.")
						on_center_in = 0
						#runner.registerInfo("OC = #{on_center_in}.")
						
						# parse the standard identifier;  eg SIPS - R55 - OSB Spline - 10 1/4 in.
						
						# find R value of the "cavity" of the SIP
						#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
						sips_r_value_ip =/(\d+)/.match(identifier).to_s.to_f
						#runner.registerInfo("SIPS R Value = #{sips_r_value_ip}.")
						
						# Define framing cavity thickness
						sips_thickness =/(\d+)\s(\d).(\d)/.match(identifier).to_s
						#runner.registerInfo("SIPs insulation thickness = #{sips_thickness}.")
						# assumes 7/16 OSB; missing metal splines and double splines
						if sips_thickness == '4 1/2'
							cav_thickness = (4.5 - 0.875)
						elsif sips_thickness == '6 1/2'
							cav_thickness = (6.5 - 0.875)
						elsif sips_thickness == '8 1/2'
							cav_thickness = (8.5 - 0.875)	
						elsif sips_thickness == '10 1/4'
							cav_thickness = (10.25 - 0.875)
						elsif sips_thickness == '12 1/4'
							cav_thickness = (12.25 - 0.875)	
						else
							cav_thickness = nil
						end
						#runner.registerInfo("SIPS Insulation Thickness = #{cav_thickness}.")
						
						# define the SIPs insulation
						if sips_r_value_ip.nil?
							cav_r_ip = 0
							ins_r_value_per_in = 0
						else
							cav_r_ip = sips_r_value_ip
							#runner.registerInfo("SIPs R Value = #{cav_r_ip}.")
							if not cav_thickness.nil?
								ins_r_value_per_in = cav_r_ip / cav_thickness
							else
								ins_r_value_per_in = nil # If this occurs, there is something wrong.
							end
						end
						#runner.registerInfo("SIPs Insulation R is #{cav_r_ip}.") 
						#runner.registerInfo("SIPs Insulation R per Inch is #{ins_r_value_per_in}.")
						
						# Assume rigid insulation for SIPs; are there others to include?
						if not ins_r_value_per_in.nil?
							if ins_r_value_per_in < 0.1
								ins_mat = 'NONE'
							elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
								ins_mat = 'RIGID_EPS'
							elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
								ins_mat = 'RIGID_XPS'
							elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
								ins_mat = 'RIGID_POLYISOCYANURATE'
							else
								ins_mat = 'RIGID_UNKNOWN'
							end
						else
							ins_mat = 'UNKNOWN'
						end
						#runner.registerInfo("SIPs Insulation is #{ins_mat}.")
						
						if cav_r_ip > 0
							insulationCav = {
								'insulationMaterial' => ins_mat,
								'insulationThickness' => cav_thickness,
								'insulationNominalRValue' => cav_r_ip,
								'insulationInstallationType' => 'CAVITY',
								'insulationLocation' => 'INTERIOR'
							}
							#runner.registerInfo("Cavity Insulation = #{insulationCav}")
							insulations << insulationCav
						end
						
						concrete_value = {}
						
						clt_values = {}


					elsif category.to_s.include?('Concrete') and not category.to_s.include?('Sandwich Panel')
						rafters_material = 'OTHER_MATERIAL'

						# solid concrete will not have framing or cavity insulation within the material
						studs_size = 'OTHER_SIZE'
						#runner.registerInfo("Studs Size = #{studs_size}.")
						on_center_in = 0
						#runner.registerInfo("OC = #{on_center_in}.")
						# Define concrete thickness
						concrete_thickness =/(\d+)\sin/.match(identifier).to_s
						#runner.registerInfo("Concrete thickness string = #{concrete_thickness}.")
						if concrete_thickness == '6 in'
							cav_thickness = 6
						elsif concrete_thickness == '8 in'
							cav_thickness = 8
						elsif concrete_thickness == '10 in'
							cav_thickness = 10	
						elsif concrete_thickness == '12 in'
							cav_thickness = 12
						else
							cav_thickness = nil
						end
						#runner.registerInfo("Concrete Thickness = #{cav_thickness}.")
						ins_mat = 'NONE'
						#runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
						# Currently creating the cavity insulation object, but could be deleted.
						# TO DO: How do we handle framing on the inside of the concrete wall?
						cav_r_ip = 0
						if cav_r_ip > 0
							insulationCav = {
								'insulationMaterial' => ins_mat,
								'insulationThickness' => cav_thickness,
								'insulationNominalRValue' => cav_r_ip,
								'insulationInstallationType' => 'CAVITY',
								'insulationLocation' => 'INTERIOR'
							}
							#runner.registerInfo("Cavity Insulation = #{insulationCav}")
							insulations << insulationCav
						end
						#Find concrete strength and reinforcement from standards identifier
						#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
						concrete_name = identifier.to_s
						#runner.registerInfo("Concrete Name = #{concrete_name}.")
						density =/(\d+)/.match(identifier).to_s.to_f
						#runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
						compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
						#runner.registerInfo("PSI = #{compressive_strength_value}.")

						# Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
						if compressive_strength_value < 2000
							compressive_strength = 'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
						elsif 	compressive_strength_value > 2000 and compressive_strength_value < 2750
							compressive_strength = '_2500_PSI'
						elsif 	compressive_strength_value > 2750 and compressive_strength_value < 3500
							compressive_strength = '_3000_PSI'
						elsif 	compressive_strength_value > 3500 and compressive_strength_value < 4500
							compressive_strength = '_4000_PSI'
						elsif 	compressive_strength_value > 4500 and compressive_strength_value < 5500
							compressive_strength = '_5000_PSI'
						elsif 	compressive_strength_value > 5500 and compressive_strength_value < 7000
							compressive_strength = '_6000_PSI'
						elsif 	compressive_strength_value > 7000
							compressive_strength = '_8000_PSI'
						else
							compressive_strength = 'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
						end
						
						# Define reinforcement - defaulted to 5 
						rebar_number = 5  # defaulted to 5 for no particular reason
						
						# Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
						if rebar_number = 4
							reinforcement = 'REBAR_NO_4'
						elsif rebar_number = 5
							reinforcement = 'REBAR_NO_5'
						elsif rebar_number = 6
							reinforcement = 'REBAR_NO_6'
						else
							reinforcement = 'UNSPECIFIED_CONCRETE_REINFORCEMENT'
						end
					
						concrete_value = {
							'concreteName' => concrete_name,
							'compressiveStrength' => compressive_strength,
							'reinforcement' => reinforcement
						}
						#runner.registerInfo("Concrete value = #{concrete_value}")
						
						clt_values = {}

					# Masonry Unit Walls - Assume concrete; ignores clay masonry; excludes block fill
					elsif category.to_s.include?('Masonry Units')
						wall_type = 'CONCRETE_MASONRY_UNIT'
						
						#Provide details on the masonry fill; currently not used for anything.
						if category.to_s.include?('Hollow')
							wall_fill_unused = 'HOLLOW'
						elsif category.to_s.include?('Solid')
							wall_fill_unused = 'SOLID'
						elsif category.to_s.include?('Fill')
							wall_fill_unused = 'FILL'
						else
							wall_fill_unused = 'UNKNOWN'
						end
						
						# ICF wall will not have framing or cavity insulation within the material
						studs_size = 'OTHER_SIZE'
						#runner.registerInfo("Studs Size = #{studs_size}.")
						on_center_in = 0
						#runner.registerInfo("OC = #{on_center_in}.")
						
						# Define thickness of the block
						cmu_thickness =/(\d+)\sin/.match(identifier).to_s
						#runner.registerInfo("CMU thickness string = #{cmu_thickness}.")
						if cmu_thickness == '6 in'
							cav_thickness = 6
						elsif cmu_thickness == '8 in'
							cav_thickness = 8
						elsif cmu_thickness == '10 in'
							cav_thickness = 10	
						elsif cmu_thickness == '12 in'
							cav_thickness = 12
						else
							cav_thickness = nil
						end
						#runner.registerInfo("CMU Thickness = #{cav_thickness}.")
						
						ins_mat = 'NONE'
						#runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
						# Currently creating the cavity insulation object, but could be deleted.
						# TO DO: How do we handle framing on the inside of the concrete wall?
						cav_r_ip = 0
						if cav_r_ip > 0
							insulationCav = {
								'insulationMaterial' => ins_mat,
								'insulationThickness' => cav_thickness,
								'insulationNominalRValue' => cav_r_ip,
								'insulationInstallationType' => 'CAVITY',
								'insulationLocation' => 'INTERIOR'
							}
							#runner.registerInfo("Cavity Insulation = #{insulationCav}")
							insulations << insulationCav
						end

						#Find concrete strength and reinforcement from standards identifier
						#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
						concrete_name = identifier.to_s
						#runner.registerInfo("Concrete Name = #{concrete_name}.")
						density =/(\d+)/.match(identifier).to_s.to_f
						#runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
						compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
						#runner.registerInfo("PSI = #{compressive_strength_value}.")

						# Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
						if compressive_strength_value < 2000
							compressive_strength = 'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
						elsif 	compressive_strength_value > 2000 and compressive_strength_value < 2750
							compressive_strength = '_2500_PSI'
						elsif 	compressive_strength_value > 2750 and compressive_strength_value < 3500
							compressive_strength = '_3000_PSI'
						elsif 	compressive_strength_value > 3500 and compressive_strength_value < 4500
							compressive_strength = '_4000_PSI'
						elsif 	compressive_strength_value > 4500 and compressive_strength_value < 5500
							compressive_strength = '_5000_PSI'
						elsif 	compressive_strength_value > 5500 and compressive_strength_value < 7000
							compressive_strength = '_6000_PSI'
						elsif 	compressive_strength_value > 7000
							compressive_strength = '_8000_PSI'
						else
							compressive_strength = 'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
						end
						
						# Define reinforcement - defaulted to 5 
						rebar_number = 5  # defaulted to 5 for no particular reason
						
						# Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
						if rebar_number = 4
							reinforcement = 'REBAR_NO_4'
						elsif rebar_number = 5
							reinforcement = 'REBAR_NO_5'
						elsif rebar_number = 6
							reinforcement = 'REBAR_NO_6'
						else
							reinforcement = 'UNSPECIFIED_CONCRETE_REINFORCEMENT'
						end
						
						concrete_value = {
							'concreteName' => concrete_name,
							'compressiveStrength' => compressive_strength,
							'reinforcement' => reinforcement
						}
						#runner.registerInfo("Concrete value = #{concrete_value}")
						
						clt_values = {}
					
					elsif category.to_s.include?('ICF')
						wall_type = 'INSULATED_CONCRETE_FORMS'
						
						# solid concrete will not have framing or cavity insulation within the material
						studs_size = 'OTHER_SIZE'
						#runner.registerInfo("Studs Size = #{studs_size}.")
						on_center_in = 0
						#runner.registerInfo("OC = #{on_center_in}.")
						
						# Insulating Concrete Forms - 1 1/2 in. Polyurethane Ins. each side - concrete 8 in.
						# Define thickness of the concrete
						concrete_thickness =/(\d+)\sin/.match(identifier).to_s
						#runner.registerInfo("ICF thickness string = #{concrete_thickness}.")
						if concrete_thickness == '6 in'
							cav_thickness = 6
						elsif concrete_thickness == '8 in'
							cav_thickness = 8
						else
							cav_thickness = nil
						end
						#runner.registerInfo("Concrete Thickness = #{cav_thickness}.")
						
						# define the ICF insulation type
						icf_ins = identifier.to_s
						#runner.registerInfo("ICF String = #{icf_ins}.")
						
						if identifier.to_s.include?('XPS')
							ins_mat = 'RIGID_XPS'
							ins_r_value_per_in = 5.0
						elsif identifier.to_s.include?('EPS')
							ins_mat = 'RIGID_EPS'
							ins_r_value_per_in = 5.0
						elsif identifier.to_s.include?('Polyurethane')
							ins_mat = 'SPRAY_FOAM_CLOSED_CELL'
							ins_r_value_per_in = 5.0
						elsif identifier.to_s.include?('Polyiso')
							ins_mat = 'RIGID_POLYISOCYANURATE' 
							ins_r_value_per_in = 5.0
						else
							ins_mat = 'UNKNOWN'
							ins_r_value_per_in = 0
						end
						#runner.registerInfo("ICF Insulation is #{ins_mat}.")
						#runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")
						
						# define the ICF insulation thickness; concrete is always thicker than the insulation
						if identifier.to_s.include?('1 1/2 in.')
							cav_thickness = 1.5
						elsif identifier.to_s.include?('2 in.')
							cav_thickness = 2
						elsif identifier.to_s.include?('2 1/2 in.')
							cav_thickness = 2.5
						elsif identifier.to_s.include?('3 in.')
							cav_thickness = 3
						elsif identifier.to_s.include?('4 in.')
							cav_thickness = 4	
						elsif identifier.to_s.include?('4 1/2 in.')
							cav_thickness = 4.5
						else
							cav_thickness = nil
						end
						#runner.registerInfo("ICF Thickness = #{cav_thickness}.")
						cav_r_ip = cav_thickness * ins_r_value_per_in
						#runner.registerInfo("ICF Insulation R Value = #{cav_r_ip}.")
						
						if cav_r_ip > 0
							insulationCav = {
								'insulationMaterial' => ins_mat,
								'insulationThickness' => cav_thickness,
								'insulationNominalRValue' => cav_r_ip,
								'insulationInstallationType' => 'CAVITY',
								'insulationLocation' => 'INTERIOR'
							}
							#runner.registerInfo("Cavity Insulation = #{insulationCav}")
							insulations << insulationCav
						end

						##Find concrete strength and reinforcement from standards identifier
						#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
						concrete_name = identifier.to_s
						#runner.registerInfo("Concrete Name = #{concrete_name}.")
						density =/(\d+)/.match(identifier).to_s.to_f
						#runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
						compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
						#runner.registerInfo("PSI = #{compressive_strength_value}.")

						# Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
						if compressive_strength_value < 2000
							compressive_strength = 'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
						elsif 	compressive_strength_value > 2000 and compressive_strength_value < 2750
							compressive_strength = '_2500_PSI'
						elsif 	compressive_strength_value > 2750 and compressive_strength_value < 3500
							compressive_strength = '_3000_PSI'
						elsif 	compressive_strength_value > 3500 and compressive_strength_value < 4500
							compressive_strength = '_4000_PSI'
						elsif 	compressive_strength_value > 4500 and compressive_strength_value < 5500
							compressive_strength = '_5000_PSI'
						elsif 	compressive_strength_value > 5500 and compressive_strength_value < 7000
							compressive_strength = '_6000_PSI'
						elsif 	compressive_strength_value > 7000
							compressive_strength = '_8000_PSI'
						else
							compressive_strength = 'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
						end
						
						# Define reinforcement - defaulted to 5 
						rebar_number = 5  # defaulted to 5 for no particular reason
						
						# Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
						if rebar_number = 4
							reinforcement = 'REBAR_NO_4'
						elsif rebar_number = 5
							reinforcement = 'REBAR_NO_5'
						elsif rebar_number = 6
							reinforcement = 'REBAR_NO_6'
						else
							reinforcement = 'UNSPECIFIED_CONCRETE_REINFORCEMENT'
						end
						
						concrete_value = {
							'concreteName' => concrete_name,
							'compressiveStrength' => compressive_strength,
							'reinforcement' => reinforcement
						}
						#runner.registerInfo("Concrete value = #{concrete_value}")
						
						clt_values = {}
					
					# Concrete Sandwich Panel Walls; matched to ICF because the material take-off approach is the same
					elsif category.to_s.include?('Concrete Sandwich Panel')
						rafters_material = 'OTHER_MATERIAL'
						# solid concrete will not have framing or cavity insulation within the material
						studs_size = 'OTHER_SIZE'
						#runner.registerInfo("Studs Size = #{studs_size}.")
						on_center_in = 0
						#runner.registerInfo("OC = #{on_center_in}.")
						
						# Concrete Sandwich Panel - 100% Ins. Layer - No Steel in Ins. - Ins. 1 1/2 in.
						# Concrete Sandwich Panel - 100% Ins. Layer - Steel in Ins. - Ins. 1 1/2 in.
						# Concrete Sandwich Panel - 90% Ins. Layer - No Steel in Ins. - Ins. 2 in.
						
						# Define thickness of the concrete
						concrete_thickness = 3 * 2 # Defaulted to 3 in wythes of concrete 
						
						# define the CSP insulation thickness
						if identifier.to_s.include?('1 1/2 in.')
							ins_thickness = 1.5
						elsif identifier.to_s.include?('2 in.')
							ins_thickness = 2
						elsif identifier.to_s.include?('3 in.')
							ins_thickness = 3
						elsif identifier.to_s.include?('4 in.')
							ins_thickness = 4	
						elsif identifier.to_s.include?('5 in.')
							ins_thickness = 5
						elsif identifier.to_s.include?('6 in.')
							ins_thickness = 6
						else
							ins_thickness = nil
						end
						#runner.registerInfo("Insulation Thickness = #{ins_thickness}.")
						
						# define the ICF insulation type and R value
						ins_mat = 'RIGID_EPS'
						ins_r_value_per_in = 5
						#runner.registerInfo("ICF Insulation is #{ins_mat}.")
						#runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")
						
						# Calculate total Cavity R value
						cav_r_ip = ins_thickness * ins_r_value_per_in
						#runner.registerInfo("CSP Insulation R Value = #{cav_r_ip}.")
						
						# calculate structural layer thickness
						cav_thickness = concrete_thickness + ins_thickness
						
						if cav_r_ip > 0
							insulationCav = {
								'insulationMaterial' => ins_mat,
								'insulationThickness' => cav_thickness,
								'insulationNominalRValue' => cav_r_ip,
								'insulationInstallationType' => 'CAVITY',
								'insulationLocation' => 'INTERIOR'
							}
							#runner.registerInfo("Cavity Insulation = #{insulationCav}")
							insulations << insulationCav
						end

						#Find concrete strength and reinforcement from standards identifier
						#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
						concrete_name = identifier.to_s
						#runner.registerInfo("Concrete Name = #{concrete_name}.")
						density =/(\d+)/.match(identifier).to_s.to_f
						#runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
						compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
						#runner.registerInfo("PSI = #{compressive_strength_value}.")

						# Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
						if compressive_strength_value < 2000
							compressive_strength = 'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
						elsif 	compressive_strength_value > 2000 and compressive_strength_value < 2750
							compressive_strength = '_2500_PSI'
						elsif 	compressive_strength_value > 2750 and compressive_strength_value < 3500
							compressive_strength = '_3000_PSI'
						elsif 	compressive_strength_value > 3500 and compressive_strength_value < 4500
							compressive_strength = '_4000_PSI'
						elsif 	compressive_strength_value > 4500 and compressive_strength_value < 5500
							compressive_strength = '_5000_PSI'
						elsif 	compressive_strength_value > 5500 and compressive_strength_value < 7000
							compressive_strength = '_6000_PSI'
						elsif 	compressive_strength_value > 7000
							compressive_strength = '_8000_PSI'
						else
							compressive_strength = 'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
						end
						
						# Define reinforcement - defaulted to 5 
						rebar_number = 5  # defaulted to 5 for no particular reason
						
						# Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
						if rebar_number = 4
							reinforcement = 'REBAR_NO_4'
						elsif rebar_number = 5
							reinforcement = 'REBAR_NO_5'
						elsif rebar_number = 6
							reinforcement = 'REBAR_NO_6'
						else
							reinforcement = 'UNSPECIFIED_CONCRETE_REINFORCEMENT'
						end
						
						concrete_value = {
							'concreteName' => concrete_name,
							'compressiveStrength' => compressive_strength,
							'reinforcement' => reinforcement
						}
						#runner.registerInfo("Concrete value = #{concrete_value}")
						
						clt_values = {}

					# Metal Insulated Panel Walls; metal SIPs
					elsif category.to_s.include?('Metal Insulated Panel Wall')
						rafters_material = 'STRUCTURALLY_INSULATED_PANEL'
					
						# Metal Insulated Panels - 2 1/2 in.
						# metal is assumed to be 26 gauge steel at 0.02 in thick for a total of 0.04 in of steel.
						# Currently assume metal thickness is additional to defined thickness
						
						# define the panel thickness
						if identifier.to_s.include?('2 in.')
							cav_thickness = 2
						elsif identifier.to_s.include?('2 1/2 in.')
							cav_thickness = 2.5
						elsif identifier.to_s.include?('3 in.')
							cav_thickness = 3
						elsif identifier.to_s.include?('4 in.')
							cav_thickness = 4	
						elsif identifier.to_s.include?('5 in.')
							cav_thickness = 5
						elsif identifier.to_s.include?('6 in.')
							cav_thickness = 6
						else
							cav_thickness = nil
						end
						#runner.registerInfo("Insulation Thickness = #{cav_thickness}.")
						
						# define the insulation type and R value; assume EPS at R-5/in
						ins_mat = 'RIGID_EPS'
						ins_r_value_per_in = 5
						#runner.registerInfo("Metal Panel Wall Insulation is #{ins_mat}.")
						#runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")
						
						# Calculate total Cavity R value
						cav_r_ip = cav_thickness * ins_r_value_per_in
						#runner.registerInfo("CSP Insulation R Value = #{cav_r_ip}.")
						
						if cav_r_ip > 0
							insulationCav = {
								'insulationMaterial' => ins_mat,
								'insulationThickness' => cav_thickness,
								'insulationNominalRValue' => cav_r_ip,
								'insulationInstallationType' => 'CAVITY',
								'insulationLocation' => 'INTERIOR'
							}
							#runner.registerInfo("Cavity Insulation = #{insulationCav}")
							insulations << insulationCav
						end
						
						concrete_value = {}
						
						clt_values = {}
					
					# Cross Laminated Timber (CLT) Walls - does not include any insulation.
					# User must manually add a standards category and standards identifier
					# Category = CLT; Identifier Format = X in. 50/75/100 psf Live Load
					elsif category.to_s.include?('CLT')	or 	category.to_s.include?('Cross Laminated Timber') or category.to_s.include?('Woods')	# not a tag option at the moment
						rafters_material = 'CROSS_LAMINATED_TIMBER'
					
						# define the framing size; there are no rafters for SIPs
						studs_size = 'OTHER_SIZE'
						#runner.registerInfo("Studs Size = #{studs_size}.")

						# define On Center
						#fc = frame_config.get.downcase
						#runner.registerInfo("OC = #{fc}.")
						on_center_in = 0
						#runner.registerInfo("OC = #{on_center_in}.")
						
						# parse the standard identifier;  eg CLT - 2x4 - 3 Layers
						
						# find R value of the "cavity" of the SIP
						#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
						live_load = 50
						if not category.nil?
							live_load =/(\d+)\spsf/.match(identifier).to_s.to_f
						end
						#runner.registerInfo("Live Load = #{live_load}.")
						
						# Define framing cavity thickness
						clt_thickness =/(\d+)\sin./.match(identifier).to_s
						#runner.registerInfo("CLT thickness = #{clt_thickness}.")
						value, unit = clt_thickness.split(' ')
						cav_thickness = value.to_f
						#runner.registerInfo("CLT Thickness = #{cav_thickness}.")
				
						cav_r_ip = 0
						ins_r_value_per_in = 0
						ins_r_value_per_in = 0
						ins_mat = 'NONE'
						
						if cav_r_ip > 0
							insulationCav = {
								'insulationMaterial' => ins_mat,
								'insulationThickness' => cav_thickness,
								'insulationNominalRValue' => cav_r_ip,
								'insulationInstallationType' => 'CAVITY',
								'insulationLocation' => 'INTERIOR'
							}
							#runner.registerInfo("Cavity Insulation = #{insulationCav}")
							insulations << insulationCav
						end
						
						concrete_value = {}
						
						# Define supported span using wall length and stories - defaulted to 1 for residential
						supported_span = wall_length_ft #equal to the width of the wall; what is the max span?
						supported_stories = 1	#assume 1 story for residential.
						
						# Define supported element
						clt_supported_element_type = 'ROOF'	#if surface is first floor then assume "floor", if 2nd floor assume "roof"
					
						clt_values = {
							'liveLoad' => live_load,	#kPa
							'supportedSpan' => supported_span,	#the length of wall unless it exceeds the maximum
							'supportedElementType' => clt_supported_element_type,
							'supportedStories' => supported_stories
						}
					
					else								# Includes Spandrel Panels Curtain Walls and straw bale wall; 
						rafters_material = 'OTHER_MATERIAL'
						# define the framing size; there are no studs for SIPs
						studs_size = 'OTHER_SIZE'
						#runner.registerInfo("Studs Size = #{studs_size}.")

						# define On Center
						#fc = frame_config.get.downcase
						#runner.registerInfo("OC = #{fc}.")
						on_center_in = 0
						#runner.registerInfo("OC = #{on_center_in}.")
						
						cav_r_ip = 0
						ins_r_value_per_in = 0
						ins_r_value_per_in = 0
						ins_mat = 'NONE'
						
						if cav_r_ip > 0
							insulationCav = {
								'insulationMaterial' => ins_mat,
								'insulationThickness' => cav_thickness,
								'insulationNominalRValue' => cav_r_ip,
								'insulationInstallationType' => 'CAVITY',
								'insulationLocation' => 'INTERIOR'
							}
							#runner.registerInfo("Cavity Insulation = #{insulationCav}")
							insulations << insulationCav
						end
						
						concrete_value = {}
						
						clt_values = {}
						
					end
					
					
					# Additional insulation either interior or exterior to the structural layer (composite framing layer, SIPs, CIFs, CLTs)
					# Use structural layer as base to find other insulation.
					
					# Interior rigid insulation r-value
					rigid_ins_int = const.rigid_insulation_values(sl_i, 'interior')
					int_r = rigid_ins_int[0].to_s.to_f
					int_t = rigid_ins_int[1].to_s.to_f
					#This is an R Value, but we need to determine the material.
					if rigid_ins_int.nil?
						int_r_ip = 0
						interior_rigid_thickness = 0
					else
						int_r_ip = int_r
						interior_rigid_thickness = int_t
						ins_r_value_per_in = int_r / int_t
						
						if ins_r_value_per_in < 0.1
							ins_mat = 'NONE'
						elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
							ins_mat = 'RIGID_EPS'
						elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
							ins_mat = 'RIGID_XPS'
						elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
							ins_mat = 'RIGID_POLYISOCYANURATE'
						else
							ins_mat = 'RIGID_UNKNOWN'
						end
					end
					#runner.registerInfo("Insulation R is #{int_r_ip}.")
					#runner.registerInfo("Insulation Type is #{ins_mat}.")
					#runner.registerInfo("Insulation Thickness is #{interior_rigid_thickness}.")
					
					if int_r_ip > 0
						insulationInt = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => interior_rigid_thickness.round(1),
							'insulationNominalRValue' => int_r_ip.round(1),
							'insulationInstallationType' => 'CONTINUOUS',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Insulation = #{insulationInt}")
						insulations << insulationInt
					end
					
					
					# Exterior rigid insulation r-value		
					rigid_ins_ext = const.rigid_insulation_values(sl_i, 'exterior')
					ext_r = rigid_ins_ext[0].to_s.to_f
					ext_t = rigid_ins_ext[1].to_s.to_f
					#This is an R Value, but we need to determine the material.
					if rigid_ins_ext.nil?
						ext_r_ip = 0
						exterior_rigid_thickness = 0
					else
						ext_r_ip = ext_r
						exterior_rigid_thickness = ext_t
						ins_r_value_per_in = ext_r / ext_t
						
						if ins_r_value_per_in < 0.1
							ins_mat = 'NONE'
						elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
							ins_mat = 'RIGID_EPS'
						elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
							ins_mat = 'RIGID_XPS'
						elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
							ins_mat = 'RIGID_POLYISOCYANURATE'
						else
							ins_mat = 'RIGID_UNKNOWN'
						end
					end
					#runner.registerInfo("Insulation R is #{ext_r_ip}.")
					#runner.registerInfo("Insulation Type is #{ins_mat}.")
					#runner.registerInfo("Insulation Thickness is #{exterior_rigid_thickness}.")
					
					if ext_r_ip > 0
						insulationExt = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => exterior_rigid_thickness.round(1),
							'insulationNominalRValue' => ext_r_ip.round(1),
							'insulationInstallationType' => 'CONTINUOUS',
							'insulationLocation' => 'EXTERIOR'
						}
						#runner.registerInfo("Insulation = #{insulationExt}")
						insulations << insulationExt
					end
					
					# Find the Floor Decking Type
					roof_decking_type = 'NONE' # Defaulted to None in case no decking is found.
					deck_identifier = nil
					deck_category = nil
					
					layers.each_with_index do |layer, i|
						# Skip fenestration, partition, and airwall materials
						next if roof_decking_type == 'WOOD' or roof_decking_type == 'METAL'
						layer = layer.to_OpaqueMaterial
						next if layer.empty?
						deck_layer = layer.get
						deck_stds = deck_layer.standardsInformation
						next if not deck_stds.standardsIdentifier.is_initialized				
						deck_identifier = deck_stds.standardsIdentifier.get.to_s
						deck_identifier = deck_identifier.downcase
						#runner.registerInfo("Deck Layer Identifier = #{deck_identifier}.")
						if deck_identifier.include?('osb') or deck_identifier.include?('plywood')
							roof_decking_type = 'WOOD'
						elsif deck_identifier.include?('Metal Deck')
							roof_decking_type = 'METAL'
						else
							roof_decking_type = 'NONE'
						end					
					end
					#runner.registerInfo("Frame Floor Decking = #{roof_decking_type}.")
					
					# define roof construction type
					if rafters_material == 'WOOD_RAFTER'		
						roof_construction_type = 'RAFTER'		# Ignores TRUSS for now.
					elsif rafters_material == 'METAL_RAFTER'
						roof_construction_type = 'RAFTER'		# Ignores TRUSS for now.
					elsif category.include?('Concrete') or category.include?('ICF')
						roof_construction_type = 'CONCRETE_DECK' #
					else 										# Handles all 'OTHER_MATERIAL'
						roof_construction_type = 'OTHER'		# There is no rafter or truss for CLT, concrete, ICF, SIPs, or MIPs
					end
					
					#Need to find all subsurfaces on a roof surface and determine which are skylights.
					#Then pull the information for each to add to the array.
					#This will require a do loop through each wall surface.
					skylights = []

					#if subsurface is a skylight, then populate the skylight object.
					#Only need to populate the physical components or the performance specs. Use performance specs from OSM.
					#Can I pull this info from OSM or do I have to go through each E+ skylight object, match the surface name, and pull specs?
					
					#runner.registerInfo("finding all skylights in this roof surface.")
					surf.subSurfaces.each do |ss|
						#if ss is a skylight, else its a door.
						#runner.registerInfo("found subsurface.")
						subsurface_type = ss.subSurfaceType
						#runner.registerInfo("found subsurface type: #{subsurface_type}.")
						# Determine if the subsurface is a skylight or other
						if subsurface_type == 'Skylight'
							operable = false		# hard code to No
							skylight_name = ss.name
							#runner.registerInfo("found subsurface #{skylight_name}.")
							skylight_area_m2 = ss.grossArea
							#runner.registerInfo("found subsurface #{skylight_name} with area #{skylight_area}.")
							skylight_area_ft2 = OpenStudio.convert(skylight_area_m2, 'm^2','ft^2').get
							skylight_z_max = -1000000000
							skylight_z_min = 1000000000
							#runner.registerInfo("finding subsurface vertices.")
							vertices = ss.vertices
							#runner.registerInfo("found subsurface vertices.")
							vertices.each do |vertex|
								z = vertex.z
								if z < skylight_z_min
									skylight_z_min = z
								else next
								end					
								if z > skylight_z_max
									skylight_z_max = z
								else
								end
							end
							#runner.registerInfo("found max and min z vertices.")
							skylight_height_m = skylight_z_max - skylight_z_min
							#runner.registerInfo("skylight height = #{skylight_height_m}.")
							#Convert to IP
							skylight_height_ft = OpenStudio.convert(skylight_height_m, 'm','ft').get

							# Take skylight name and use it to find the specs.
							# Parse the skylight name, upcase the letters, and then put back together. The periods are causing the problem.
							skylight_name_string = skylight_name.to_s
							#runner.registerInfo("skylight name now string: #{skylight_name_string}.")
							skylight_name_capped = skylight_name_string.upcase
							#runner.registerInfo("skylight name capped: #{skylight_name_capped}.")
							# query the SQL file including the row name being a variable. Treat like its in a runner.
							# U-Factor Query
							query = "SELECT Value
							  FROM tabulardatawithstrings
							  WHERE ReportName='EnvelopeSummary'
							  AND ReportForString= 'Entire Facility'
							  AND TableName='Exterior Fenestration'
							  AND ColumnName='Glass U-Factor'
							  AND RowName='#{skylight_name_capped}'
							  AND Units='W/m2-K'"       
							#runner.registerInfo("Query is #{query}.")
							u_si = sql.execAndReturnFirstDouble(query)
							#runner.registerInfo("U-SI value was found: #{u_si}.")
							if u_si.is_initialized
							  u_si = u_si.get
							else
							  u_si = 0
							end
							u_ip = OpenStudio.convert(u_si, 'W/m^2*K','Btu/hr*ft^2*R').get
							# SHGC Query
							query = "SELECT Value
							  FROM tabulardatawithstrings
							  WHERE ReportName='EnvelopeSummary'
							  AND ReportForString= 'Entire Facility'
							  AND TableName='Exterior Fenestration'
							  AND ColumnName='Glass SHGC'
							  AND RowName='#{skylight_name_capped}'"       
							#runner.registerInfo("Query is #{query}.")
							shgc = sql.execAndReturnFirstDouble(query)
							#runner.registerInfo("SHGC value was found: #{shgc}.")
							if shgc.is_initialized
							  shgc = shgc.get
							else
							  shgc = 0
							end
							
							# VT Query
							query = "SELECT Value
							  FROM tabulardatawithstrings
							  WHERE ReportName='EnvelopeSummary'
							  AND ReportForString= 'Entire Facility'
							  AND TableName='Exterior Fenestration'
							  AND ColumnName='Glass Visible Transmittance'
							  AND RowName='#{skylight_name_capped}'"       
							#runner.registerInfo("Query is #{query}.")
							vt = sql.execAndReturnFirstDouble(query)
							#runner.registerInfo("U-SI value was found: #{vt}.")
							if vt.is_initialized
							  vt = vt.get
							else
							  vt = 0
							end
							
							skylight = {
								'name'=> skylight_name,
								'operable'=> operable,
								'area'=> skylight_area_ft2.round(2),
								'height' => skylight_height_ft.round(2),	# TO DO  - need to add to enumerations
								'quantity'=> 1,			# Hard coded until we introduce HPXML
								'frameType'=> 'NONE_FRAME_TYPE',		# Hard coded until we introduce Construction Fenstration Information option
								'glassLayer'=> 'NONE_GLASS_LAYERS',		# Hard coded until we introduce Construction Fenstration Information option
								'glassType'=> 'NONE_GLASS_TYPE',		# Hard coded until we introduce Construction Fenstration Information option
								'gasFill'=> 'NONE_GAS_FILL',			# Hard coded until we introduce Construction Fenstration Information option
								'shgc'=> shgc.round(4),
								'visualTransmittance'=> vt.round(4),
								'uFactor'=> u_ip.round(4)
							}
							#runner.registerInfo("skylight = #{skylight}")
							skylights << skylight
							attic_skylights << skylight
						else	
							#runner.registerInfo("subsurface type is not a skylight and will be skipped: #{subsurface_type}.")
						end
					end
					
					#Populate the surface object
					#runner.registerInfo("Creating Roof object.")
					atticRoof = {
						'roofName' => roof_name,
						'attachedToSpace' => roof_attached_to_space,		# attic space to which the roof surface belongs
						'roofInsulations' => insulations,					# Array of the insulations just like walls
						'deckType' => roof_decking_type,					# roof deck material - wood default
						'roofType' => roof_type,							# roof finishing material (shingles, etc)
						'radiantBarrier' => radiant_barrier,				# defaulted to yes; search roof layers for barrier
						'roofArea' => roof_area_ft2.round(2),				# sum of roof surfaces for the specific zone
						'RoofConstructionType' => roof_construction_type, 	# rafter or truss	
						'raftersSize' => rafters_size,						# defined in composite layer standard information
						'rafterSpacing' => on_center_in,					# rafters framing - OC
						'raftersMaterials' => rafters_material,				# defined in composite layer standard information
						'pitch' => pitch.round(1),							# defined by using the slope of the roof surfaces
						'roofSpan' => roof_span_ft.round(2),				# use the longest axis of the roof
						'skyLights' => skylights							# all skylights subsurfaces in all roof surfaces 
					}
					#runner.registerInfo("Attic Roof = #{atticRoof}")
					# Add roof object details to the array
					atticRoofs << atticRoof
					
					# Grab remaining surface specific values for the attic specs; assumes all surfaces have the same constructions.
					attic_roof_insulations = insulations
					attic_deck_type = roof_decking_type
					attic_roof_type = roof_type
					attic_radiant_barrier = radiant_barrier
					attic_rafters_size = rafters_size
					attic_rafters_mat = rafters_material
					attic_pitch = pitch
					#runner.registerInfo("attic_pitch = #{attic_pitch}.")
				end
					
				# FIND ATTIC FLOORS
				if surf.surfaceType == 'Floor' and construction_stds.intendedSurfaceType.to_s.include?('AtticFloor')
					# Assumes construction_stds.intendedSurfaceType.is_initialized. Could error out if its not initialized...					
					# Define the space as an attic; name the surface as a floor; find the area of the surface and add to the attic floor area.
					attic_name = space_name
					floor_name = surface_name
					floor_area_ft2 = area_ft2
					# Add to attic floor area.
					attic_floor_area = attic_floor_area + floor_area_ft2
					
					# Get the layers from the construction
					layers = const.layers
					# Find the main stud layer. This is a function in construction.rb created by NREL
					sl_i = const.structural_layer_index
					# Skip and warn if we can't find a structural layer
					if sl_i.nil?
						runner.registerInfo("Cannot find structural layer in wall construction #{const.name}; this construction will not be included in the LCA calculations.  To ensure that the LCA calculations work, you must specify the Standards Information fields in the Construction and its constituent Materials.  Use the CEC2013 enumerations.")  
					next
					end	
					
					# Calculate the floor span by saving the longest 
					#runner.registerInfo("finding  wall vertices.")
					vertices = surf.vertices
					# Find the distance between 2 points on the same z axis
					length = nil
					width = nil
					x0 = nil
					y0 = nil
					z0 = nil
					# Find the x and y differences
					vertices.each_with_index do |vertex, i|
						#Once the values are populated, skip the rest of the vertices.
						if i == 0
							x0 = vertex.x
							y0 = vertex.y
							z0 = vertex.z
							#runner.registerInfo("Vertices = #{x0}, #{y0}, #{z0}.")
						else 
							if vertex.z == z0
								length = (x0 - vertex.x).abs
								width = (y0 - vertex.y).abs
								#runner.registerInfo("Vertices (m) = #{length}, #{width}.")				
							end
						end
					end
					#runner.registerInfo("Vertices = #{length}, #{width}.")
					#Use x and y differences to calculate the span.
					floor_span_m = Math.sqrt(length**2+width**2)
					floor_span_ft = OpenStudio.convert(floor_span_m, 'm','ft').get
					#runner.registerInfo(" Floor surface span = #{floor_span_ft}.")
					if floor_span_ft > attic_floor_span
						attic_floor_span = floor_span_ft
					end
					
					#Find characteristics of the structural layer using Material Standard Information Measure Tags
					# Assumes a single structural layer. For example, does not capture SIPs manually defined by mutliple layers.
					# These are the tags for the structural layer.
					# Trusses have space for HVAC and DHW lines. Should be used if there is a basement or conditioned attic.

					frame_floor_type = nil # either floor joist or floor truss. 
					frame_floor_type = 'truss' # Default to floor truss. Base on user input or conditional or basements and space conditioned.
					
					# Structural layer 
					sli_stds = layers[sl_i].standardsInformation
					
					if sli_stds.standardsCategory.is_initialized
						category = sli_stds.standardsCategory.get.to_s
						#runner.registerInfo("Structural Layer Category = #{category}.")
					end
					if sli_stds.standardsIdentifier.is_initialized
						identifier = sli_stds.standardsIdentifier.get.to_s
						#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
					end
					if sli_stds.compositeFramingMaterial.is_initialized
						frame_mat = sli_stds.compositeFramingMaterial.get.to_s
						#runner.registerInfo("Structural Layer Framing Material = #{frame_mat}.")
					end
					if sli_stds.compositeFramingConfiguration.is_initialized
						frame_config = sli_stds.compositeFramingConfiguration.get.to_s
						#runner.registerInfo("Structural Layer Framing Config = #{frame_config}.")
					end
					if sli_stds.compositeFramingDepth.is_initialized
						frame_depth = sli_stds.compositeFramingDepth.get.to_s
						#runner.registerInfo("Structural Layer Framing Depth = #{frame_depth}.")
					end
					if sli_stds.compositeFramingSize.is_initialized
						frame_size = sli_stds.compositeFramingSize.get.to_s
						#runner.registerInfo("Structural Layer Framing Size = #{frame_size}.")
					end
					if sli_stds.compositeCavityInsulation.is_initialized
						cavity_ins = sli_stds.compositeCavityInsulation.get.to_i
						#runner.registerInfo("Structural Layer Cavity Insulation = #{cavity_ins}.")
					end
					
					# Find interior floor finishing product (if available). Similar to interior wall finish approach
					# Find interior layer for the construction to define the finish
					# Layers from exterior to interior
					frame_floor_covering = nil
					il_identifier = nil
					il_category = nil
					
					layers.each_with_index do |layer, i|
						# Skip fenestration, partition, and airwall materials
						layer = layer.to_OpaqueMaterial
						next if layer.empty?
						int_layer = layer.get
						#runner.registerInfo("interior layer = #{int_layer}.")
						
						il_i_stds = int_layer.standardsInformation
						if il_i_stds.standardsCategory.is_initialized
							il_category = il_i_stds.standardsCategory.get.to_s
							#runner.registerInfo("Interior Layer Category = #{il_category}.")
						end
						if il_i_stds.standardsIdentifier.is_initialized
							il_identifier = il_i_stds.standardsIdentifier.get.to_s
							#runner.registerInfo("Interior Layer Identifier = #{il_identifier}.")
						end
					end
					#runner.registerInfo("Interior Layer = #{il_identifier}.")		
					
					# Determine floor covering
					# Currently not requiring details on flooring. could leverage BEES.
					# Should add UNKNOWN to the enumerations.		
					if il_category.include?('Woods') or il_category.include?('Bldg Board and Siding')
						frame_floor_covering = 'HARDWOOD' # Assumes that any wood or plywood is for a hardwood floor. 			
					elsif il_category.include?('Finish Materials')
						il_identifier = il_identifier.downcase
						if il_identifier != nil
							if il_identifier.include?('carpet')
								frame_floor_covering = 'CARPET'
							elsif il_identifier.include?('linoleum')
								frame_floor_covering = 'VINYL' # groups Linoleum, Cork, and Vinyl together
							elsif il_identifier.include?('tile')
								frame_floor_covering = 'TILE' # groups all rubber, slate, and other tile together
							else
								frame_floor_covering = 'NONE_FRAME_FLOOR_COVERING' # terrazzo is grouped here. 
							end
						else
							frame_floor_covering = 'NONE_FRAME_FLOOR_COVERING'
						end
					else 
						frame_floor_covering = 'NONE_FRAME_FLOOR_COVERING'
					end		
					#runner.registerInfo("Frame Floor Covering = #{frame_floor_covering}.")
					
					# Find the Floor Decking Type
					floor_decking_type = 'NONE' # Defaulted to None in case no decking is found.
					deck_identifier = nil
					deck_category = nil
					
					layers.each_with_index do |layer, i|
						# Skip fenestration, partition, and airwall materials
						next if floor_decking_type == 'OSB' or floor_decking_type == 'PLYWOOD'
						layer = layer.to_OpaqueMaterial
						next if layer.empty?
						deck_layer = layer.get
						deck_stds = deck_layer.standardsInformation
						next if not deck_stds.standardsIdentifier.is_initialized				
						deck_identifier = deck_stds.standardsIdentifier.get.to_s
						deck_identifier = deck_identifier.downcase
						#runner.registerInfo("Deck Layer Identifier = #{deck_identifier}.")
						if deck_identifier.include?('osb') or deck_identifier.include?('plywood')
							#runner.registerInfo("Deck Layer = #{deck_identifier}.")
							if deck_identifier.include?('osb')
								floor_decking_type = 'OSB'
							elsif deck_identifier.include?('plywood')
								floor_decking_type = 'PLYWOOD'
							else
								floor_decking_type = 'NONE'
							end					
						end
					end
					#runner.registerInfo("Frame Floor Decking = #{floor_decking_type}.")
					
					
					# Define the material for the joist/truss
					if category.to_s.include?('Wood Framed')
						frame_floor_material = 'WOOD'
					elsif category.to_s.include?('Metal Framed')
						frame_floor_material = 'METAL'
					else
						frame_floor_material = 'WOOD' #Defaults to wood; could add error message here.
					end
					
					# define On Center
					fc = frame_config.downcase
					#runner.registerInfo("OC = #{fc}.")
					on_center_in = /(\d+)/.match(frame_config).to_s.to_f
					#runner.registerInfo("OC = #{on_center_in}.")
					
					# define the framing size
					if frame_size == '2x4'
						studs_size = '_2X4'
					elsif frame_size == '2x6'
						studs_size = '_2X6'
					elsif frame_size == '2x8'
						studs_size = '_2X8'
					elsif frame_size == '2x10'
						studs_size = '_2X10'
					elsif frame_size == '2x12'
						studs_size = '_2X12'
					elsif frame_size == '2x14'
						studs_size = '_2X14'	
					else
						studs_size = 'OTHER_SIZE'
					end
					#runner.registerInfo("Studs Size = #{studs_size}.")
					
					# Define framing cavity thickness
					if frame_depth == '3_5In'
						cav_thickness = 3.5
					elsif frame_depth == '5_5In'
						cav_thickness = 5.5
					elsif frame_depth == '7_25In'
						cav_thickness = 7.25
					elsif frame_depth == '9_25In'
						cav_thickness = 9.25
					elsif frame_depth == '11_25In'
						cav_thickness = 11.25	
					else
						cav_thickness = nil
					end
					#runner.registerInfo("Cavity Thickness = #{cav_thickness}.")
					
					
					# Get all insulation in the frame floor construction.
					# Interior walls will not have insulation. 
					#Top and bottom floors may have insulation. It could be in the cavity and/or continuous rigid.
					
					#Inialized insulations array.
					insulations = []
					cav_ins_mat = nil
					# Use the structural layer sandards information to get the cavity insulation, if any.
					# define the cavity insulation
					if cavity_ins.nil?
						cav_r_ip = 0
						ins_r_value_per_in = 0
					else
						cav_r_ip = cavity_ins
						#runner.registerInfo("Cavity R Value = #{cav_r_ip}.")
						if not cav_thickness.nil?
							ins_r_value_per_in = cav_r_ip / cav_thickness
						else
							ins_r_value_per_in = nil # If this occurs, there is something wrong.
						end
					end
					#runner.registerInfo("Cavity Insulation R is #{cav_r_ip}.") 
					#runner.registerInfo("Cavity Insulation R per Inch is #{ins_r_value_per_in}.")
					
					# Assume cavity insulation for wood or metal framing is either fiberglass batt or cellulose; are there others to include?
					if not ins_r_value_per_in.nil?
						if ins_r_value_per_in < 0.1
							cav_ins_mat = 'NONE'
						elsif ins_r_value_per_in < 3.6 and ins_r_value_per_in > 0.01
							cav_ins_mat = 'BATT_FIBERGLASS'
						else
							cav_ins_mat = 'LOOSE_FILL_CELLULOSE'
						end
					else
						cav_ins_mat = 'UNKNOWN'
					end
					#runner.registerInfo("Cavity Insulation  is #{cav_ins_mat}.")
					
					if cav_r_ip > 0
						insulationCav = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => cav_thickness,
							'insulationNominalRValue' => cav_r_ip,
							'insulationInstallationType' => 'CAVITY',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Cavity Insulation = #{insulationCav}")
						insulations << insulationCav
					end
					
					
					# Additional insulation either interior or exterior to the structural layer (composite framing layer, SIPs, CIFs, CLTs)
					# Use structural layer as base to find other insulation.
					
					# Interior rigid insulation r-value
					rigid_ins_int = const.rigid_insulation_values(sl_i, 'interior')
					int_r = rigid_ins_int[0].to_s.to_f
					int_t = rigid_ins_int[1].to_s.to_f
					#This is an R Value, but we need to determine the material.
					if rigid_ins_int.nil?
						int_r_ip = 0
						interior_rigid_thickness = 0
					else
						int_r_ip = int_r
						interior_rigid_thickness = int_t
						ins_r_value_per_in = int_r / int_t
						
						if ins_r_value_per_in < 0.1
							ins_mat = 'NONE'
						elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
							ins_mat = 'RIGID_EPS'
						elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
							ins_mat = 'RIGID_XPS'
						elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
							ins_mat = 'RIGID_POLYISOCYANURATE'
						else
							ins_mat = 'RIGID_UNKNOWN'
						end
					end
					#runner.registerInfo("Insulation R is #{int_r_ip}.")
					#runner.registerInfo("Insulation Type is #{ins_mat}.")
					#runner.registerInfo("Insulation Thickness is #{interior_rigid_thickness}.")
					
					if int_r_ip > 0
						insulationInt = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => interior_rigid_thickness.round(1),
							'insulationNominalRValue' => int_r_ip.round(1),
							'insulationInstallationType' => 'CONTINUOUS',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Insulation = #{insulationInt}")
						insulations << insulationInt
					end
					
					
					# Exterior rigid insulation r-value		
					rigid_ins_ext = const.rigid_insulation_values(sl_i, 'exterior')
					ext_r = rigid_ins_ext[0].to_s.to_f
					ext_t = rigid_ins_ext[1].to_s.to_f
					#This is an R Value, but we need to determine the material.
					if rigid_ins_ext.nil?
						ext_r_ip = 0
						exterior_rigid_thickness = 0
					else
						ext_r_ip = ext_r
						exterior_rigid_thickness = ext_t
						ins_r_value_per_in = ext_r / ext_t
						
						if ins_r_value_per_in < 0.1
							ins_mat = 'NONE'
						elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
							ins_mat = 'RIGID_EPS'
						elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
							ins_mat = 'RIGID_XPS'
						elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
							ins_mat = 'RIGID_POLYISOCYANURATE'
						else
							ins_mat = 'RIGID_UNKNOWN'
						end
					end
					#runner.registerInfo("Insulation R is #{ext_r_ip}.")
					#runner.registerInfo("Insulation Type is #{ins_mat}.")
					#runner.registerInfo("Insulation Thickness is #{exterior_rigid_thickness}.")
					
					if ext_r_ip > 0
						insulationExt = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => exterior_rigid_thickness.round(1),
							'insulationNominalRValue' => ext_r_ip.round(1),
							'insulationInstallationType' => 'CONTINUOUS',
							'insulationLocation' => 'EXTERIOR'
						}
						#runner.registerInfo("Insulation = #{insulationExt}")
						insulations << insulationExt
					end
								
					
					# create floor joist/truss object
					floor_joist = nil
					floor_truss = nil
					
					if frame_floor_type == 'truss'
						floor_truss = {
							'floorTrussSpacing' => on_center_in,
							'floorTrussFramingFactor' => nil,
							'floorTrussSize' => studs_size,
							'floorTrussMaterial' => frame_floor_material
						}
					elsif frame_floor_type == 'joist'
						floor_joist = {
							'floorJoistSpacing' => on_center_in,
							'floorJoistFramingFactor' => nil,
							'floorJoistSize' => studs_size,
							'floorJoistMaterial' => frame_floor_material
						}
					else
						runner.registerInfo("Cannot find frame floor type. Check Construction and Material Measure Tags.")  
					end
					
					# Populate frame floor object
					atticFloor = {
					  'floorJoist' => floor_joist,
					  'floorTruss' => floor_truss,
					  'frameFloorInsulations' => insulations,
					  'frameFloorName' => floor_name,
					  'frameFloorArea' => area_ft2.round(1),
					  'frameFloorSpan' => floor_span_ft.round(1),
					  'frameFloorDeckingType' => floor_decking_type,
					  'frameFloorFloorCovering' => frame_floor_covering
					}
				  
					#runner.registerInfo("atticFloor = #{atticFloor}")
					atticFloors << atticFloor
					
					# Define the attic space insulation array.
					# Assumes the insulation is the same for all attic floor surfaces in a given space.
					attic_floor_insulations = insulations
					
				end	
			end	
		end	
		#runner.registerInfo("Attic Floor Area = #{attic_floor_area}.")
		#runner.registerInfo("Attic Roof Area = #{attic_roof_area}.")
		#runner.registerInfo("Attic Floor Span = #{attic_floor_span}.")
		#runner.registerInfo("Attic Roof Span = #{attic_roof_span}.")
		# NOTE: we could add an array of the floor and roof surface objects if desired.
		# NOTE: currently the floors are double counted. Need an alternative definition to call on.
		
		# determine if the space is an attic. If an attic, add the atticAndRoof object to the atticAndRoofs array.
		if 	not attic_name.nil? or not attic_roofs == []			
			#Populate the atticAndRoof surface object
			#runner.registerInfo("Creating Attic and Roof object.")
			atticAndRoof = {
				'atticAndRoofName' => attic_name,						# Use space name.
				'deckType' => attic_deck_type,							# get from roofs array (assumes a single type)
				'roofType' => attic_roof_type,							# get from roofs array (assumes a single type)
				'radiantBarrier' => attic_radiant_barrier,				# get from roofs array (assumes a single type)
				'roofArea' => attic_roof_area.round(2),					# sum of roof surfaces for the space
				'raftersSize' => attic_rafters_size,					# get from roofs array (assumes a single type)
				'raftersMaterials' => attic_rafters_mat,				# get from roofs array (assumes a single type)
				'pitch' => attic_pitch.round(1),						# get from roofs array (assumes a single type)
				'roofSpan' => attic_roof_span.round(2),					# use the longest axis of the roof 
				'atticType' => attic_type,								# User defined
				'atticArea' => attic_floor_area.round(2),				# sum of area for floor surfaces for the attic space
				'atticLength' => attic_floor_span.round(2),				# use the longest axis of the zone
				'atticFloorInsulations'=> attic_floor_insulations,		# Get from floors array 
				'atticRoofInsulations'=> attic_roof_insulations,		# Get from roofs array
				'atticCeilingInsulations'=> attic_ceiling_insulations,	# Empty. This is in the roof insulation array.
				'skyLights' => attic_skylights							# all skylights subsurfaces in all roof surfaces
			}
			#runner.registerInfo("Attic/Roof = #{atticAndRoof}")
			#Add attic to attics array
			atticAndRoofs << atticAndRoof	
		end		
	end

	return atticAndRoofs
	
end

def get_atticandroof3(idf, model, runner, user_arguments, sql)

    # AtticAndRoofs3 - updates atticandroofs2 with space.surfuce instead of model.surface
	# This updates the old atticandroof to provide actual results.
	atticAndRoofs = [] #Used for the new code, which are the 2nd set of obejcts reported.
	atticFloors = []
	atticRoofs = []
	# Define variables and call on user inputs.
	attic_type = runner.getStringArgumentValue('attic_type',user_arguments)
	# Identify the spaces that are Attics
	
	model.getSpaces.each do |space|
		attic_name = nil
		#define attic floor areas and spans
		# These will be populated from a combination of all roof and floor surfaces in the attic space.
		# define reused variables for each space
		attic_floor_area = 0
		attic_roof_area = 0
		attic_roof_span = 0
		attic_floor_span = 0
		attic_wall_span = 0
		attic_floors = []
		attic_roofs = []
		attic_skylights = []
		attic_floor_insulations = []
		attic_roof_insulations = []
		attic_ceiling_insulations = []
		attic_deck_type = nil
		attic_roof_type = nil
		attic_radiant_barrier = nil
		attic_rafters_size = nil
		attic_rafters_mat = nil
		attic_pitch = nil
		#space_is_attic = false
		attic_name = nil
		# define space name
		space_name = space.name.get.to_s
		#runner.registerInfo("Space is #{space_name}.")
		# search surfaces in the space for roof surface 
		space.surfaces.each do |surf| 
			# add the surface if its a attic roof or attic floor.
			# Define the construction
			const = surf.construction
			const = const.get
			const = const.to_Construction.get
			# Define the Measure Tags Set
			construction_stds = const.standardsInformation
			#Get Surface Name
			surface_name = surf.name.get
			# Get the area
			area_m2 = surf.netArea
			#runner.registerInfo("Area is #{area_m2} m2.")  
			# Area (ft2)
			area_ft2 = OpenStudio.convert(area_m2, 'm^2','ft^2').get
			
			# FIND GABLE SPAN - using longest wall (captures the width of the gable)
			# TO DO: how do we handle a non-gable roof?
			if surf.surfaceType == 'Wall' and construction_stds.intendedSurfaceType.to_s.include?('AtticWall')
				# Calculate the gable span by saving the longest distance
				#runner.registerInfo("finding wall vertices for #{surface_name} in #{space_name}.")
				vertices = surf.vertices
				# Find the distance between 2 points on the same z axis
				x = nil
				y = nil
				x0 = nil
				y0 = nil
				z0 = nil
				# Find the x and y differences
				vertices.each_with_index do |vertex, i|
					#Once the values are populated, skip the rest of the vertices.
					if i == 0
						x0 = vertex.x
						y0 = vertex.y
						z0 = vertex.z
						#runner.registerInfo("Initial Vertices = #{x0}, #{y0}, #{z0}.")
					elsif vertex.z < z0
						x0 = vertex.x
						y0 = vertex.y
						z0 = vertex.z
						#runner.registerInfo("Lower Z Vertices = #{x0}, #{y0}, #{z0}.")
					elsif vertex.z == z0
						x = (x0 - vertex.x).abs
						y = (y0 - vertex.y).abs
						#runner.registerInfo("X and Y = #{x}, #{y}.")
					end
				end
				#runner.registerInfo("Longest X and Y = #{x}, #{y}.")
				#Use x and y differences to calculate the span.
				gable_span_m = Math.sqrt(x**2+y**2)
				gable_span_ft = OpenStudio.convert(gable_span_m, 'm','ft').get
				#runner.registerInfo(" Gable span = #{gable_span_ft}.")
				if gable_span_ft > attic_wall_span
					attic_wall_span = gable_span_ft
					#runner.registerInfo(" Attic wall span was updated to #{attic_wall_span}.")
				end
			#runner.registerInfo("Finished finding the attic wall span for #{surface_name}.")
			end
			
			# For the given surface in the given space, determine if its an attic roof or attic floor.
			if surf.surfaceType == 'RoofCeiling' and construction_stds.intendedSurfaceType.to_s.include?('AtticRoof')		
				#runner.registerInfo("Surface construction is AtticRoof.")
				attic_name = space_name
				roof_name = surface_name
				roof_area_ft2 = area_ft2
				# Add to attic floor area.
				attic_roof_area = attic_roof_area + roof_area_ft2
				# Get the layers from the construction
				layers = const.layers
				# Find the main stud layer. This is a function in construction.rb created by NREL
				sl_i = const.structural_layer_index
				# Skip and warn if we can't find a structural layer
				if sl_i.nil?
					runner.registerInfo("Cannot find structural layer in wall construction #{const.name}; this construction will not be included in the LCA calculations.  To ensure that the LCA calculations work, you must specify the Standards Information fields in the Construction and its constituent Materials.  Use the CEC2013 enumerations.")  
				next
				end	

				# Determine if the surface is an internal or external wall. If its internal, we may have to default the assembly design.
				# Check if the construction has measure tags. If so, then use those. Otherwise interpret the model.
				
				if construction_stds.intendedSurfaceType.is_initialized
					surface_type = construction_stds.intendedSurfaceType.to_s
					#runner.registerInfo("Construction Type = #{surface_type}.")
					if surface_type == 'ExteriorRoof'
						exterior_adjacent_to = 'AMBIENT'
					elsif surface_type == 'AtticRoof'
						exterior_adjacent_to = 'AMBIENT'
					elsif surface_type == 'DemisingRoof'
						exterior_adjacent_to = 'LIVING_SPACE'	
					elsif surface_type == 'GroundContactRoof'
						exterior_adjacent_to = 'GROUND'		
					else
						exterior_adjacent_to = 'OTHER_EXTERIOR_ADJACENT_TO'
					end
				else
					if surf.outsideBoundaryCondition == 'Outdoors'
						exterior_adjacent_to = 'AMBIENT'
					elsif surf.outsideBoundaryCondition == 'Ground' || 'Foundation'
						exterior_adjacent_to = 'GROUND'
					elsif surf.outsideBoundaryCondition == 'Zone' || 'Adiabatic' || 'Surface'
						exterior_adjacent_to = 'LIVING_SPACE'
					else
						exterior_adjacent_to = 'OTHER_EXTERIOR_ADJACENT_TO'
					end	
				end
				#runner.registerInfo("Exterior Adjacent To is #{exterior_adjacent_to}.")
				
				# Calculate pitch of roof surface
				# Use the tilt of the roof surface and convert to pitch value using the formula: tan(tilt)*12=pitch
				radians = surf.tilt.to_s.to_f
				#runner.registerInfo(" Radians = #{radians}.")
				surface_angle = radians * 57.295779513
				#runner.registerInfo(" Roof angle = #{surface_angle}.")	 # Tilt is in radians; 1 radian = 57.295779513 degrees
				pitch = Math.tan(radians) * 12 # pitch is the tangent of the radians multiplied by 12
				#runner.registerInfo(" Roof surface pitch = #{pitch}.")
				
				# Calculate the roof span
				#runner.registerInfo("finding  wall vertices.")
				vertices = surf.vertices
				# Find the distance between 2 points on the same z axis
				length = nil
				width = nil
				x0 = nil
				y0 = nil
				z0 = nil
				# Find the x and y differences
				vertices.each_with_index do |vertex, i|
					#Once the values are populated, skip the rest of the vertices.
					next if length != nil	
					if i == 0
						x0 = vertex.x
						y0 = vertex.y
						z0 = vertex.z
						#runner.registerInfo("Vertices = #{x0}, #{y0}, #{z0}.")
					else 
						if vertex.z == z0
							length = (x0 - vertex.x).abs
							width = (y0 - vertex.y).abs
							#runner.registerInfo("Vertices (m) = #{length}, #{width}.")				
						end
					end
				end
				#runner.registerInfo("Vertices = #{length}, #{width}.")
				#Use x and y differences to calculate the span.
				roof_span_m = Math.sqrt(length**2+width**2)
				roof_span_ft = OpenStudio.convert(roof_span_m, 'm','ft').get
				#runner.registerInfo(" Roof surface span = #{roof_span_ft}.")
				
				#set surface roof span equal to the attic roof span.
				if attic_roof_span < roof_span_ft
					attic_roof_span = roof_span_ft
				end
				
				# Identify the name of the space for which the roof surface is attached to.
				roof_attached_to_space = space_name
				#runner.registerInfo(" Roof surface attached to space #{roof_attached_to_space}.")
				
				# TO DO: Update to get the width and length of the sloped roof surface
				#find roof width
				roof_z_max = -1000000000
				roof_z_min = 1000000000
				#runner.registerInfo("found subsurface vertices.")
				vertices.each do |vertex|
					z = vertex.z
					if z < roof_z_min
						roof_z_min = z
					else next
					end
					if z > roof_z_max
						roof_z_max = z
					else
					end
				end
				#runner.registerInfo("found max and min z vertices.")
				roof_height_m = roof_z_max - roof_z_min
				#runner.registerInfo("wall height = #{wall_height_m}.")
				#Convert to IP
				roof_height_ft = OpenStudio.convert(roof_height_m, 'm','ft').get	
				roof_length_ft = roof_area_ft2 / roof_height_ft
				
				#Find characteristics of the structural layer using Material Standard Information Measure Tags
				# Assumes a single structural layer. For example, does not capture SIPs manually defined by mutliple layers.
				# These are the tags for the structural layer.
				
				sli_stds = layers[sl_i].standardsInformation
				
				if sli_stds.standardsCategory.is_initialized
					category = sli_stds.standardsCategory.get.to_s
					#runner.registerInfo("Structural Layer Category = #{category}.")
				end
				if sli_stds.standardsIdentifier.is_initialized
					identifier = sli_stds.standardsIdentifier.get.to_s
					#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
				end
				if sli_stds.compositeFramingMaterial.is_initialized
					frame_mat = sli_stds.compositeFramingMaterial.get.to_s
					#runner.registerInfo("Structural Layer Framing Material = #{frame_mat}.")
				end
				if sli_stds.compositeFramingConfiguration.is_initialized
					frame_config = sli_stds.compositeFramingConfiguration.get.to_s
					#runner.registerInfo("Structural Layer Framing Config = #{frame_config}.")
				end
				if sli_stds.compositeFramingDepth.is_initialized
					frame_depth = sli_stds.compositeFramingDepth.get.to_s
					#runner.registerInfo("Structural Layer Framing Depth = #{frame_depth}.")
				end
				if sli_stds.compositeFramingSize.is_initialized
					frame_size = sli_stds.compositeFramingSize.get.to_s
					#runner.registerInfo("Structural Layer Framing Size = #{frame_size}.")
				end
				if sli_stds.compositeCavityInsulation.is_initialized
					cavity_ins = sli_stds.compositeCavityInsulation.get.to_i
					#runner.registerInfo("Structural Layer Cavity Insulation = #{cavity_ins}.")
				end
				
				# Find interior and exterior layer for the construction to define the finishes
				# Layers from exterior to interior
				il_identifier = nil
				el_identifier = nil
				roof_type = nil
				roof_interior_finish = nil
				vapor_barrier = nil
				air_barrier = false
				
				layers.each_with_index do |layer, i|
					# Skip fenestration, partition, and airwall materials
					layer = layer.to_OpaqueMaterial
					next if layer.empty?
					layer = layer.get
					#runner.registerInfo("layer = #{layer}.")
					if i == 0
						ext_layer = layer
						#runner.registerInfo("exterior layer = #{ext_layer}.")
						el_i_stds = layer.standardsInformation
						if el_i_stds.standardsCategory.is_initialized
							el_category = el_i_stds.standardsCategory.get.to_s
							#runner.registerInfo("Exterior Layer Category = #{el_category}.")
						end
						if el_i_stds.standardsIdentifier.is_initialized
							el_identifier = el_i_stds.standardsIdentifier.get.to_s
							#runner.registerInfo("Exterior Layer Identifier = #{el_identifier}.")
						end				
					else
						int_layer = layer
						#runner.registerInfo("interior layer = #{int_layer}.")
						il_i_stds = layer.standardsInformation
						if il_i_stds.standardsCategory.is_initialized
							il_category = il_i_stds.standardsCategory.get.to_s
							#runner.registerInfo("Interior Layer Category = #{il_category}.")
						end
						if il_i_stds.standardsIdentifier.is_initialized
							il_identifier = il_i_stds.standardsIdentifier.get.to_s
							#runner.registerInfo("Interior Layer Identifier = #{il_identifier}.")
						end
				  end
				end
				#runner.registerInfo("Interior Layer = #{il_identifier}.")
				#runner.registerInfo("Exterior Layer = #{el_identifier}.")
				
				
				# Convert identifiers to interior wall finish and wall siding for exterior walls.		
				# Interior Wall Finish
				# Category could be Bldg Board and Siding - Limited to gypsum board, otherwise its "other"
				if il_identifier != nil
					if il_identifier.include?('Gypsum Board - 1/2 in.') or il_identifier.include?('Gypsum Board - 3/8 in.')
						interior_wall_finish = 'GYPSUM_REGULAR_1_2'
					elsif il_identifier.include?('Gypsum Board - 3/4 in.') or il_identifier.include?('Gypsum Board - 5/8 in.')
						interior_wall_finish = 'GYPSUM_REGULAR_5_8'
					else
						interior_wall_finish = 'OTHER_FINISH'
					end
				else
					interior_wall_finish = 'NONE'
				end
				#runner.registerInfo("Interior Layer Thickness = #{interior_wall_finish}.")
				
				# Roof Type - Shingles, etc.
				# Category could be Bldg Board and Siding or Roofing or Concrete
				# Question: Should we consider CLT option?
				# Currently does not include EXPANDED_POLYSTYRENE_SHEATHING or PLASTIC_RUBBER_SYNTHETIC_SHEETING
				# These are not typical on a house.
				if el_identifier != nil
					if el_identifier.include?('Metal')					# Assumes metal is steel. Currently missing aluminum siding
						roof_type = 'METAL_SURFACING'
					elsif el_identifier.include?('Asphalt') and el_identifier.include?('shingles')
						roof_type = 'ASPHALT_OR_FIBERGLASS_SHINGLES'
					elsif el_identifier.include?('Wood Shingles') or el_identifier.include?('Woods')
						roof_type = 'WOOD_SHINGLES_OR_SHAKES'
					elsif el_identifier.include?('Shingles')
						roof_type = 'SHINGLES'
					elsif el_identifier.include?('Concrete')
						roof_type = 'CONCRETE_ROOF'
					elsif el_identifier.include?('tile') or el_identifier.include?('Tile') or el_identifier.include?('Slate')
						roof_type = 'SLATE_OR_TILE_SHINGLES'	
					else
						roof_type = 'OTHER_ROOF_TYPE'
					end
				else
					roof_type = 'SHINGLES'
				end
				#runner.registerInfo("Roof Exterior Layer = #{roof_type}.")
				
				#Determine if there is a air barrier or vapor barrier
				# For roofs, this is assumed to be a radiant barrier.
				radiant_barrier = nil
				# Same code as for walls in case we want to expand to specific barrier materials in the future.		
				layers.each_with_index do |layer, i|
					# Skip fenestration, partition, and airwall materials
					layer = layer.to_OpaqueMaterial
					next if layer.empty?
					layer = layer.get
					#runner.registerInfo("layer = #{layer}.")
					barrier_stds = layer.standardsInformation
					if barrier_stds.standardsCategory.is_initialized
						barrier_category = barrier_stds.standardsCategory.get.to_s
						if barrier_category.include?('Building Membrane')
							#runner.registerInfo("Barrier Category = #{barrier_category}.")
							if barrier_stds.standardsIdentifier.is_initialized
								barrier_identifier = barrier_stds.standardsIdentifier.get.to_s
								#runner.registerInfo("Barrier Identifier = #{barrier_identifier}.")
								if barrier_identifier.include?('Vapor')		# Should we add custom identifiers?
									if barrier_identifier.include?('1/16')	# Need to update these values since even 6 mil is too small
										vapor_barrier = 'POLYETHELYNE_3_MIL'
									elsif barrier_identifier.include?('1/8')
										vapor_barrier = 'POLYETHELYNE_3_MIL'
									elsif barrier_identifier.include?('1/4')
										vapor_barrier = 'POLYETHELYNE_6_MIL'
									else
										vapor_barrier = 'PSK' # Default value
									end
								else	
									air_barrier = true
								end
							end				
						end
					end
				end
				#runner.registerInfo("Air Barrier = #{air_barrier}.")
				#runner.registerInfo("Vapor Barrier = #{vapor_barrier}.")
				if air_barrier == true or not vapor_barrier.nil?
					radiant_barrier = true
				else
					radiant_barrier = false
				end	
				
				#Inialize insulations array here because approach to insulation varies by wall type.
				insulations = []
			
				# Define roof framing type based on the measure tags	
				# missing match for ???
				
				# WOOD_STUD Wall Type
				if category.to_s.include?('Wood Framed') # Should only be Wood Framed Rafter Roof
					
					# define the wall type
					rafters_material = 'WOOD_RAFTER'
					
					# define the framing size
					if frame_size == '2x2'
						rafters_size = '_2X2'
					elsif frame_size == '2x3'
						rafters_size = '_2X3'	
					elsif frame_size == '2x4'
						rafters_size = '_2X4'
					elsif frame_size == '2x6'
						rafters_size = '_2X6'
					elsif frame_size == '2x8'
						rafters_size = '_2X8'
					elsif frame_size == '2x10'
						rafters_size = '_2X10'	
					elsif frame_size == '2x12'
						rafters_size = '_2X12'
					elsif frame_size == '2x14'
						rafters_size = '_2X14'
					elsif frame_size == '2x16'
						rafters_size = '_2X16'	
					else
						rafters_size = 'OTHER_SIZE'
					end
					#runner.registerInfo("Rafter Size = #{rafters_size}.")
					
					# define On Center
					#fc = frame_config.get.downcase
					#runner.registerInfo("OC = #{fc}.")
					on_center_in = /(\d+)/.match(frame_config).to_s.to_f
					#runner.registerInfo("OC = #{on_center_in}.")
					
					# Define framing cavity thickness
					if frame_depth == '3_5In'
						cav_thickness = 3.5
					elsif frame_depth == '5_5In'
						cav_thickness = 5.5
					elsif frame_depth == '7_25In'
						cav_thickness = 7.25
					elsif frame_depth == '9_25In'
						cav_thickness = 9.25
					elsif frame_depth == '11_25In'
						cav_thickness = 11.25	
					else
						cav_thickness = nil
					end
					#runner.registerInfo("Cavity Thickness = #{cav_thickness}.")
					
					# define the cavity insulation
					if cavity_ins.nil?
						cav_r_ip = 0
						ins_r_value_per_in = 0
					else
						cav_r_ip = cavity_ins
						#runner.registerInfo("Cavity R Value = #{cav_r_ip}.")
						if not cav_thickness.nil?
							ins_r_value_per_in = cav_r_ip / cav_thickness
						else
							ins_r_value_per_in = nil # If this occurs, there is something wrong.
						end
					end
					#runner.registerInfo("Cavity Insulation R is #{cav_r_ip}.") 
					#runner.registerInfo("Cavity Insulation R per Inch is #{ins_r_value_per_in}.")
					
					# Assume cavity insulation for wood framing is either fiberglass batt or cellulose; are there others to include?
					if not ins_r_value_per_in.nil?
						if ins_r_value_per_in < 0.1
							ins_mat = 'NONE'
						elsif ins_r_value_per_in < 3.6 and ins_r_value_per_in > 0.01
							ins_mat = 'BATT_FIBERGLASS'
						else
							ins_mat = 'LOOSE_FILL_CELLULOSE'
						end
					else
						ins_mat = 'UNKNOWN'
					end
					#runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
					
					if cav_r_ip > 0
						insulationCav = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => cav_thickness,
							'insulationNominalRValue' => cav_r_ip,
							'insulationInstallationType' => 'CAVITY',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Cavity Insulation = #{insulationCav}")
						insulations << insulationCav
					end
					
					concrete_value = {}
					
					clt_values = {}
					
				# Metal Framed Roof Type
				elsif category.to_s.include?('Metal Framed')
					# define the wall type
					rafters_material = 'METAL_RAFTER'
					
					# define the framing size
					if frame_size == '2x2'
						rafters_size = '_2X2'
					elsif frame_size == '2x3'
						rafters_size = '_2X3'	
					elsif frame_size == '2x4'
						rafters_size = '_2X4'
					elsif frame_size == '2x6'
						rafters_size = '_2X6'
					elsif frame_size == '2x8'
						rafters_size = '_2X8'
					elsif frame_size == '2x10'
						rafters_size = '_2X10'	
					elsif frame_size == '2x12'
						rafters_size = '_2X12'
					elsif frame_size == '2x14'
						rafters_size = '_2X14'
					elsif frame_size == '2x16'
						rafters_size = '_2X16'	
					else
						rafters_size = 'OTHER_SIZE'
					end
					#runner.registerInfo("Rafter Size = #{rafters_size}.")
					

					# define On Center
					#fc = frame_config.get.downcase
					#runner.registerInfo("OC = #{fc}.")
					on_center_in = /(\d+)/.match(frame_config).to_s.to_f
					#runner.registerInfo("OC = #{on_center_in}.")
					
					# Define framing cavity thickness
					if frame_depth == '3_5In'
						cav_thickness = 3.5
					elsif frame_depth == '5_5In'
						cav_thickness = 5.5
					elsif frame_depth == '7_25In'
						cav_thickness = 7.25
					elsif frame_depth == '9_25In'
						cav_thickness = 9.25
					elsif frame_depth == '11_25In'
						cav_thickness = 11.25	
					else
						cav_thickness = nil
					end
					#runner.registerInfo("Cavity Thickness = #{cav_thickness}.")
					
					# define the cavity insulation
					if cavity_ins.nil?
						cav_r_ip = 0
						ins_r_value_per_in = 0
					else
						cav_r_ip = cavity_ins
						#runner.registerInfo("Cavity R Value = #{cav_r_ip}.")
						if not cav_thickness.nil?
							ins_r_value_per_in = cav_r_ip / cav_thickness
						else
							ins_r_value_per_in = nil # If this occurs, there is something wrong.
						end
					end
					#runner.registerInfo("Cavity Insulation R is #{cav_r_ip}.") 
					#runner.registerInfo("Cavity Insulation R per Inch is #{ins_r_value_per_in}.")
					
					# Assume cavity insulation for wood framing is either fiberglass batt or cellulose; are there others to include?
					if not ins_r_value_per_in.nil?
						if ins_r_value_per_in < 0.1
							ins_mat = 'NONE'
						elsif ins_r_value_per_in < 3.6 and ins_r_value_per_in > 0.01
							ins_mat = 'BATT_FIBERGLASS'
						else
							ins_mat = 'LOOSE_FILL_CELLULOSE'
						end
					else
						ins_mat = 'UNKNOWN'
					end
					#runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
					
					if cav_r_ip > 0
						insulationCav = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => cav_thickness,
							'insulationNominalRValue' => cav_r_ip,
							'insulationInstallationType' => 'CAVITY',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Cavity Insulation = #{insulationCav}")
						insulations << insulationCav
					end

					concrete_value = {}
					
					clt_values = {}
					

				# SIPS Roof Type
				elsif category.to_s.include?('SIPS')
					# define the roof material type
					rafters_material = 'STRUCTURALLY_INSULATED_PANEL' 	# SIPs are not currently an option
					
					# define the framing size; there are no rafters for SIPs
					studs_size = 'OTHER_SIZE'
					#runner.registerInfo("Studs Size = #{studs_size}.")

					# define On Center
					#fc = frame_config.get.downcase
					#runner.registerInfo("OC = #{fc}.")
					on_center_in = 0
					#runner.registerInfo("OC = #{on_center_in}.")
					
					# parse the standard identifier;  eg SIPS - R55 - OSB Spline - 10 1/4 in.
					
					# find R value of the "cavity" of the SIP
					#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
					sips_r_value_ip =/(\d+)/.match(identifier).to_s.to_f
					#runner.registerInfo("SIPS R Value = #{sips_r_value_ip}.")
					
					# Define framing cavity thickness
					sips_thickness =/(\d+)\s(\d).(\d)/.match(identifier).to_s
					#runner.registerInfo("SIPs insulation thickness = #{sips_thickness}.")
					# assumes 7/16 OSB; missing metal splines and double splines
					if sips_thickness == '4 1/2'
						cav_thickness = (4.5 - 0.875)
					elsif sips_thickness == '6 1/2'
						cav_thickness = (6.5 - 0.875)
					elsif sips_thickness == '8 1/2'
						cav_thickness = (8.5 - 0.875)	
					elsif sips_thickness == '10 1/4'
						cav_thickness = (10.25 - 0.875)
					elsif sips_thickness == '12 1/4'
						cav_thickness = (12.25 - 0.875)	
					else
						cav_thickness = nil
					end
					#runner.registerInfo("SIPS Insulation Thickness = #{cav_thickness}.")
					
					# define the SIPs insulation
					if sips_r_value_ip.nil?
						cav_r_ip = 0
						ins_r_value_per_in = 0
					else
						cav_r_ip = sips_r_value_ip
						#runner.registerInfo("SIPs R Value = #{cav_r_ip}.")
						if not cav_thickness.nil?
							ins_r_value_per_in = cav_r_ip / cav_thickness
						else
							ins_r_value_per_in = nil # If this occurs, there is something wrong.
						end
					end
					#runner.registerInfo("SIPs Insulation R is #{cav_r_ip}.") 
					#runner.registerInfo("SIPs Insulation R per Inch is #{ins_r_value_per_in}.")
					
					# Assume rigid insulation for SIPs; are there others to include?
					if not ins_r_value_per_in.nil?
						if ins_r_value_per_in < 0.1
							ins_mat = 'NONE'
						elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
							ins_mat = 'RIGID_EPS'
						elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
							ins_mat = 'RIGID_XPS'
						elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
							ins_mat = 'RIGID_POLYISOCYANURATE'
						else
							ins_mat = 'RIGID_UNKNOWN'
						end
					else
						ins_mat = 'UNKNOWN'
					end
					#runner.registerInfo("SIPs Insulation is #{ins_mat}.")
					
					if cav_r_ip > 0
						insulationCav = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => cav_thickness,
							'insulationNominalRValue' => cav_r_ip,
							'insulationInstallationType' => 'CAVITY',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Cavity Insulation = #{insulationCav}")
						insulations << insulationCav
					end
					
					concrete_value = {}
					
					clt_values = {}


				elsif category.to_s.include?('Concrete') and not category.to_s.include?('Sandwich Panel')
					rafters_material = 'OTHER_MATERIAL'

					# solid concrete will not have framing or cavity insulation within the material
					studs_size = 'OTHER_SIZE'
					#runner.registerInfo("Studs Size = #{studs_size}.")
					on_center_in = 0
					#runner.registerInfo("OC = #{on_center_in}.")
					# Define concrete thickness
					concrete_thickness =/(\d+)\sin/.match(identifier).to_s
					#runner.registerInfo("Concrete thickness string = #{concrete_thickness}.")
					if concrete_thickness == '6 in'
						cav_thickness = 6
					elsif concrete_thickness == '8 in'
						cav_thickness = 8
					elsif concrete_thickness == '10 in'
						cav_thickness = 10	
					elsif concrete_thickness == '12 in'
						cav_thickness = 12
					else
						cav_thickness = nil
					end
					#runner.registerInfo("Concrete Thickness = #{cav_thickness}.")
					ins_mat = 'NONE'
					#runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
					# Currently creating the cavity insulation object, but could be deleted.
					# TO DO: How do we handle framing on the inside of the concrete wall?
					cav_r_ip = 0
					if cav_r_ip > 0
						insulationCav = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => cav_thickness,
							'insulationNominalRValue' => cav_r_ip,
							'insulationInstallationType' => 'CAVITY',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Cavity Insulation = #{insulationCav}")
						insulations << insulationCav
					end
					#Find concrete strength and reinforcement from standards identifier
					#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
					concrete_name = identifier.to_s
					#runner.registerInfo("Concrete Name = #{concrete_name}.")
					density =/(\d+)/.match(identifier).to_s.to_f
					#runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
					compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
					#runner.registerInfo("PSI = #{compressive_strength_value}.")

					# Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
					if compressive_strength_value < 2000
						compressive_strength = 'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
					elsif 	compressive_strength_value > 2000 and compressive_strength_value < 2750
						compressive_strength = '_2500_PSI'
					elsif 	compressive_strength_value > 2750 and compressive_strength_value < 3500
						compressive_strength = '_3000_PSI'
					elsif 	compressive_strength_value > 3500 and compressive_strength_value < 4500
						compressive_strength = '_4000_PSI'
					elsif 	compressive_strength_value > 4500 and compressive_strength_value < 5500
						compressive_strength = '_5000_PSI'
					elsif 	compressive_strength_value > 5500 and compressive_strength_value < 7000
						compressive_strength = '_6000_PSI'
					elsif 	compressive_strength_value > 7000
						compressive_strength = '_8000_PSI'
					else
						compressive_strength = 'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
					end
					
					# Define reinforcement - defaulted to 5 
					rebar_number = 5  # defaulted to 5 for no particular reason
					
					# Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
					if rebar_number = 4
						reinforcement = 'REBAR_NO_4'
					elsif rebar_number = 5
						reinforcement = 'REBAR_NO_5'
					elsif rebar_number = 6
						reinforcement = 'REBAR_NO_6'
					else
						reinforcement = 'UNSPECIFIED_CONCRETE_REINFORCEMENT'
					end
				
					concrete_value = {
						'concreteName' => concrete_name,
						'compressiveStrength' => compressive_strength,
						'reinforcement' => reinforcement
					}
					#runner.registerInfo("Concrete value = #{concrete_value}")
					
					clt_values = {}

				# Masonry Unit Walls - Assume concrete; ignores clay masonry; excludes block fill
				elsif category.to_s.include?('Masonry Units')
					wall_type = 'CONCRETE_MASONRY_UNIT'
					
					#Provide details on the masonry fill; currently not used for anything.
					if category.to_s.include?('Hollow')
						wall_fill_unused = 'HOLLOW'
					elsif category.to_s.include?('Solid')
						wall_fill_unused = 'SOLID'
					elsif category.to_s.include?('Fill')
						wall_fill_unused = 'FILL'
					else
						wall_fill_unused = 'UNKNOWN'
					end
					
					# ICF wall will not have framing or cavity insulation within the material
					studs_size = 'OTHER_SIZE'
					#runner.registerInfo("Studs Size = #{studs_size}.")
					on_center_in = 0
					#runner.registerInfo("OC = #{on_center_in}.")
					
					# Define thickness of the block
					cmu_thickness =/(\d+)\sin/.match(identifier).to_s
					#runner.registerInfo("CMU thickness string = #{cmu_thickness}.")
					if cmu_thickness == '6 in'
						cav_thickness = 6
					elsif cmu_thickness == '8 in'
						cav_thickness = 8
					elsif cmu_thickness == '10 in'
						cav_thickness = 10	
					elsif cmu_thickness == '12 in'
						cav_thickness = 12
					else
						cav_thickness = nil
					end
					#runner.registerInfo("CMU Thickness = #{cav_thickness}.")
					
					ins_mat = 'NONE'
					#runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
					# Currently creating the cavity insulation object, but could be deleted.
					# TO DO: How do we handle framing on the inside of the concrete wall?
					cav_r_ip = 0
					if cav_r_ip > 0
						insulationCav = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => cav_thickness,
							'insulationNominalRValue' => cav_r_ip,
							'insulationInstallationType' => 'CAVITY',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Cavity Insulation = #{insulationCav}")
						insulations << insulationCav
					end

					#Find concrete strength and reinforcement from standards identifier
					#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
					concrete_name = identifier.to_s
					#runner.registerInfo("Concrete Name = #{concrete_name}.")
					density =/(\d+)/.match(identifier).to_s.to_f
					#runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
					compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
					#runner.registerInfo("PSI = #{compressive_strength_value}.")

					# Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
					if compressive_strength_value < 2000
						compressive_strength = 'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
					elsif 	compressive_strength_value > 2000 and compressive_strength_value < 2750
						compressive_strength = '_2500_PSI'
					elsif 	compressive_strength_value > 2750 and compressive_strength_value < 3500
						compressive_strength = '_3000_PSI'
					elsif 	compressive_strength_value > 3500 and compressive_strength_value < 4500
						compressive_strength = '_4000_PSI'
					elsif 	compressive_strength_value > 4500 and compressive_strength_value < 5500
						compressive_strength = '_5000_PSI'
					elsif 	compressive_strength_value > 5500 and compressive_strength_value < 7000
						compressive_strength = '_6000_PSI'
					elsif 	compressive_strength_value > 7000
						compressive_strength = '_8000_PSI'
					else
						compressive_strength = 'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
					end
					
					# Define reinforcement - defaulted to 5 
					rebar_number = 5  # defaulted to 5 for no particular reason
					
					# Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
					if rebar_number = 4
						reinforcement = 'REBAR_NO_4'
					elsif rebar_number = 5
						reinforcement = 'REBAR_NO_5'
					elsif rebar_number = 6
						reinforcement = 'REBAR_NO_6'
					else
						reinforcement = 'UNSPECIFIED_CONCRETE_REINFORCEMENT'
					end
					
					concrete_value = {
						'concreteName' => concrete_name,
						'compressiveStrength' => compressive_strength,
						'reinforcement' => reinforcement
					}
					#runner.registerInfo("Concrete value = #{concrete_value}")
					
					clt_values = {}
				
				elsif category.to_s.include?('ICF')
					wall_type = 'INSULATED_CONCRETE_FORMS'
					
					# solid concrete will not have framing or cavity insulation within the material
					studs_size = 'OTHER_SIZE'
					#runner.registerInfo("Studs Size = #{studs_size}.")
					on_center_in = 0
					#runner.registerInfo("OC = #{on_center_in}.")
					
					# Insulating Concrete Forms - 1 1/2 in. Polyurethane Ins. each side - concrete 8 in.
					# Define thickness of the concrete
					concrete_thickness =/(\d+)\sin/.match(identifier).to_s
					#runner.registerInfo("ICF thickness string = #{concrete_thickness}.")
					if concrete_thickness == '6 in'
						cav_thickness = 6
					elsif concrete_thickness == '8 in'
						cav_thickness = 8
					else
						cav_thickness = nil
					end
					#runner.registerInfo("Concrete Thickness = #{cav_thickness}.")
					
					# define the ICF insulation type
					icf_ins = identifier.to_s
					#runner.registerInfo("ICF String = #{icf_ins}.")
					
					if identifier.to_s.include?('XPS')
						ins_mat = 'RIGID_XPS'
						ins_r_value_per_in = 5.0
					elsif identifier.to_s.include?('EPS')
						ins_mat = 'RIGID_EPS'
						ins_r_value_per_in = 5.0
					elsif identifier.to_s.include?('Polyurethane')
						ins_mat = 'SPRAY_FOAM_CLOSED_CELL'
						ins_r_value_per_in = 5.0
					elsif identifier.to_s.include?('Polyiso')
						ins_mat = 'RIGID_POLYISOCYANURATE' 
						ins_r_value_per_in = 5.0
					else
						ins_mat = 'UNKNOWN'
						ins_r_value_per_in = 0
					end
					#runner.registerInfo("ICF Insulation is #{ins_mat}.")
					#runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")
					
					# define the ICF insulation thickness; concrete is always thicker than the insulation
					if identifier.to_s.include?('1 1/2 in.')
						cav_thickness = 1.5
					elsif identifier.to_s.include?('2 in.')
						cav_thickness = 2
					elsif identifier.to_s.include?('2 1/2 in.')
						cav_thickness = 2.5
					elsif identifier.to_s.include?('3 in.')
						cav_thickness = 3
					elsif identifier.to_s.include?('4 in.')
						cav_thickness = 4	
					elsif identifier.to_s.include?('4 1/2 in.')
						cav_thickness = 4.5
					else
						cav_thickness = nil
					end
					#runner.registerInfo("ICF Thickness = #{cav_thickness}.")
					cav_r_ip = cav_thickness * ins_r_value_per_in
					#runner.registerInfo("ICF Insulation R Value = #{cav_r_ip}.")
					
					if cav_r_ip > 0
						insulationCav = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => cav_thickness,
							'insulationNominalRValue' => cav_r_ip,
							'insulationInstallationType' => 'CAVITY',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Cavity Insulation = #{insulationCav}")
						insulations << insulationCav
					end

					##Find concrete strength and reinforcement from standards identifier
					#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
					concrete_name = identifier.to_s
					#runner.registerInfo("Concrete Name = #{concrete_name}.")
					density =/(\d+)/.match(identifier).to_s.to_f
					#runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
					compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
					#runner.registerInfo("PSI = #{compressive_strength_value}.")

					# Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
					if compressive_strength_value < 2000
						compressive_strength = 'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
					elsif 	compressive_strength_value > 2000 and compressive_strength_value < 2750
						compressive_strength = '_2500_PSI'
					elsif 	compressive_strength_value > 2750 and compressive_strength_value < 3500
						compressive_strength = '_3000_PSI'
					elsif 	compressive_strength_value > 3500 and compressive_strength_value < 4500
						compressive_strength = '_4000_PSI'
					elsif 	compressive_strength_value > 4500 and compressive_strength_value < 5500
						compressive_strength = '_5000_PSI'
					elsif 	compressive_strength_value > 5500 and compressive_strength_value < 7000
						compressive_strength = '_6000_PSI'
					elsif 	compressive_strength_value > 7000
						compressive_strength = '_8000_PSI'
					else
						compressive_strength = 'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
					end
					
					# Define reinforcement - defaulted to 5 
					rebar_number = 5  # defaulted to 5 for no particular reason
					
					# Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
					if rebar_number = 4
						reinforcement = 'REBAR_NO_4'
					elsif rebar_number = 5
						reinforcement = 'REBAR_NO_5'
					elsif rebar_number = 6
						reinforcement = 'REBAR_NO_6'
					else
						reinforcement = 'UNSPECIFIED_CONCRETE_REINFORCEMENT'
					end
					
					concrete_value = {
						'concreteName' => concrete_name,
						'compressiveStrength' => compressive_strength,
						'reinforcement' => reinforcement
					}
					#runner.registerInfo("Concrete value = #{concrete_value}")
					
					clt_values = {}
				
				# Concrete Sandwich Panel Walls; matched to ICF because the material take-off approach is the same
				elsif category.to_s.include?('Concrete Sandwich Panel')
					rafters_material = 'OTHER_MATERIAL'
					# solid concrete will not have framing or cavity insulation within the material
					studs_size = 'OTHER_SIZE'
					#runner.registerInfo("Studs Size = #{studs_size}.")
					on_center_in = 0
					#runner.registerInfo("OC = #{on_center_in}.")
					
					# Concrete Sandwich Panel - 100% Ins. Layer - No Steel in Ins. - Ins. 1 1/2 in.
					# Concrete Sandwich Panel - 100% Ins. Layer - Steel in Ins. - Ins. 1 1/2 in.
					# Concrete Sandwich Panel - 90% Ins. Layer - No Steel in Ins. - Ins. 2 in.
					
					# Define thickness of the concrete
					concrete_thickness = 3 * 2 # Defaulted to 3 in wythes of concrete 
					
					# define the CSP insulation thickness
					if identifier.to_s.include?('1 1/2 in.')
						ins_thickness = 1.5
					elsif identifier.to_s.include?('2 in.')
						ins_thickness = 2
					elsif identifier.to_s.include?('3 in.')
						ins_thickness = 3
					elsif identifier.to_s.include?('4 in.')
						ins_thickness = 4	
					elsif identifier.to_s.include?('5 in.')
						ins_thickness = 5
					elsif identifier.to_s.include?('6 in.')
						ins_thickness = 6
					else
						ins_thickness = nil
					end
					#runner.registerInfo("Insulation Thickness = #{ins_thickness}.")
					
					# define the ICF insulation type and R value
					ins_mat = 'RIGID_EPS'
					ins_r_value_per_in = 5
					#runner.registerInfo("ICF Insulation is #{ins_mat}.")
					#runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")
					
					# Calculate total Cavity R value
					cav_r_ip = ins_thickness * ins_r_value_per_in
					#runner.registerInfo("CSP Insulation R Value = #{cav_r_ip}.")
					
					# calculate structural layer thickness
					cav_thickness = concrete_thickness + ins_thickness
					
					if cav_r_ip > 0
						insulationCav = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => cav_thickness,
							'insulationNominalRValue' => cav_r_ip,
							'insulationInstallationType' => 'CAVITY',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Cavity Insulation = #{insulationCav}")
						insulations << insulationCav
					end

					#Find concrete strength and reinforcement from standards identifier
					#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
					concrete_name = identifier.to_s
					#runner.registerInfo("Concrete Name = #{concrete_name}.")
					density =/(\d+)/.match(identifier).to_s.to_f
					#runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
					compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
					#runner.registerInfo("PSI = #{compressive_strength_value}.")

					# Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
					if compressive_strength_value < 2000
						compressive_strength = 'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
					elsif 	compressive_strength_value > 2000 and compressive_strength_value < 2750
						compressive_strength = '_2500_PSI'
					elsif 	compressive_strength_value > 2750 and compressive_strength_value < 3500
						compressive_strength = '_3000_PSI'
					elsif 	compressive_strength_value > 3500 and compressive_strength_value < 4500
						compressive_strength = '_4000_PSI'
					elsif 	compressive_strength_value > 4500 and compressive_strength_value < 5500
						compressive_strength = '_5000_PSI'
					elsif 	compressive_strength_value > 5500 and compressive_strength_value < 7000
						compressive_strength = '_6000_PSI'
					elsif 	compressive_strength_value > 7000
						compressive_strength = '_8000_PSI'
					else
						compressive_strength = 'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
					end
					
					# Define reinforcement - defaulted to 5 
					rebar_number = 5  # defaulted to 5 for no particular reason
					
					# Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
					if rebar_number = 4
						reinforcement = 'REBAR_NO_4'
					elsif rebar_number = 5
						reinforcement = 'REBAR_NO_5'
					elsif rebar_number = 6
						reinforcement = 'REBAR_NO_6'
					else
						reinforcement = 'UNSPECIFIED_CONCRETE_REINFORCEMENT'
					end
					
					concrete_value = {
						'concreteName' => concrete_name,
						'compressiveStrength' => compressive_strength,
						'reinforcement' => reinforcement
					}
					#runner.registerInfo("Concrete value = #{concrete_value}")
					
					clt_values = {}

				# Metal Insulated Panel Walls; metal SIPs
				elsif category.to_s.include?('Metal Insulated Panel Wall')
					rafters_material = 'STRUCTURALLY_INSULATED_PANEL'
				
					# Metal Insulated Panels - 2 1/2 in.
					# metal is assumed to be 26 gauge steel at 0.02 in thick for a total of 0.04 in of steel.
					# Currently assume metal thickness is additional to defined thickness
					
					# define the panel thickness
					if identifier.to_s.include?('2 in.')
						cav_thickness = 2
					elsif identifier.to_s.include?('2 1/2 in.')
						cav_thickness = 2.5
					elsif identifier.to_s.include?('3 in.')
						cav_thickness = 3
					elsif identifier.to_s.include?('4 in.')
						cav_thickness = 4	
					elsif identifier.to_s.include?('5 in.')
						cav_thickness = 5
					elsif identifier.to_s.include?('6 in.')
						cav_thickness = 6
					else
						cav_thickness = nil
					end
					#runner.registerInfo("Insulation Thickness = #{cav_thickness}.")
					
					# define the insulation type and R value; assume EPS at R-5/in
					ins_mat = 'RIGID_EPS'
					ins_r_value_per_in = 5
					#runner.registerInfo("Metal Panel Wall Insulation is #{ins_mat}.")
					#runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")
					
					# Calculate total Cavity R value
					cav_r_ip = cav_thickness * ins_r_value_per_in
					#runner.registerInfo("CSP Insulation R Value = #{cav_r_ip}.")
					
					if cav_r_ip > 0
						insulationCav = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => cav_thickness,
							'insulationNominalRValue' => cav_r_ip,
							'insulationInstallationType' => 'CAVITY',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Cavity Insulation = #{insulationCav}")
						insulations << insulationCav
					end
					
					concrete_value = {}
					
					clt_values = {}
				
				# Cross Laminated Timber (CLT) Walls - does not include any insulation.
				# User must manually add a standards category and standards identifier
				# Category = CLT; Identifier Format = X in. 50/75/100 psf Live Load
				elsif category.to_s.include?('CLT')	or 	category.to_s.include?('Cross Laminated Timber') or category.to_s.include?('Woods')	# not a tag option at the moment
					rafters_material = 'CROSS_LAMINATED_TIMBER'
				
					# define the framing size; there are no rafters for SIPs
					studs_size = 'OTHER_SIZE'
					#runner.registerInfo("Studs Size = #{studs_size}.")

					# define On Center
					#fc = frame_config.get.downcase
					#runner.registerInfo("OC = #{fc}.")
					on_center_in = 0
					#runner.registerInfo("OC = #{on_center_in}.")
					
					# parse the standard identifier;  eg CLT - 2x4 - 3 Layers
					
					# find R value of the "cavity" of the SIP
					#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
					live_load = 50
					if not category.nil?
						live_load =/(\d+)\spsf/.match(identifier).to_s.to_f
					end
					#runner.registerInfo("Live Load = #{live_load}.")
					
					# Define framing cavity thickness
					clt_thickness =/(\d+)\sin./.match(identifier).to_s
					#runner.registerInfo("CLT thickness = #{clt_thickness}.")
					value, unit = clt_thickness.split(' ')
					cav_thickness = value.to_f
					#runner.registerInfo("CLT Thickness = #{cav_thickness}.")
			
					cav_r_ip = 0
					ins_r_value_per_in = 0
					ins_r_value_per_in = 0
					ins_mat = 'NONE'
					
					if cav_r_ip > 0
						insulationCav = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => cav_thickness,
							'insulationNominalRValue' => cav_r_ip,
							'insulationInstallationType' => 'CAVITY',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Cavity Insulation = #{insulationCav}")
						insulations << insulationCav
					end
					
					concrete_value = {}
					
					# Define supported span using wall length and stories - defaulted to 1 for residential
					supported_span = wall_length_ft #equal to the width of the wall; what is the max span?
					supported_stories = 1	#assume 1 story for residential.
					
					# Define supported element
					clt_supported_element_type = 'ROOF'	#if surface is first floor then assume "floor", if 2nd floor assume "roof"
				
					clt_values = {
						'liveLoad' => live_load,	#kPa
						'supportedSpan' => supported_span,	#the length of wall unless it exceeds the maximum
						'supportedElementType' => clt_supported_element_type,
						'supportedStories' => supported_stories
					}
				
				else								# Includes Spandrel Panels Curtain Walls and straw bale wall; 
					rafters_material = 'OTHER_MATERIAL'
					# define the framing size; there are no studs for SIPs
					studs_size = 'OTHER_SIZE'
					#runner.registerInfo("Studs Size = #{studs_size}.")

					# define On Center
					#fc = frame_config.get.downcase
					#runner.registerInfo("OC = #{fc}.")
					on_center_in = 0
					#runner.registerInfo("OC = #{on_center_in}.")
					
					cav_r_ip = 0
					ins_r_value_per_in = 0
					ins_r_value_per_in = 0
					ins_mat = 'NONE'
					
					if cav_r_ip > 0
						insulationCav = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => cav_thickness,
							'insulationNominalRValue' => cav_r_ip,
							'insulationInstallationType' => 'CAVITY',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Cavity Insulation = #{insulationCav}")
						insulations << insulationCav
					end
					
					concrete_value = {}
					
					clt_values = {}
					
				end
				
				
				# Additional insulation either interior or exterior to the structural layer (composite framing layer, SIPs, CIFs, CLTs)
				# Use structural layer as base to find other insulation.
				
				# Interior rigid insulation r-value
				rigid_ins_int = const.rigid_insulation_values(sl_i, 'interior')
				int_r = rigid_ins_int[0].to_s.to_f
				int_t = rigid_ins_int[1].to_s.to_f
				#This is an R Value, but we need to determine the material.
				if rigid_ins_int.nil?
					int_r_ip = 0
					interior_rigid_thickness = 0
				else
					int_r_ip = int_r
					interior_rigid_thickness = int_t
					ins_r_value_per_in = int_r / int_t
					
					if ins_r_value_per_in < 0.1
						ins_mat = 'NONE'
					elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
						ins_mat = 'RIGID_EPS'
					elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
						ins_mat = 'RIGID_XPS'
					elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
						ins_mat = 'RIGID_POLYISOCYANURATE'
					else
						ins_mat = 'RIGID_UNKNOWN'
					end
				end
				#runner.registerInfo("Insulation R is #{int_r_ip}.")
				#runner.registerInfo("Insulation Type is #{ins_mat}.")
				#runner.registerInfo("Insulation Thickness is #{interior_rigid_thickness}.")
				
				if int_r_ip > 0
					insulationInt = {
						'insulationMaterial' => ins_mat,
						'insulationThickness' => interior_rigid_thickness.round(1),
						'insulationNominalRValue' => int_r_ip.round(1),
						'insulationInstallationType' => 'CONTINUOUS',
						'insulationLocation' => 'INTERIOR'
					}
					#runner.registerInfo("Insulation = #{insulationInt}")
					insulations << insulationInt
				end
				
				# Exterior rigid insulation r-value		
				rigid_ins_ext = const.rigid_insulation_values(sl_i, 'exterior')
				ext_r = rigid_ins_ext[0].to_s.to_f
				ext_t = rigid_ins_ext[1].to_s.to_f
				#This is an R Value, but we need to determine the material.
				if rigid_ins_ext.nil?
					ext_r_ip = 0
					exterior_rigid_thickness = 0
				else
					ext_r_ip = ext_r
					exterior_rigid_thickness = ext_t
					ins_r_value_per_in = ext_r / ext_t
					
					if ins_r_value_per_in < 0.1
						ins_mat = 'NONE'
					elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
						ins_mat = 'RIGID_EPS'
					elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
						ins_mat = 'RIGID_XPS'
					elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
						ins_mat = 'RIGID_POLYISOCYANURATE'
					else
						ins_mat = 'RIGID_UNKNOWN'
					end
				end
				#runner.registerInfo("Insulation R is #{ext_r_ip}.")
				#runner.registerInfo("Insulation Type is #{ins_mat}.")
				#runner.registerInfo("Insulation Thickness is #{exterior_rigid_thickness}.")
				
				if ext_r_ip > 0
					insulationExt = {
						'insulationMaterial' => ins_mat,
						'insulationThickness' => exterior_rigid_thickness.round(1),
						'insulationNominalRValue' => ext_r_ip.round(1),
						'insulationInstallationType' => 'CONTINUOUS',
						'insulationLocation' => 'EXTERIOR'
					}
					#runner.registerInfo("Insulation = #{insulationExt}")
					insulations << insulationExt
				end
				
				# Find the Floor Decking Type
				roof_decking_type = 'NONE' # Defaulted to None in case no decking is found.
				deck_identifier = nil
				deck_category = nil
				
				layers.each_with_index do |layer, i|
					# Skip fenestration, partition, and airwall materials
					next if roof_decking_type == 'WOOD' or roof_decking_type == 'METAL'
					layer = layer.to_OpaqueMaterial
					next if layer.empty?
					deck_layer = layer.get
					deck_stds = deck_layer.standardsInformation
					next if not deck_stds.standardsIdentifier.is_initialized				
					deck_identifier = deck_stds.standardsIdentifier.get.to_s
					deck_identifier = deck_identifier.downcase
					#runner.registerInfo("Deck Layer Identifier = #{deck_identifier}.")
					if deck_identifier.include?('osb') or deck_identifier.include?('plywood')
						roof_decking_type = 'WOOD'
					elsif deck_identifier.include?('Metal Deck')
						roof_decking_type = 'METAL'
					else
						roof_decking_type = 'NONE'
					end					
				end
				#runner.registerInfo("Frame Floor Decking = #{roof_decking_type}.")
				
				# define roof construction type
				if rafters_material == 'WOOD_RAFTER'		
					roof_construction_type = 'RAFTER'		# Ignores TRUSS for now.
				elsif rafters_material == 'METAL_RAFTER'
					roof_construction_type = 'RAFTER'		# Ignores TRUSS for now.
				elsif category.include?('Concrete') or category.include?('ICF')
					roof_construction_type = 'CONCRETE_DECK' #
				else 										# Handles all 'OTHER_MATERIAL'
					roof_construction_type = 'OTHER'		# There is no rafter or truss for CLT, concrete, ICF, SIPs, or MIPs
				end
				
				#Need to find all subsurfaces on a roof surface and determine which are skylights.
				#Then pull the information for each to add to the array.
				#This will require a do loop through each wall surface.
				skylights = []

				#if subsurface is a skylight, then populate the skylight object.
				#Only need to populate the physical components or the performance specs. Use performance specs from OSM.
				#Can I pull this info from OSM or do I have to go through each E+ skylight object, match the surface name, and pull specs?
				
				#runner.registerInfo("finding all skylights in this roof surface.")
				surf.subSurfaces.each do |ss|
					#if ss is a skylight, else its a door.
					#runner.registerInfo("found subsurface.")
					subsurface_type = ss.subSurfaceType
					#runner.registerInfo("found subsurface type: #{subsurface_type}.")
					# Determine if the subsurface is a skylight or other
					if subsurface_type == 'Skylight'
						operable = false		# hard code to No
						skylight_name = ss.name
						#runner.registerInfo("found subsurface #{skylight_name}.")
						skylight_area_m2 = ss.grossArea
						#runner.registerInfo("found subsurface #{skylight_name} with area #{skylight_area}.")
						skylight_area_ft2 = OpenStudio.convert(skylight_area_m2, 'm^2','ft^2').get
						skylight_z_max = -1000000000
						skylight_z_min = 1000000000
						#runner.registerInfo("finding subsurface vertices.")
						vertices = ss.vertices
						#runner.registerInfo("found subsurface vertices.")
						vertices.each do |vertex|
							z = vertex.z
							if z < skylight_z_min
								skylight_z_min = z
							else next
							end					
							if z > skylight_z_max
								skylight_z_max = z
							else
							end
						end
						#runner.registerInfo("found max and min z vertices.")
						skylight_height_m = skylight_z_max - skylight_z_min
						#runner.registerInfo("skylight height = #{skylight_height_m}.")
						#Convert to IP
						skylight_height_ft = OpenStudio.convert(skylight_height_m, 'm','ft').get

						# Take skylight name and use it to find the specs.
						# Parse the skylight name, upcase the letters, and then put back together. The periods are causing the problem.
						skylight_name_string = skylight_name.to_s
						#runner.registerInfo("skylight name now string: #{skylight_name_string}.")
						skylight_name_capped = skylight_name_string.upcase
						#runner.registerInfo("skylight name capped: #{skylight_name_capped}.")
						# query the SQL file including the row name being a variable. Treat like its in a runner.
						# U-Factor Query
						query = "SELECT Value
						  FROM tabulardatawithstrings
						  WHERE ReportName='EnvelopeSummary'
						  AND ReportForString= 'Entire Facility'
						  AND TableName='Exterior Fenestration'
						  AND ColumnName='Glass U-Factor'
						  AND RowName='#{skylight_name_capped}'
						  AND Units='W/m2-K'"       
						#runner.registerInfo("Query is #{query}.")
						u_si = sql.execAndReturnFirstDouble(query)
						#runner.registerInfo("U-SI value was found: #{u_si}.")
						if u_si.is_initialized
						  u_si = u_si.get
						else
						  u_si = 0
						end
						u_ip = OpenStudio.convert(u_si, 'W/m^2*K','Btu/hr*ft^2*R').get
						# SHGC Query
						query = "SELECT Value
						  FROM tabulardatawithstrings
						  WHERE ReportName='EnvelopeSummary'
						  AND ReportForString= 'Entire Facility'
						  AND TableName='Exterior Fenestration'
						  AND ColumnName='Glass SHGC'
						  AND RowName='#{skylight_name_capped}'"       
						#runner.registerInfo("Query is #{query}.")
						shgc = sql.execAndReturnFirstDouble(query)
						#runner.registerInfo("SHGC value was found: #{shgc}.")
						if shgc.is_initialized
						  shgc = shgc.get
						else
						  shgc = 0
						end
						
						# VT Query
						query = "SELECT Value
						  FROM tabulardatawithstrings
						  WHERE ReportName='EnvelopeSummary'
						  AND ReportForString= 'Entire Facility'
						  AND TableName='Exterior Fenestration'
						  AND ColumnName='Glass Visible Transmittance'
						  AND RowName='#{skylight_name_capped}'"       
						#runner.registerInfo("Query is #{query}.")
						vt = sql.execAndReturnFirstDouble(query)
						#runner.registerInfo("U-SI value was found: #{vt}.")
						if vt.is_initialized
						  vt = vt.get
						else
						  vt = 0
						end
						
						skylight = {
							'name'=> skylight_name,
							'operable'=> operable,
							'area'=> skylight_area_ft2.round(2),
							'height' => skylight_height_ft.round(2),	# TO DO  - need to add to enumerations
							'quantity'=> 1,			# Hard coded until we introduce HPXML
							'frameType'=> 'NONE_FRAME_TYPE',		# Hard coded until we introduce Construction Fenstration Information option
							'glassLayer'=> 'NONE_GLASS_LAYERS',		# Hard coded until we introduce Construction Fenstration Information option
							'glassType'=> 'NONE_GLASS_TYPE',		# Hard coded until we introduce Construction Fenstration Information option
							'gasFill'=> 'NONE_GAS_FILL',			# Hard coded until we introduce Construction Fenstration Information option
							'shgc'=> shgc.round(4),
							'visualTransmittance'=> vt.round(4),
							'uFactor'=> u_ip.round(4)
						}
						#runner.registerInfo("skylight = #{skylight}")
						skylights << skylight
						attic_skylights << skylight
					else	
						#runner.registerInfo("subsurface type is not a skylight and will be skipped: #{subsurface_type}.")
					end
				end
				
				#Populate the surface object
				#runner.registerInfo("Creating Roof object.")
				atticRoof = {
					'roofName' => roof_name,
					'attachedToSpace' => roof_attached_to_space,		# attic space to which the roof surface belongs
					'roofInsulations' => insulations,					# Array of the insulations just like walls
					'deckType' => roof_decking_type,					# roof deck material - wood default
					'roofType' => roof_type,							# roof finishing material (shingles, etc)
					'radiantBarrier' => radiant_barrier,				# defaulted to yes; search roof layers for barrier
					'roofArea' => roof_area_ft2.round(2),				# sum of roof surfaces for the specific zone
					'RoofConstructionType' => roof_construction_type, 	# rafter or truss	
					'raftersSize' => rafters_size,						# defined in composite layer standard information
					'rafterSpacing' => on_center_in,					# rafters framing - OC
					'raftersMaterials' => rafters_material,				# defined in composite layer standard information
					'pitch' => pitch.round(1),							# defined by using the slope of the roof surfaces
					'roofSpan' => roof_span_ft.round(2),				# use the longest axis of the roof
					'skyLights' => skylights							# all skylights subsurfaces in all roof surfaces 
				}
				#runner.registerInfo("Attic Roof = #{atticRoof}")
				# Add roof object details to the array
				atticRoofs << atticRoof
				
				# Grab remaining surface specific values for the attic specs; assumes all surfaces have the same constructions.
				attic_roof_insulations = insulations
				attic_deck_type = roof_decking_type
				attic_roof_type = roof_type
				attic_radiant_barrier = radiant_barrier
				attic_rafters_size = rafters_size
				attic_rafters_mat = rafters_material
				attic_pitch = pitch
				#runner.registerInfo("attic_pitch = #{attic_pitch.round(0)}.")
			end
				
			# FIND ATTIC FLOORS
			if surf.surfaceType == 'Floor' and construction_stds.intendedSurfaceType.to_s.include?('AtticFloor')
				# Assumes construction_stds.intendedSurfaceType.is_initialized. Could error out if its not initialized...					
				# Define the space as an attic; name the surface as a floor; find the area of the surface and add to the attic floor area.
				attic_name = space_name
				floor_name = surface_name
				floor_area_ft2 = area_ft2
				# Add to attic floor area.
				attic_floor_area = attic_floor_area + floor_area_ft2
				
				# Get the layers from the construction
				layers = const.layers
				# Find the main stud layer. This is a function in construction.rb created by NREL
				sl_i = const.structural_layer_index
				# Skip and warn if we can't find a structural layer
				if sl_i.nil?
					runner.registerInfo("Cannot find structural layer in wall construction #{const.name}; this construction will not be included in the LCA calculations.  To ensure that the LCA calculations work, you must specify the Standards Information fields in the Construction and its constituent Materials.  Use the CEC2013 enumerations.")  
				next
				end	
				
				# Calculate the floor span by saving the longest 
				#runner.registerInfo("finding  wall vertices.")
				vertices = surf.vertices
				# Find the distance between 2 points on the same z axis
				length = nil
				width = nil
				x0 = nil
				y0 = nil
				z0 = nil
				# Find the x and y differences
				vertices.each_with_index do |vertex, i|
					#Once the values are populated, skip the rest of the vertices.
					if i == 0
						x0 = vertex.x
						y0 = vertex.y
						z0 = vertex.z
						#runner.registerInfo("Vertices = #{x0}, #{y0}, #{z0}.")
					else 
						if vertex.z == z0
							length = (x0 - vertex.x).abs
							width = (y0 - vertex.y).abs
							#runner.registerInfo("Vertices (m) = #{length}, #{width}.")				
						end
					end
				end
				#runner.registerInfo("Vertices = #{length}, #{width}.")
				#Use x and y differences to calculate the span.
				floor_span_m = Math.sqrt(length**2+width**2)
				floor_span_ft = OpenStudio.convert(floor_span_m, 'm','ft').get
				#runner.registerInfo(" Floor surface span = #{floor_span_ft}.")				
				if floor_span_ft > attic_floor_span
					attic_floor_span = floor_span_ft
				end
				#Find characteristics of the structural layer using Material Standard Information Measure Tags
				# Assumes a single structural layer. For example, does not capture SIPs manually defined by mutliple layers.
				# These are the tags for the structural layer.
				# Trusses have space for HVAC and DHW lines. Should be used if there is a basement or conditioned attic.

				frame_floor_type = nil # either floor joist or floor truss. 
				frame_floor_type = 'truss' # Default to floor truss. Base on user input or conditional or basements and space conditioned.
				
				# Structural layer 
				sli_stds = layers[sl_i].standardsInformation
				
				if sli_stds.standardsCategory.is_initialized
					category = sli_stds.standardsCategory.get.to_s
					#runner.registerInfo("Structural Layer Category = #{category}.")
				end
				if sli_stds.standardsIdentifier.is_initialized
					identifier = sli_stds.standardsIdentifier.get.to_s
					#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
				end
				if sli_stds.compositeFramingMaterial.is_initialized
					frame_mat = sli_stds.compositeFramingMaterial.get.to_s
					#runner.registerInfo("Structural Layer Framing Material = #{frame_mat}.")
				end
				if sli_stds.compositeFramingConfiguration.is_initialized
					frame_config = sli_stds.compositeFramingConfiguration.get.to_s
					#runner.registerInfo("Structural Layer Framing Config = #{frame_config}.")
				end
				if sli_stds.compositeFramingDepth.is_initialized
					frame_depth = sli_stds.compositeFramingDepth.get.to_s
					#runner.registerInfo("Structural Layer Framing Depth = #{frame_depth}.")
				end
				if sli_stds.compositeFramingSize.is_initialized
					frame_size = sli_stds.compositeFramingSize.get.to_s
					#runner.registerInfo("Structural Layer Framing Size = #{frame_size}.")
				end
				if sli_stds.compositeCavityInsulation.is_initialized
					cavity_ins = sli_stds.compositeCavityInsulation.get.to_i
					#runner.registerInfo("Structural Layer Cavity Insulation = #{cavity_ins}.")
				end
				
				# Find interior floor finishing product (if available). Similar to interior wall finish approach
				# Find interior layer for the construction to define the finish
				# Layers from exterior to interior
				frame_floor_covering = nil
				il_identifier = nil
				il_category = nil
				il_conductivity = nil
				il_thickness = nil
				
				layers.each_with_index do |layer, i|
					# Skip fenestration, partition, and airwall materials
					layer = layer.to_OpaqueMaterial
					next if layer.empty?
					int_layer = layer.get
					#runner.registerInfo("interior layer = #{int_layer}.")
					il_thickness = int_layer.thickness.to_s.to_f
					#runner.registerInfo("il thickness = #{il_thickness}.")
					il_conductivity = int_layer.thermalConductivity.to_s.to_f
					#runner.registerInfo("il conductivity = #{il_conductivity}.")

					il_i_stds = int_layer.standardsInformation
					if il_i_stds.standardsCategory.is_initialized
						il_category = il_i_stds.standardsCategory.get.to_s
						#runner.registerInfo("Interior Layer Category = #{il_category}.")
					end
					if il_i_stds.standardsIdentifier.is_initialized
						il_identifier = il_i_stds.standardsIdentifier.get.to_s
						#runner.registerInfo("Interior Layer Identifier = #{il_identifier}.")
					end
				end
				#runner.registerInfo("Interior Layer = #{il_identifier}.")		
				
				# Determine floor covering
				# Currently not requiring details on flooring. could leverage BEES.
				# Should add UNKNOWN to the enumerations.		
				if il_category.include?('Woods') or il_category.include?('Bldg Board and Siding')
					frame_floor_covering = 'HARDWOOD' # Assumes that any wood or plywood is for a hardwood floor. 			
				elsif il_category.include?('Finish Materials')
					il_identifier = il_identifier.downcase
					if il_identifier != nil
						if il_identifier.include?('carpet')
							frame_floor_covering = 'CARPET'
						elsif il_identifier.include?('linoleum')
							frame_floor_covering = 'VINYL' # groups Linoleum, Cork, and Vinyl together
						elsif il_identifier.include?('tile')
							frame_floor_covering = 'TILE' # groups all rubber, slate, and other tile together
						else
							frame_floor_covering = 'NONE_FRAME_FLOOR_COVERING' # terrazzo is grouped here. 
						end
					else
						frame_floor_covering = 'NONE_FRAME_FLOOR_COVERING'
					end
				else 
					frame_floor_covering = 'NONE_FRAME_FLOOR_COVERING'
					#runner.registerInfo("No Frame Floor Covering. Could we insulation layer.")
				end		
				#runner.registerInfo("Frame Floor Covering = #{frame_floor_covering}.")
				
				# Find the Floor Decking Type
				floor_decking_type = 'NONE' # Defaulted to None in case no decking is found.
				deck_identifier = nil
				deck_category = nil
				
				layers.each_with_index do |layer, i|
					# Skip fenestration, partition, and airwall materials
					next if floor_decking_type == 'OSB' or floor_decking_type == 'PLYWOOD'
					layer = layer.to_OpaqueMaterial
					next if layer.empty?
					deck_layer = layer.get
					deck_stds = deck_layer.standardsInformation
					next if not deck_stds.standardsIdentifier.is_initialized				
					deck_identifier = deck_stds.standardsIdentifier.get.to_s
					deck_identifier = deck_identifier.downcase
					#runner.registerInfo("Deck Layer Identifier = #{deck_identifier}.")
					if deck_identifier.include?('osb') or deck_identifier.include?('plywood')
						#runner.registerInfo("Deck Layer = #{deck_identifier}.")
						if deck_identifier.include?('osb')
							floor_decking_type = 'OSB'
						elsif deck_identifier.include?('plywood')
							floor_decking_type = 'PLYWOOD'
						else
							floor_decking_type = 'NONE'
						end					
					end
				end
				#runner.registerInfo("Frame Floor Decking = #{floor_decking_type}.")
				
				
				# Define the material for the joist/truss
				if category.to_s.include?('Wood Framed')
					frame_floor_material = 'WOOD'
				elsif category.to_s.include?('Metal Framed')
					frame_floor_material = 'METAL'
				else
					frame_floor_material = 'WOOD' #Defaults to wood; could add error message here.
				end
				
				# define On Center
				fc = frame_config.downcase
				#runner.registerInfo("OC = #{fc}.")
				on_center_in = /(\d+)/.match(frame_config).to_s.to_f
				#runner.registerInfo("OC = #{on_center_in}.")
				
				# define the framing size
				if frame_size == '2x4'
					studs_size = '_2X4'
				elsif frame_size == '2x6'
					studs_size = '_2X6'
				elsif frame_size == '2x8'
					studs_size = '_2X8'
				elsif frame_size == '2x10'
					studs_size = '_2X10'
				elsif frame_size == '2x12'
					studs_size = '_2X12'
				elsif frame_size == '2x14'
					studs_size = '_2X14'	
				else
					studs_size = 'OTHER_SIZE'
				end
				#runner.registerInfo("Studs Size = #{studs_size}.")
				
				# Define framing cavity thickness
				if frame_depth == '3_5In'
					cav_thickness = 3.5
				elsif frame_depth == '5_5In'
					cav_thickness = 5.5
				elsif frame_depth == '7_25In'
					cav_thickness = 7.25
				elsif frame_depth == '9_25In'
					cav_thickness = 9.25
				elsif frame_depth == '11_25In'
					cav_thickness = 11.25	
				else
					cav_thickness = nil
				end
				#runner.registerInfo("Cavity Thickness = #{cav_thickness}.")
				
				
				# Get all insulation in the frame floor construction.
				# Interior floors will typically not have insulation. 
				# Top and bottom floors may have insulation. It could be in the cavity and/or continuous rigid on the "outside".
				# For example, an unconditioned attic floor could have 6+ inches of batt or loose fill insulation.
				
				#Initialized insulations array.
				insulations = []
				cav_ins_mat = nil
				# Use the structural layer sandards information to get the cavity insulation, if any.
				# define the cavity insulation
				if cavity_ins.nil?
					cav_r_ip = 0
					ins_r_value_per_in = 0
				else
					cav_r_ip = cavity_ins
					#runner.registerInfo("Cavity R Value = #{cav_r_ip}.")
					if not cav_thickness.nil?
						ins_r_value_per_in = cav_r_ip / cav_thickness
					else
						ins_r_value_per_in = nil # If this occurs, there is something wrong.
					end
				end
				#runner.registerInfo("Cavity Insulation R is #{cav_r_ip}.") 
				#runner.registerInfo("Cavity Insulation R per Inch is #{ins_r_value_per_in}.")
				
				# Assume cavity insulation for wood or metal framing is either fiberglass batt or cellulose; are there others to include?
				if not ins_r_value_per_in.nil?
					if ins_r_value_per_in < 0.1
						cav_ins_mat = 'NONE'
					elsif ins_r_value_per_in < 3.6 and ins_r_value_per_in > 0.01
						cav_ins_mat = 'BATT_FIBERGLASS'
					else
						cav_ins_mat = 'LOOSE_FILL_CELLULOSE'
					end
				else
					cav_ins_mat = 'UNKNOWN'
				end
				#runner.registerInfo("Cavity Insulation is #{cav_ins_mat}.")
				
				if cav_r_ip > 0
					insulationCav = {
						'insulationMaterial' => cav_ins_mat,
						'insulationThickness' => cav_thickness,
						'insulationNominalRValue' => cav_r_ip,
						'insulationInstallationType' => 'CAVITY',
						'insulationLocation' => 'INTERIOR'
					}
					#runner.registerInfo("Cavity Insulation = #{insulationCav}")
					insulations << insulationCav
				end
				
				
				# Additional insulation either interior or exterior to the structural layer (composite framing layer, SIPs, CIFs, CLTs)
				# Use structural layer as base to find other insulation.
				
				# # Interior rigid insulation r-value
				# # Interior Rigid Insulation is very unlikely for an attic floor.
				# rigid_ins_int = const.rigid_insulation_values(sl_i, 'interior')
				# int_r = rigid_ins_int[0].to_s.to_f
				# int_t = rigid_ins_int[1].to_s.to_f
				# #This is an R Value, but we need to determine the material.
				# # Assumes "interior" insulation
				# if rigid_ins_int.nil?
					# int_r_ip = 0
					# interior_rigid_thickness = 0
					# ins_mat = 'NONE'
				# else
					# int_r_ip = int_r
					# interior_rigid_thickness = int_t
					# ins_r_value_per_in = int_r / int_t
					
					# if ins_r_value_per_in < 0.1
						# ins_mat = 'NONE'
					# elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
						# ins_mat = 'RIGID_EPS'
					# elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
						# ins_mat = 'RIGID_XPS'
					# elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
						# ins_mat = 'RIGID_POLYISOCYANURATE'
					# else
						# ins_mat = 'RIGID_UNKNOWN'
					# end
				# end
				# #runner.registerInfo("Insulation R is #{int_r_ip}.")
				# #runner.registerInfo("Insulation Type is #{ins_mat}.")
				# #runner.registerInfo("Insulation Thickness is #{interior_rigid_thickness}.")
				
				# if int_r_ip > 0
					# insulationInt = {
						# 'insulationMaterial' => ins_mat,
						# 'insulationThickness' => interior_rigid_thickness.round(1),
						# 'insulationNominalRValue' => int_r_ip.round(1),
						# 'insulationInstallationType' => 'CONTINUOUS',
						# 'insulationLocation' => 'INTERIOR'
					# }
					# #runner.registerInfo("Insulation = #{insulationInt}")
					# insulations << insulationInt
				# end
				
				
				# Exterior rigid insulation r-value		
				rigid_ins_ext = const.rigid_insulation_values(sl_i, 'exterior')
				#runner.registerInfo("Rigid Exterior Insulation = #{rigid_ins_ext}")
				
				ext_r = rigid_ins_ext[0].to_s.to_f
				ext_t = rigid_ins_ext[1].to_s.to_f
				
				#This is an R Value, but we need to determine the material.
				if rigid_ins_ext.nil?
					ext_r_ip = 0
					exterior_rigid_thickness = 0
				else
					ext_r_ip = ext_r
					exterior_rigid_thickness = ext_t
					ins_r_value_per_in = ext_r / ext_t
					
					if ins_r_value_per_in < 0.1
						ins_mat = 'NONE'
					elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
						ins_mat = 'RIGID_EPS'
					elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
						ins_mat = 'RIGID_XPS'
					elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
						ins_mat = 'RIGID_POLYISOCYANURATE'
					else
						ins_mat = 'RIGID_UNKNOWN'
					end
				end
				#runner.registerInfo("Insulation R is #{ext_r_ip}.")
				#runner.registerInfo("Insulation Type is #{ins_mat}.")
				#runner.registerInfo("Insulation Thickness is #{exterior_rigid_thickness}.")
				
				if ext_r_ip > 0
					insulationExt = {
						'insulationMaterial' => ins_mat,
						'insulationThickness' => exterior_rigid_thickness.round(1),
						'insulationNominalRValue' => ext_r_ip.round(1),
						'insulationInstallationType' => 'CONTINUOUS',
						'insulationLocation' => 'EXTERIOR'
					}
					#runner.registerInfo("Insulation = #{insulationExt}")
					insulations << insulationExt
				end
							
				
				# Determine if interior layer is actually insulation. This is missed by the current code.
				# This only catches one layer, the most interior layer. 
				# If there are multiple layers of batts, they need to be combined into a single layer.
				top_insulation = nil
				top_ins_type = nil
				top_ins_r = nil
				top_ins_thickness = nil
				
				#runner.registerInfo("Top Insulation Identifier is #{il_identifier}.")

				if il_identifier != nil and il_category.include?('Insulation')
					if il_identifier.include?('- 1/8 in.')
						top_ins_thickness = 0.125
					elsif il_identifier.include?('- 1/2 in.')
						top_ins_thickness = 0.25
					elsif il_identifier.include?('- 1/2 in.')
						top_ins_thickness = 0.5
					elsif il_identifier.include?('1 in.')
						top_ins_thickness = 1.0
					elsif il_identifier.include?('1 1/2 in.')
						top_ins_thickness = 1.5
					elsif il_identifier.include?('2 in.')	
						top_ins_thickness = 2.0	
					elsif il_identifier.include?('2 1/2 in.')	
						top_ins_thickness = 2.5
					elsif il_identifier.include?('3 in.')	
						top_ins_thickness = 3.0		
					elsif il_identifier.include?('3 1/2 in.')
						top_ins_thickness = 3.5
					elsif il_identifier.include?('4 in.')	
						top_ins_thickness = 4.0		
					elsif il_identifier.include?('4 1/2 in.')	
						top_ins_thickness = 4.5
					elsif il_identifier.include?('5 in.')	
						top_ins_thickness = 5.0		
					elsif il_identifier.include?('5 1/2 in.')
						top_ins_thickness = 5.5
					elsif il_identifier.include?('6 in.')	
						top_ins_thickness = 6.0		
					elsif il_identifier.include?('6 1/2 in.')	
						top_ins_thickness = 6.5
					elsif il_identifier.include?('7 in.')
						top_ins_thickness = 7.0
					elsif il_identifier.include?('7 1/4 in.')
						top_ins_thickness = 7.25	
					elsif il_identifier.include?('7 1/2 in.')
						top_ins_thickness = 7.5
					elsif il_identifier.include?('8 in.')	
						top_ins_thickness = 8.0
					elsif il_identifier.include?('8 1/4 in.')	
						top_ins_thickness = 8.25	
					elsif il_identifier.include?('8 1/2 in.')	
						top_ins_thickness = 8.5
					elsif il_identifier.include?('9 in.')	
						top_ins_thickness = 9.0		
					elsif il_identifier.include?('9 1/2 in.')
						top_ins_thickness = 9.5	
					elsif il_identifier.include?('10 in.')	
						top_ins_thickness = 10.0
					elsif il_identifier.include?('11 in.')	
						top_ins_thickness = 11.0
					elsif il_identifier.include?('12 in.')	
						top_ins_thickness = 12.0
					else
						top_ins_thickness = nil
					end
					#runner.registerInfo("Top Insulation Thickness is #{top_ins_thickness}.")
					
					if il_identifier.include?('R')
						top_ins_r_string =/R(\d+)/.match(il_identifier).to_s
						top_ins_r =/(\d+)/.match(top_ins_r_string).to_s.to_f
					else
						layer_conductivity = il_conductivity
						layer_thickness = il_thickness
						top_ins_r = layer_thickness / layer_conductivity * 5.678
					end
					#runner.registerInfo("Top Insulation R is #{top_ins_r}.")
					
				end
				#runner.registerInfo("Insulation thickness is #{top_ins_thickness}.")
				#runner.registerInfo("Insulation R is #{top_ins_r}.")
				
				if il_category.include?('Insulation Board') 
					#runner.registerInfo("Insulation board found on top of attic floor.")
					il_identifier = il_identifier.downcase
					if il_identifier != nil
						if il_identifier.include?('polyiso')
							top_insulation = 'RIGID_POLYISOCYANURATE'
						elsif il_identifier.include?('xps')
							top_insulation = 'RIGID_XPS' 
						elsif il_identifier.include?('EPS')
							top_insulation = 'RIGID_EPS'
						elsif il_identifier.include?('Polyurethane')
							top_insulation = 'SPRAY_FOAM_CLOSED_CELL'
						else
							top_insulation = 'RIGID_UNKNOWN'
						end
					else
						top_insulation = 'RIGID_UNKNOWN'
					end
				elsif il_category.include?('Insulation')
					#runner.registerInfo("Non-board Insulation found on top of attic floor.")
					il_identifier = il_identifier.downcase
					if il_identifier != nil
						if il_identifier.include?('loose fill')
							top_insulation = 'LOOSE_FILL_CELLULOSE'
						elsif il_identifier.include?('batt')
							top_insulation = 'BATT_FIBERGLASS' 
						elsif il_identifier.include?('spray')
							top_insulation = 'SPRAY_FOAM_CLOSED_CELL' 
						else
							top_insulation = 'UNKNOWN' 
						end
					else
						top_insulation = 'UNKNOWN'
					end
				else 
					top_insulation = nil
					runner.registerInfo("No Top Insulation.")
				end		
				#runner.registerInfo("Top Insulation is #{top_insulation}.")
				
				if top_insulation != nil
					insulationTop = {
						'insulationMaterial' => top_insulation,
						'insulationThickness' => top_ins_thickness.round(1),
						'insulationNominalRValue' => top_ins_r.round(1),
						'insulationInstallationType' => 'CONTINUOUS',
						'insulationLocation' => 'INTERIOR'				# Interior is on top of the attic floor framing.
					}
					#runner.registerInfo("Insulation = #{insulationTop}")
					insulations << insulationTop
				end
				
				# create floor joist/truss object
				floor_joist = nil
				floor_truss = nil
				
				if frame_floor_type == 'truss'
					floor_truss = {
						'floorTrussSpacing' => on_center_in,
						'floorTrussFramingFactor' => nil,
						'floorTrussSize' => studs_size,
						'floorTrussMaterial' => frame_floor_material
					}
				elsif frame_floor_type == 'joist'
					floor_joist = {
						'floorJoistSpacing' => on_center_in,
						'floorJoistFramingFactor' => nil,
						'floorJoistSize' => studs_size,
						'floorJoistMaterial' => frame_floor_material
					}
				else
					runner.registerInfo("Cannot find frame floor type. Check Construction and Material Measure Tags.")  
				end
				
				# Populate frame floor object
				atticFloor = {
				  'floorJoist' => floor_joist,
				  'floorTruss' => floor_truss,
				  'frameFloorInsulations' => insulations,
				  'frameFloorName' => floor_name,
				  'frameFloorArea' => area_ft2.round(1),
				  'frameFloorSpan' => floor_span_ft.round(1),
				  'frameFloorDeckingType' => floor_decking_type,
				  'frameFloorFloorCovering' => frame_floor_covering
				}
			  
				#runner.registerInfo("atticFloor = #{atticFloor}")
				atticFloors << atticFloor
				
				# Define the attic space insulation array.
				# Assumes the insulation is the same for all attic floor surfaces in a given space.
				attic_floor_insulations = insulations
				
			end	

		end	
		#runner.registerInfo("Attic Floor Area = #{attic_floor_area}.")
		#runner.registerInfo("Attic Roof Area = #{attic_roof_area}.")
		#runner.registerInfo("Attic Floor Span = #{attic_floor_span}.")
		#runner.registerInfo("Attic Roof Span = #{attic_roof_span}.")
		# NOTE: we could add an array of the floor and roof surface objects if desired.
		# NOTE: currently the floors are double counted. Need an alternative definition to call on.
		
		# determine if the space is an attic. If an attic, add the atticAndRoof object to the atticAndRoofs array.
		if 	not attic_name.nil? or not attic_roofs == []			
			#Populate the atticAndRoof surface object
			#runner.registerInfo("Creating Attic and Roof object.")
			atticAndRoof = {
				'atticAndRoofName' => attic_name,						# Use space name.
				'deckType' => attic_deck_type,							# get from roofs array (assumes a single type)
				'roofType' => attic_roof_type,							# get from roofs array (assumes a single type)
				'radiantBarrier' => attic_radiant_barrier,				# get from roofs array (assumes a single type)
				'roofArea' => attic_roof_area.round(2),					# sum of roof surfaces for the space
				'raftersSize' => attic_rafters_size,					# get from roofs array (assumes a single type)
				'raftersMaterials' => attic_rafters_mat,				# get from roofs array (assumes a single type)
				'pitch' => attic_pitch.round(1),						# get from roofs array (assumes a single type)
				'roofSpan' => attic_wall_span.round(2),					# use the width of the gable of the roof (via max attic wall span)
				'atticType' => attic_type,								# User defined
				'atticArea' => attic_floor_area.round(2),				# sum of area for floor surfaces for the attic space
				'atticLength' => attic_floor_span.round(2),				# use the longest axis of the zone
				'atticFloorInsulations'=> attic_floor_insulations,		# Get from floors array 
				'atticRoofInsulations'=> attic_roof_insulations,		# Get from roofs array
				'atticCeilingInsulations'=> attic_ceiling_insulations,	# Empty. This is in the roof insulation array.
				'skyLights' => attic_skylights							# all skylights subsurfaces in all roof surfaces
			}
			#runner.registerInfo("Attic/Roof = #{atticAndRoof}")
			#Add attic to attics array
			atticAndRoofs << atticAndRoof	
		end		
	end

	return atticAndRoofs
	
end