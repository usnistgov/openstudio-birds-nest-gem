# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

def build_frame_floors_array(idf, model, runner, user_arguments, sql)
	# Frame Floors are all floors except foundation floor.
	# TO DO: add an identifier for AttachedToSpace value. Only needed for attic right now.
	frameFloors = []
	model.getSurfaces.each do |surf|
		# Skip surfaces that aren't floors
		next unless surf.surfaceType == 'Floor' && surf.outsideBoundaryCondition != 'Ground'
		# Skip surfaces with no construction. 
		#Question: If there is no construction should we exclude it or assume basic internal design?
		const = surf.construction
		next if const.empty?
		const = const.get
		# Convert construction base to construction
		const = const.to_Construction.get
		#runner.registerInfo("Frame Floor Construction is #{const}.")  
		
		# Identify the name of the space for which the roof surface is attached to.
		space = surf.space.get
		floor_attached_to_space = space.name.to_s
		runner.registerInfo(" Floor surface attached to space #{floor_attached_to_space}.")
		
		# Get the area
		area_m2 = surf.netArea
		#runner.registerInfo("Floor Area is #{area_m2} m2.")  
		# Area (ft2)
		area_ft2 = OpenStudio.convert(area_m2, 'm^2','ft^2').get
		
		# find frame floor span
		# Currently finds the length and width of the floor
		# Assumes shorter of the 2 is the span for the joists/trusses
		floor_x_max = -1000000000
		floor_x_min = 1000000000
		floor_span_ft = nil
		#runner.registerInfo("finding foundation wall vertices.")
		vertices = surf.vertices
		#runner.registerInfo("found subsurface vertices.")
		vertices.each do |vertex|
			x = vertex.x
			if x < floor_x_min
				floor_x_min = x
			else next
			end
			if x > floor_x_max
				floor_x_max = x
			else
			end
		end
		#runner.registerInfo("found max and min z vertices.")
		floor_x_m = floor_x_max - floor_x_min
		#runner.registerInfo("floor x = #{floor_x_m}.")
		#Convert to IP
		floor_x_ft = OpenStudio.convert(floor_x_m, 'm','ft').get	
		floor_y_ft = area_ft2 / floor_x_ft	
		if floor_x_ft < floor_y_ft
			floor_span_ft = floor_x_ft
		else
			floor_span_ft = floor_y_ft
		end
		#runner.registerInfo("floor_span_ft = #{floor_span_ft}.")
		
		#Get Surface Name
		floor_name = surf.name.get
		#runner.registerInfo("Surface Name is #{floor_name}.")  
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
		on_center_in = /(\d+)/.match(frame_config).to_s.to_f
		#runner.registerInfo("OC = #{on_center_in}.")
		
		# define the framing size
		if frame_size == '2x2'
			studs_size = '_2X2'
		elsif frame_size == '2x3'
			studs_size = '_2X3'
		elsif frame_size == '2x4'
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
		
		# Define the cavity insulation material for wood framing
		# If user defines material in "identifier" then use that; If not then assume fiberglass batt
		if not ins_r_value_per_in.nil?
			if ins_r_value_per_in < 0.1
				ins_mat = 'NONE'
			elsif not identifier.nil?
				identifier = identifier.downcase
				if identifier.include?('glass')
					ins_mat = 'BATT_FIBERGLASS'
				elsif identifier.include?('cellulose')
					ins_mat = 'LOOSE_FILL_CELLULOSE'
				elsif identifier.include?('mineral') or identifier.include?('wool') or identifier.include?('rock')
					ins_mat = 'BATT_ROCKWOOL'
				elsif identifier.include?('spray') or identifier.include?('cell') or identifier.include?('foam')
					if ins_r_value_per_in < 5
						ins_mat = 'SPRAY_FOAM_OPEN_CELL'
					elsif ins_r_value_per_in > 5
						ins_mat = 'SPRAY_FOAM_CLOSED_CELL'
					else
						ins_mat = 'SPRAY_FOAM_UNKNOWN'
					end
				else
					ins_mat = 'BATT_FIBERGLASS'
				end	
			else
				ins_mat = 'BATT_FIBERGLASS'
			end
		else
			ins_mat = 'UNKNOWN'
		end
		#runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
		
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
		#runner.registerInfo("sl_i = #{sl_i}.")
		layers.each_with_index do |layer, i|
			# Skip fenestration, partition, and airwall materials
			ins_mat = nil
			ins_thickness = nil
			ins_r_val_ip = nil
			layer = layer.to_OpaqueMaterial
			next if layer.empty?
			layer = layer.get
			#runner.registerInfo("layer = #{layer}.")
			#if side == 'interior'
			# All layers inside (after) the structural layer
			#	next unless i > struct_layer_i
			if i != sl_i
				#runner.registerInfo("Layer is not Structural Layer. checking for insulation")
				if layer.nist_is_insulation
					# identify insulation material, thickness, and r-value using standard information
					ins_stds = layer.standardsInformation
					# If standard information is available, use to define insulation.
					if ins_stds.standardsCategory.is_initialized and ins_stds.standardsIdentifier.is_initialized
						ins_category = ins_stds.standardsCategory.get.to_s
						ins_category = ins_category.downcase
						ins_identifier = ins_stds.standardsIdentifier.get.to_s
						ins_identifier = ins_identifier.downcase
						#runner.registerInfo("Insulation Layer Category = #{ins_category}.")
						#runner.registerInfo("Insulation Layer Identifier = #{ins_identifier}.")
						
						# identify insulation thickness
						if ins_identifier != nil and ins_category.include?('insulation')
							if ins_identifier.include?('- 1/8 in.')
								ins_thickness = 0.125
							elsif ins_identifier.include?('- 1/4 in.')
								ins_thickness = 0.25
							elsif ins_identifier.include?('- 1/2 in.')
								ins_thickness = 0.5
							elsif ins_identifier.include?('1 in.')
								ins_thickness = 1.0
							elsif ins_identifier.include?('1 1/2 in.')
								ins_thickness = 1.5
							elsif ins_identifier.include?('2 in.')	
								ins_thickness = 2.0	
							elsif ins_identifier.include?('2 1/2 in.')	
								ins_thickness = 2.5
							elsif ins_identifier.include?('3 in.')	
								ins_thickness = 3.0		
							elsif ins_identifier.include?('3 1/2 in.')
								ins_thickness = 3.5
							elsif ins_identifier.include?('4 in.')	
								ins_thickness = 4.0		
							elsif ins_identifier.include?('4 1/2 in.')	
								ins_thickness = 4.5
							elsif ins_identifier.include?('5 in.')	
								ins_thickness = 5.0		
							elsif ins_identifier.include?('5 1/2 in.')
								ins_thickness = 5.5
							elsif ins_identifier.include?('6 in.')	
								ins_thickness = 6.0		
							elsif ins_identifier.include?('6 1/2 in.')	
								ins_thickness = 6.5
							elsif ins_identifier.include?('7 in.')
								ins_thickness = 7.0
							elsif ins_identifier.include?('7 1/4 in.')
								ins_thickness = 7.25	
							elsif ins_identifier.include?('7 1/2 in.')
								ins_thickness = 7.5
							elsif ins_identifier.include?('8 in.')	
								ins_thickness = 8.0
							elsif ins_identifier.include?('8 1/4 in.')	
								ins_thickness = 8.25	
							elsif ins_identifier.include?('8 1/2 in.')	
								ins_thickness = 8.5
							elsif ins_identifier.include?('9 in.')	
								ins_thickness = 9.0		
							elsif ins_identifier.include?('9 1/2 in.')
								ins_thickness = 9.5	
							elsif ins_identifier.include?('10 in.')	
								ins_thickness = 10.0
							elsif ins_identifier.include?('11 in.')	
								ins_thickness = 11.0
							elsif ins_identifier.include?('12 in.')	
								ins_thickness = 12.0
							else
								ins_thickness = nil
							end
							#runner.registerInfo("Insulation Thickness is #{ins_thickness}.")
						else
							ins_thickness = nil
							#runner.registerInfo("Insulation Thickness is missing.")
						end
						
						# identify insulation r-value
						if ins_identifier != nil and ins_identifier.include?('r')
							ins_r_string =/r(\d+)/.match(ins_identifier).to_s
							ins_r_val_ip =/(\d+)/.match(ins_r_string).to_s.to_f
						elsif ins_category.include?('spray')
							if ins_identifier.include?('urethane')
								if ins_identifier.include?('3.0 lb/ft3')
									ins_r_val_ip = ins_thickness * 6.3	
								elsif ins_identifier.include?('0.5 lb/ft3')
									ins_r_val_ip = ins_thickness * 3.7	
								end
							elsif ins_identifier.include?('cellulosic')
								ins_r_val_ip = ins_thickness * 3.7
							elsif ins_identifier.include?('glass')
								ins_r_val_ip = ins_thickness * 3.7
							end
						elsif not layer.thermalConductivity.nil? and not layer.thickness.nil?
							layer_conductivity = layer.thermalConductivity.to_s.to_f
							layer_thickness_m = layer.thickness.to_s.to_f
							ins_r_val_ip = layer_thickness_m / layer_conductivity * 5.678
						else
							ins_r_val_ip = nil
						end
						#runner.registerInfo("Insulation R is #{ins_r_val_ip}.")
						
						# identify insulation material
						if ins_category.include?('insulation board') 
							if ins_identifier != nil
								if ins_identifier.include?('polyiso')
									ins_mat = 'RIGID_POLYISOCYANURATE'
								elsif ins_identifier.include?('xps')
									ins_mat = 'RIGID_XPS' 
								elsif ins_identifier.include?('compliance')
									ins_mat = 'RIGID_XPS'
									ins_thickness = ins_r_val_ip / 5.0 # must define thickness for compliance insulation 
								elsif ins_identifier.include?('eps')
									ins_mat = 'RIGID_EPS'
								elsif ins_identifier.include?('urethane')
									ins_mat = 'SPRAY_FOAM_CLOSED_CELL'   # R-values for CBES materials match closed cell
								else
									ins_mat = 'RIGID_UNKNOWN'
								end
							else
								ins_mat = 'RIGID_UNKNOWN'
							end
						elsif ins_category.include?('insulation')
							#runner.registerInfo("Non-board Insulation found on top of attic floor.")
							ins_identifier = ins_identifier.downcase
							if ins_identifier != nil
								if ins_identifier.include?('loose fill')
									ins_mat = 'LOOSE_FILL_CELLULOSE'
								elsif ins_identifier.include?('cellulosic fiber')
									ins_mat = 'LOOSE_FILL_CELLULOSE'
								elsif ins_identifier.include?('batt')
									ins_mat = 'BATT_FIBERGLASS'
								elsif ins_identifier.include?('glass fiber')
									ins_mat = 'LOOSE_FILL_FIBERGLASS'	
								elsif ins_identifier.include?('spray') and ins_identifier.include?('4.6 lb/ft3')
									ins_mat = 'SPRAY_FOAM_CLOSED_CELL' 
								elsif ins_identifier.include?('spray') and ins_identifier.include?('3.0 lb/ft3')
									ins_mat = 'SPRAY_FOAM_CLOSED_CELL' 
								elsif ins_identifier.include?('spray') and ins_identifier.include?('0.5 lb/ft3')
									ins_mat = 'SPRAY_FOAM_OPEN_CELL' 	
								else
									ins_mat = 'UNKNOWN' 
								end
							else
								ins_mat = 'UNKNOWN'
							end
						else 
							ins_mat = nil
							#runner.registerInfo("No Insulation Material found.")
						end						
						#runner.registerInfo("Insulation Material is #{ins_mat}.")
					# If no standard information is available, use the layer performance specs (thickness and thermal resistance to match insulation material)
					# Currently only considers rigid insulation. 
					elsif not layer.thickness.nil? and not layer.thermalResistance.nil?
						ins_thickness_m = layer.thickness.to_f
						ins_thickness = OpenStudio.convert(ins_thickness_m, 'm','in').get
						ins_r_val_si = layer.thermalResistance.to_f
						ins_r_val_ip = OpenStudio.convert(r_val_si,"m^2*K/W","ft^2*h*R/Btu").get
						ins_r_value_per_in = ins_r_val_ip / ins_thickness
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
					# If a failure occurs above, then provide nil values.
					else
						ins_mat = nil
						ins_thickness = nil
						ins_r_val_ip = nil
						runner.registerInfo("No Insulation Material found.")
					end
					# Populate the correct insulation object (interior or exterior)
					#runner.registerInfo("Insulation Specs: #{ins_mat},#{ins_thickness},#{ins_r_val_ip}.")
					if i > sl_i
						# add interior insulation to insulations
						insulationInt = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => ins_thickness.round(1),
							'insulationNominalRValue' => ins_r_val_ip.round(1),
							'insulationInstallationType' => 'CONTINUOUS',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Insulation = #{insulationInt}")
						insulations << insulationInt
					elsif i < sl_i
						# add exterior insulation to insulations
						insulationExt = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => ins_thickness.round(1),
							'insulationNominalRValue' => ins_r_val_ip.round(1),
							'insulationInstallationType' => 'CONTINUOUS',
							'insulationLocation' => 'EXTERIOR'
						}
						#runner.registerInfo("Insulation = #{insulationExt}")
						insulations << insulationExt
					else
						runner.registerInfo("Layer was not added as Insulation.")
					end
				else
					#runner.registerInfo("Layer not insulation")
				end	
			end
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

		frameFloor = {
			  'floorJoist' => floor_joist,
			  'floorTruss' => floor_truss,
			  'frameFloorInsulations' => insulations,
			  'frameFloorName' => floor_name,
			  #'attachedToSpace' => floor_attached_to_space,
			  'frameFloorArea' => area_ft2.round(1),
			  'frameFloorSpan' => floor_span_ft.round(1),
			  'frameFloorDeckingType' => floor_decking_type,
			  'frameFloorFloorCovering' => frame_floor_covering
			}
		  
		#runner.registerInfo("frameFloor = #{frameFloor}")
		frameFloors << frameFloor
	end
	return frameFloors
end


def get_foundations(idf, model, runner, user_arguments, sql)
	
	# Perimeter insulation not available in the OSM model unless an E+ measure is used.
	# Can call on these values using the GroundHeatTransfer_Slab_InsulationFields Class
	# enum domain {RINS_Rvalueofunderslabinsulation, DINS_Widthofstripofunderslabinsulation, RVINS_Rvalueofverticalinsulation, ZVINS_Depthofverticalinsulation, IVINS_Flag_Isthereverticalinsulation}
	# Code requires R-0 or R-10, 2ft or R-10, 4ft vertical
	# Use "slab_r" from user inputs

	found_chars = runner.getStringArgumentValue('found_chars', user_arguments)
	#runner.registerInfo("User specified Foundation Characteristics: #{found_chars}.") 
	foundation_type_string, slab_r_string, extra = found_chars.split(', ')
	#runner.registerInfo("Split Characteristics: #{foundation_type_string}, #{slab_r_string}.")
	
	# Match user input to enumerations. Does not include all options (e.g., BASEMENT_FINISHED), but not necessary given current information needs.
	if foundation_type_string.to_s == 'Slab On/In Grade'
		foundation_type = 'SLAB_ON_GRADE'
	elsif foundation_type_string.to_s == 'Basement'
		foundation_type = 'BASEMENT_CONDITIONED'
	elsif foundation_type_string.to_s == 'Crawlspace'
		foundation_type = 'CRAWLSPACE_VENTED'
	else
		runner.registerInfo("Warning: Foundation was not matched to enumeration.")

	end
	
	#runner.registerInfo("Foundation Type: #{foundation_type}")
	#runner.registerInfo("R: #{slab_r_string}")
	
	# TO DO: Convert foundation type and whether a space is conditioned to set foundationType
	# Need to match to enumerations.
	
	if foundation_type == 'SLAB_ON_GRADE'
		slab_ins_r = /R-(\d+)/.match(slab_r_string).to_s
		slab_ins_ft = /(\d+)\sft/.match(slab_r_string).to_s
		#runner.registerInfo("Slab R: #{slab_ins_r}")
		#runner.registerInfo("Slab ft: #{slab_ins_ft}")
		slab_perimeter_r = /(\d+)/.match(slab_ins_r).to_s.to_f
		slab_perimeter_ft = /(\d+)/.match(slab_ins_ft).to_s.to_f
		#runner.registerInfo("Slab R: #{slab_perimeter_r}")
		#runner.registerInfo("Slab ft: #{slab_perimeter_ft}")
		perimeter_ins_thickness = slab_perimeter_r / 5.0 # Assume EPS for perimeter insulation		
		#runner.registerInfo("Slab perimeter insulation thickness: #{perimeter_ins_thickness}")
	else
		slab_perimeter_r = 0
		perimeter_ins_thickness = 0
		slab_perimeter_ft = 0
	end	
		
	foundations = []
	slab_under_slab_insulations = []
	slab_under_slab_perimeter_insulations = []
	slab_perimeter_insulations = []
	
	# Find only foundation floor surfaces - concrete only
	model.getSurfaces.each do |surf|
		# Skip surfaces that aren't floors
		next unless surf.surfaceType == 'Floor' && surf.outsideBoundaryCondition == 'Ground'
		# Skip surfaces with no construction. 
		#Get Surface Name
		foundation_name = surf.name.get
		# Get Construction
		const = surf.construction
		# Skip surfaces with no construction. 
		next if const.empty?
		const = const.get
		# Convert construction base to construction
		const = const.to_Construction.get
		#runner.registerInfo("Foundation Floor Construction is #{const}.")  

		# Find the structural mass layer. Same approach from foundation walls
		sl_i = const.found_structural_layer_index
		# Skip and warn if we can't find a structural layer
		if sl_i.nil?
			runner.registerInfo("Cannot find structural layer in foundation floor #{const.name}; this construction will not be included in the LCA calculations.  To ensure that the LCA calculations work, you must specify the Standards Information fields in the Construction and its constituent Materials.  Use the CEC2013 enumerations.")  
		next
		end
		
		# Identify the name of the space for which the roof surface is attached to.
		space = surf.space.get
		floor_attached_to_space = space.name.to_s
		#runner.registerInfo(" Floor surface attached to space #{floor_attached_to_space}.")
		
		# Get the area
		area_m2 = surf.netArea
		#runner.registerInfo("Foundation Floor Area is #{area_m2} m2.")  
		# Area (ft2)
		area_ft2 = OpenStudio.convert(area_m2, 'm^2','ft^2').get
		
		#find floor width and length
		floor_x_max = -1000000000
		floor_x_min = 1000000000
		floor_y_max = -1000000000
		floor_y_min = 1000000000
		#runner.registerInfo("finding foundation wall vertices.")
		vertices = surf.vertices
		#runner.registerInfo("found subsurface vertices.")
		vertices.each do |vertex|
			x = vertex.x
			if x < floor_x_min
				floor_x_min = x
			else next
			end
			if x > floor_x_max
				floor_x_max = x
			end
			y = vertex.y
			if y < floor_y_min
				floor_y_min = y
			else next
			end
			if y > floor_y_max
				floor_y_max = y
			end
		end
		floor_length_m = floor_x_max - floor_x_min
		#runner.registerInfo("floor length = #{floor_length_m}.")
		#Convert to IP
		found_floor_length_ft = OpenStudio.convert(floor_length_m, 'm','ft').get

		floor_width_m = floor_y_max - floor_y_min
		#runner.registerInfo("floor width = #{floor_width_m}.")
		#Convert to IP
		found_floor_width_ft = OpenStudio.convert(floor_width_m, 'm','ft').get
		
		perimeter_ft = found_floor_length_ft * 2 + found_floor_width_ft * 2
		
		# Confirm that the surface is a foundation floor. 
		# Check if the construction has measure tags. If so, then use those. Otherwise interpret the model.
		construction_stds = const.standardsInformation
		#runner.registerInfo("Construction Standards Information is #{construction_stds}.")  
		
		# Get the layers from the construction
		layers = const.layers
		# Find the structural mass layer. This is a function in construction.rb replicated from the structural layer index
		sl_i = const.found_structural_layer_index
		# Skip and warn if we can't find a structural layer
		if sl_i.nil?
			runner.registerInfo("Cannot find structural layer in wall construction #{const.name}; this construction will not be included in the LCA calculations.  To ensure that the LCA calculations work, you must specify the Standards Information fields in the Construction and its constituent Materials.  Use the CEC2013 enumerations.")  
		next
		end
		
		# Find interior floor finishing product (if available). Similar to interior wall finish approach
		# Find interior layer for the construction to define the finish
		# Layers from exterior to interior
		slab_floor_covering = nil
		il_identifier = nil
		il_category = nil
		
		layers.each_with_index do |layer, i|
			# Skip fenestration, partition, and airwall materials
			layer = layer.to_OpaqueMaterial
			next if layer.empty?
			layer = layer.get
			#runner.registerInfo("layer = #{layer}.")
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
		#runner.registerInfo("Interior Layer = #{il_identifier}.")		
		
		# Determine floor covering
		# Currently not requiring details on flooring. could leverage BEES.
		# Should add UNKNOWN to the enumerations.		
		if il_category.include?('Woods') or il_category.include?('Bldg Board and Siding')
			slab_floor_covering = 'HARDWOOD' # Assumes that any wood or plywood is for a hardwood floor. 			
		elsif il_category.include?('Finish Materials')
			il_identifier = il_identifier.downcase
			if il_identifier != nil
				if il_identifier.include?('carpet')
					slab_floor_covering = 'CARPET'
				elsif il_identifier.include?('linoleum')
					slab_floor_covering = 'VINYL' # groups Linoleum, Cork, and Vinyl together
				elsif il_identifier.include?('tile')
					slab_floor_covering = 'TILE' # groups all rubber, slate, and other tile together
				else
					slab_floor_covering = 'NONE' # terrazzo is grouped here. 
				end
			else
				slab_floor_covering = 'NONE'
			end
		else 
			slab_floor_covering = 'NONE'
		end		
		#runner.registerInfo("Slab Floor Covering = #{slab_floor_covering}.")
		
		
		#Find characteristics of the structural layer using Material Standard Information Measure Tags
		slab_thickness = nil
		
		sli_stds = layers[sl_i].standardsInformation
		
		if sli_stds.standardsCategory.is_initialized
			category = sli_stds.standardsCategory.get.to_s
			#runner.registerInfo("Structural Layer Category = #{category}.")
		end
		if sli_stds.standardsIdentifier.is_initialized
			identifier = sli_stds.standardsIdentifier.get.to_s
			#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
		end
		
		concrete_thickness =/(\d+)\sin/.match(identifier).to_s
		#runner.registerInfo("Concrete thickness string = #{concrete_thickness}.")
		if concrete_thickness == '2 in'
			slab_thickness = 2
		elsif concrete_thickness == '4 in'
			slab_thickness = 4	
		elsif concrete_thickness == '6 in'
			slab_thickness = 6		
		elsif concrete_thickness == '8 in'
			slab_thickness = 8
		elsif concrete_thickness == '10 in'
			slab_thickness = 10	
		elsif concrete_thickness == '12 in'
			slab_thickness = 12
		else
			slab_thickness = nil
		end
		#runner.registerInfo("Concrete Thickness = #{slab_thickness}.")

		#Find concrete strength and reinforcement from standards identifier
		#runner.registerInfo("Structural Layer Identifier = #{identifier}.")
		concrete_name = identifier.to_s
		#runner.registerInfo("Concrete Name = #{concrete_name}.")
		density =/(\d+)/.match(identifier).to_s.to_f
		#runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
		compressive_strength_value = 3750 # Defaulted to middle of typical concrete slabs on grade (3500 to 4000)
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
		
		# Match reinforcement to slab on grade foundation reinforcement.
		reinforcement = 'WELDED_WIRE_MESH' # Hard coded based on enumeration details.
	
		concrete_value = {
			'concreteName' => concrete_name,
			'compressiveStrength' => compressive_strength,
			'reinforcement' => reinforcement
		}
		#runner.registerInfo("Concrete value = #{concrete_value}")
		
		
		# Under the slab insulation
		# Use structural layer as base to find other insulation.
		# Uses the same approach as exterior wall insulation
	
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
			slab_under_slab_insulations << insulationExt
		end	
		
		if slab_perimeter_r > 0
			slab_under_slab_perimeter_insulations = [{
				'insulationMaterial': 'RIGID_EPS',
				'insulationThickness': perimeter_ins_thickness,
				'insulationNominalRValue': slab_perimeter_r,
				'insulationInstallationType': 'CONTINUOUS',
				'insulationLocation': 'EXTERIOR'
			}]
			slab_perimeter_insulations = [{
				'insulationMaterial': 'RIGID_EPS',
				'insulationThickness': perimeter_ins_thickness,
				'insulationNominalRValue': slab_perimeter_r,
				'insulationInstallationType': 'CONTINUOUS',
				'insulationLocation': 'EXTERIOR'
			}]
		end
		
		slab = {
			'slabPerimeterInsulations' => slab_perimeter_insulations,						# perimeter of zone
			'slabUnderSlabPerimeterInsulations' => slab_under_slab_perimeter_insulations,	# 
			'slabName' => foundation_name,
			#'attachedToSpace' => floor_attached_to_space,
			'slabArea' => area_ft2.round(1),
			'slabThickness' => slab_thickness,
			'slabPerimeter'=> perimeter_ft.round(1),
			'slabPerimeterInsulationDepth'=> slab_perimeter_ft, # Defaulted to user input.
			'slabUnderSlabInsulationWidth'=> 0, # Defaulted to 0 ft.
			'slabFloorCovering'=> slab_floor_covering,
			'slabUnderSlabInsulations'=> slab_under_slab_insulations,
			'concreteValue'=> concrete_value
		}
		#runner.registerInfo("Slab Object = #{slab}")
		
		foundation = {
			'foundationType' => foundation_type,		# Foundation type is identified in summary characteristics; 
			'slab' => slab,								# slab will be empty if its a crawlspace
			'foundationName'=> foundation_name			# foundation name will be empty if its a crawlspace
		}
		#runner.registerInfo("Foundation Object = #{foundation}")
		foundations << foundation
	end
	# Let the user know if no foundation is found.
	if foundations == []
		runner.registerInfo("No Foundation Objects. The building foundation type is #{foundation_type}.")
	end
	return foundations
end


def build_frame_floors_minus_slab_and_attic_array(idf, model, runner, user_arguments, sql)
	# Frame Floors are all floors except foundation floor. This version removes attic floors as well.
	# TO DO: add an identifier for AttachedToSpace value. Only needed for attic right now.
	frameFloors = []
	
	model.getSurfaces.each do |surf|
		# Skip surfaces that aren't floors
		next unless surf.surfaceType == 'Floor' && surf.outsideBoundaryCondition != 'Ground'
		# Skip surfaces with no construction. 
		#Question: If there is no construction should we exclude it or assume basic internal design?
		const = surf.construction
		next if const.empty?
		const = const.get
		# Convert construction base to construction
		const = const.to_Construction.get
		#runner.registerInfo("Frame Floor Construction is #{const}.")  
		
		# define construction standards to be used as a filtering mechanism
		construction_stds = const.standardsInformation
		#runner.registerInfo("Construction Standards Information is #{construction_stds}.") 
		
		# Skip if the surface is an attic floor
		next if construction_stds.intendedSurfaceType.to_s.include?('AtticFloor')
		
		# Get the area
		area_m2 = surf.netArea
		#runner.registerInfo("Floor Area is #{area_m2} m2.")  
		# Area (ft2)
		area_ft2 = OpenStudio.convert(area_m2, 'm^2','ft^2').get
		
		# Identify the name of the space for which the roof surface is attached to.
		space = surf.space.get
		floor_attached_to_space = space.name.to_s
		#runner.registerInfo(" Floor surface attached to space #{floor_attached_to_space}.")
		
		
		# find frame floor span
		# Currently finds the length and width of the floor
		# Assumes shorter of the 2 is the span for the joists/trusses
		floor_x_max = -1000000000
		floor_x_min = 1000000000
		floor_span_ft = nil
		#runner.registerInfo("finding foundation wall vertices.")
		vertices = surf.vertices
		#runner.registerInfo("found subsurface vertices.")
		vertices.each do |vertex|
			x = vertex.x
			if x < floor_x_min
				floor_x_min = x
			else next
			end
			if x > floor_x_max
				floor_x_max = x
			else
			end
		end
		#runner.registerInfo("found max and min z vertices.")
		floor_x_m = floor_x_max - floor_x_min
		#runner.registerInfo("floor x = #{floor_x_m}.")
		#Convert to IP
		floor_x_ft = OpenStudio.convert(floor_x_m, 'm','ft').get	
		floor_y_ft = area_ft2 / floor_x_ft	
		if floor_x_ft < floor_y_ft
			floor_span_ft = floor_x_ft
		else
			floor_span_ft = floor_y_ft
		end
		#runner.registerInfo("floor_span_ft = #{floor_span_ft}.")
		
		#Get Surface Name
		floor_name = surf.name.get
		#runner.registerInfo("Surface Name is #{floor_name}.")  
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
		# Ignores other structural layer options (CLT, SIPs, ICFs)
		if category.to_s.include?('Wood Framed')
			frame_floor_material = 'WOOD'
		elsif category.to_s.include?('Metal Framed')
			frame_floor_material = 'METAL'
		else
			frame_floor_material = 'WOOD' #Defaults to wood; could add error message here.
		end
		
		# define On Center
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
				'insulationMaterial' => cav_ins_mat,
				'insulationThickness' => cav_thickness,
				'insulationNominalRValue' => cav_r_ip.round(1),
				'insulationInstallationType' => 'CAVITY',
				'insulationLocation' => 'INTERIOR'
			}
			#runner.registerInfo("Cavity Insulation = #{insulationCav}")
			insulations << insulationCav
		end
		
# Additional insulation either interior or exterior to the structural layer (composite framing layer, SIPs, CIFs, CLTs)
		# Use structural layer as base to find other insulation.
		#runner.registerInfo("sl_i = #{sl_i}.")
		layers.each_with_index do |layer, i|
			# Skip fenestration, partition, and airwall materials
			ins_mat = nil
			ins_thickness = nil
			ins_r_val_ip = nil
			layer = layer.to_OpaqueMaterial
			next if layer.empty?
			layer = layer.get
			#runner.registerInfo("layer = #{layer}.")
			#if side == 'interior'
			# All layers inside (after) the structural layer
			#	next unless i > struct_layer_i
			if i != sl_i
				#runner.registerInfo("Layer is not Structural Layer. checking for insulation")
				if layer.nist_is_insulation
					# identify insulation material, thickness, and r-value using standard information
					ins_stds = layer.standardsInformation
					# If standard information is available, use to define insulation.
					if ins_stds.standardsCategory.is_initialized and ins_stds.standardsIdentifier.is_initialized
						ins_category = ins_stds.standardsCategory.get.to_s
						ins_category = ins_category.downcase
						ins_identifier = ins_stds.standardsIdentifier.get.to_s
						ins_identifier = ins_identifier.downcase
						#runner.registerInfo("Insulation Layer Category = #{ins_category}.")
						#runner.registerInfo("Insulation Layer Identifier = #{ins_identifier}.")
						
						# identify insulation thickness
						if ins_identifier != nil and ins_category.include?('insulation')
							if ins_identifier.include?('- 1/8 in.')
								ins_thickness = 0.125
							elsif ins_identifier.include?('- 1/4 in.')
								ins_thickness = 0.25
							elsif ins_identifier.include?('- 1/2 in.')
								ins_thickness = 0.5
							elsif ins_identifier.include?('1 in.')
								ins_thickness = 1.0
							elsif ins_identifier.include?('1 1/2 in.')
								ins_thickness = 1.5
							elsif ins_identifier.include?('2 in.')	
								ins_thickness = 2.0	
							elsif ins_identifier.include?('2 1/2 in.')	
								ins_thickness = 2.5
							elsif ins_identifier.include?('3 in.')	
								ins_thickness = 3.0		
							elsif ins_identifier.include?('3 1/2 in.')
								ins_thickness = 3.5
							elsif ins_identifier.include?('4 in.')	
								ins_thickness = 4.0		
							elsif ins_identifier.include?('4 1/2 in.')	
								ins_thickness = 4.5
							elsif ins_identifier.include?('5 in.')	
								ins_thickness = 5.0		
							elsif ins_identifier.include?('5 1/2 in.')
								ins_thickness = 5.5
							elsif ins_identifier.include?('6 in.')	
								ins_thickness = 6.0		
							elsif ins_identifier.include?('6 1/2 in.')	
								ins_thickness = 6.5
							elsif ins_identifier.include?('7 in.')
								ins_thickness = 7.0
							elsif ins_identifier.include?('7 1/4 in.')
								ins_thickness = 7.25	
							elsif ins_identifier.include?('7 1/2 in.')
								ins_thickness = 7.5
							elsif ins_identifier.include?('8 in.')	
								ins_thickness = 8.0
							elsif ins_identifier.include?('8 1/4 in.')	
								ins_thickness = 8.25	
							elsif ins_identifier.include?('8 1/2 in.')	
								ins_thickness = 8.5
							elsif ins_identifier.include?('9 in.')	
								ins_thickness = 9.0		
							elsif ins_identifier.include?('9 1/2 in.')
								ins_thickness = 9.5	
							elsif ins_identifier.include?('10 in.')	
								ins_thickness = 10.0
							elsif ins_identifier.include?('11 in.')	
								ins_thickness = 11.0
							elsif ins_identifier.include?('12 in.')	
								ins_thickness = 12.0
							else
								ins_thickness = nil
							end
							#runner.registerInfo("Insulation Thickness is #{ins_thickness}.")
						else
							ins_thickness = nil
							#runner.registerInfo("Insulation Thickness is missing.")
						end
						
						# identify insulation r-value
						if ins_identifier != nil and ins_identifier.include?('r')
							ins_r_string =/r(\d+)/.match(ins_identifier).to_s
							ins_r_val_ip =/(\d+)/.match(ins_r_string).to_s.to_f
						elsif ins_category.include?('spray')
							if ins_identifier.include?('urethane')
								if ins_identifier.include?('3.0 lb/ft3')
									ins_r_val_ip = ins_thickness * 6.3	
								elsif ins_identifier.include?('0.5 lb/ft3')
									ins_r_val_ip = ins_thickness * 3.7	
								end
							elsif ins_identifier.include?('cellulosic')
								ins_r_val_ip = ins_thickness * 3.7
							elsif ins_identifier.include?('glass')
								ins_r_val_ip = ins_thickness * 3.7
							end
						elsif not layer.thermalConductivity.nil? and not layer.thickness.nil?
							layer_conductivity = layer.thermalConductivity.to_s.to_f
							layer_thickness_m = layer.thickness.to_s.to_f
							ins_r_val_ip = layer_thickness_m / layer_conductivity * 5.678
						else
							ins_r_val_ip = nil
						end
						#runner.registerInfo("Insulation R is #{ins_r_val_ip}.")
						
						# identify insulation material
						if ins_category.include?('insulation board') 
							if ins_identifier != nil
								if ins_identifier.include?('polyiso')
									ins_mat = 'RIGID_POLYISOCYANURATE'
								elsif ins_identifier.include?('xps')
									ins_mat = 'RIGID_XPS' 
								elsif ins_identifier.include?('compliance')
									ins_mat = 'RIGID_XPS'
									ins_thickness = ins_r_val_ip / 5.0 # must define thickness for compliance insulation 
								elsif ins_identifier.include?('eps')
									ins_mat = 'RIGID_EPS'
								elsif ins_identifier.include?('urethane')
									ins_mat = 'SPRAY_FOAM_CLOSED_CELL'   # R-values for CBES materials match closed cell
								else
									ins_mat = 'RIGID_UNKNOWN'
								end
							else
								ins_mat = 'RIGID_UNKNOWN'
							end
						elsif ins_category.include?('insulation')
							#runner.registerInfo("Non-board Insulation found on top of attic floor.")
							ins_identifier = ins_identifier.downcase
							if ins_identifier != nil
								if ins_identifier.include?('loose fill')
									ins_mat = 'LOOSE_FILL_CELLULOSE'
								elsif ins_identifier.include?('cellulosic fiber')
									ins_mat = 'LOOSE_FILL_CELLULOSE'
								elsif ins_identifier.include?('batt')
									ins_mat = 'BATT_FIBERGLASS'
								elsif ins_identifier.include?('glass fiber')
									ins_mat = 'LOOSE_FILL_FIBERGLASS'	
								elsif ins_identifier.include?('spray') and ins_identifier.include?('4.6 lb/ft3')
									ins_mat = 'SPRAY_FOAM_CLOSED_CELL' 
								elsif ins_identifier.include?('spray') and ins_identifier.include?('3.0 lb/ft3')
									ins_mat = 'SPRAY_FOAM_CLOSED_CELL' 
								elsif ins_identifier.include?('spray') and ins_identifier.include?('0.5 lb/ft3')
									ins_mat = 'SPRAY_FOAM_OPEN_CELL' 	
								else
									ins_mat = 'UNKNOWN' 
								end
							else
								ins_mat = 'UNKNOWN'
							end
						else 
							ins_mat = nil
							#runner.registerInfo("No Insulation Material found.")
						end						
						#runner.registerInfo("Insulation Material is #{ins_mat}.")
					# If no standard information is available, use the layer performance specs (thickness and thermal resistance to match insulation material)
					# Currently only considers rigid insulation. 
					elsif not layer.thickness.nil? and not layer.thermalResistance.nil?
						ins_thickness_m = layer.thickness.to_f
						ins_thickness = OpenStudio.convert(ins_thickness_m, 'm','in').get
						ins_r_val_si = layer.thermalResistance.to_f
						ins_r_val_ip = OpenStudio.convert(r_val_si,"m^2*K/W","ft^2*h*R/Btu").get
						ins_r_value_per_in = ins_r_val_ip / ins_thickness
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
					# If a failure occurs above, then provide nil values.
					else
						ins_mat = nil
						ins_thickness = nil
						ins_r_val_ip = nil
						#runner.registerInfo("No Insulation Material found.")
					end
					# Populate the correct insulation object (interior or exterior)
					#runner.registerInfo("Insulation Specs: #{ins_mat},#{ins_thickness},#{ins_r_val_ip}.")
					if i > sl_i
						# add interior insulation to insulations
						insulationInt = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => ins_thickness.round(1),
							'insulationNominalRValue' => ins_r_val_ip.round(1),
							'insulationInstallationType' => 'CONTINUOUS',
							'insulationLocation' => 'INTERIOR'
						}
						#runner.registerInfo("Insulation = #{insulationInt}")
						insulations << insulationInt
					elsif i < sl_i
						# add exterior insulation to insulations
						insulationExt = {
							'insulationMaterial' => ins_mat,
							'insulationThickness' => ins_thickness.round(1),
							'insulationNominalRValue' => ins_r_val_ip.round(1),
							'insulationInstallationType' => 'CONTINUOUS',
							'insulationLocation' => 'EXTERIOR'
						}
						#runner.registerInfo("Insulation = #{insulationExt}")
						insulations << insulationExt
					else
						#runner.registerInfo("Layer was not added as Insulation.")
					end
				else
					#runner.registerInfo("Layer not insulation")
				end	
			end
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

		frameFloor = {
			  'frameFloorName' => floor_name,
			  #'attachedToSpace' => floor_attached_to_space,
			  'frameFloorArea' => area_ft2.round(1),
			  'frameFloorSpan' => floor_span_ft.round(1),
			  'frameFloorDeckingType' => floor_decking_type,
			  'frameFloorFloorCovering' => frame_floor_covering,
			  'floorJoist' => floor_joist,
			  'floorTruss' => floor_truss,
			  'frameFloorInsulations' => insulations
			}
		  
		#runner.registerInfo("frameFloor = #{frameFloor}")
		frameFloors << frameFloor
	end
	return frameFloors
end