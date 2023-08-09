# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Extend the OpenStudio class
class OpenStudio::Model::Material

  # Determine the enumeration for each material
  # in the ceiling construction.
  #
  # @return [String] the layer material.
  def nist_insulation_material()

    mat = nil

    # Get the standards category
    stds = self.standardsInformation
    cat = stds.standardsCategory
    return mat if cat.empty?
    mat = cat.get

    # Convert enumerations
    if mat.include?('Batt')
      mat = 'Batt'
    elsif mat.include?('Board')
      mat = 'Board'
    elsif mat.include?('Loose')
      mat = 'LooseFill'
    elsif mat.include?('Spray')
      mat = 'SprayApplied'
    else
      mat = 'Other'
    end

    return mat

  end

  # Determine the material that makes up the wall,
  # based on the standards category.
  #
  # @return [String] the wall material.
  # Possible values are nil, Wood, Metal, Concrete
  def nist_wall_material() # Removed from walls but stil used by fondation walls

    mat = nil

    # Get the standards category
    stds = self.standardsInformation
    cat = stds.standardsCategory
    return mat if cat.empty?
    cat = cat.get.downcase

    # Determine the material added CLT as a structural layer option
    if cat.include?('metal')
      mat = 'Metal'
    elsif cat.include?('wood') || cat.include?('sips')
      mat = 'WoodWood'
    elsif cat.include?('concrete') || cat.include?('icf') || cat.include?('masonry')
      mat = 'MassConcrete'
    elsif cat.include?('clt')
      mat = 'CROSS_LAMINATED_TIMBER'
	end

    return mat

  end  
  
  # Determine the material that makes up the wall,
  # based on the standards category.
  #
  # @return [String] the wall material.
  # Possible values are nil, Wood, Metal, Concrete
  def nist_roof_material()

    mat = nil

    # Get the standards category
    stds = self.standardsInformation
    cat = stds.standardsCategory
    return mat if cat.empty?
    cat = cat.get.downcase

    #Determine the material
    if cat.include?('metal') && cat.include?('frame')
      mat = 'Steel'
    elsif cat.include?('wood') && cat.include?('frame') || cat.include?('sips') 
      mat = 'Wood'
    elsif cat.include?('concrete') || cat.include?('icf') || cat.include?('masonry')
      mat = 'IEAD'
    end

    return mat

  end  


  # Determine the stud spacing
  # based on the standards composite
  # framing configuration.
  #
  # @return [Double] the stud spacing, in inches.
  def nist_stud_spacing_inches()

    spc_in = nil

    # Get the standards composite
    # framing configuration
    stds = self.standardsInformation
    fc = stds.compositeFramingConfiguration
    return spc_in if fc.empty?
    fc = fc.get.downcase

    # Parse out the stud spacing
    # from this: Wall16inOC or Roof16inOC
    match = /(\d+)inoc/.match(fc)
    return spc_in if match.nil?
    spc_in = match[1].to_f
    
    return spc_in

  end  
  
  # Determine the thickness of the structural
  # layer.  For standard opaque materials,
  # this is based on the actual layer thickness.
  # For no-mass materials, it is based on the
  # standards composite framing size field.
  #
  # @return [Integer] the thickness, in inches.
  def nist_thickness_inches()

    thickness_in = nil

    # Standard Opaque Materials
    if self.to_StandardOpaqueMaterial.is_initialized
      mat = self.to_StandardOpaqueMaterial.get
      thickness_m = mat.thickness
      thickness_in = OpenStudio.convert(thickness_m,'m','in').get.to_i
    end
    
    # No Mass Materials
    if self.to_MasslessOpaqueMaterial.is_initialized
      mat = self.to_MasslessOpaqueMaterial.get

      # Get the standards composite
      # framing configuration
      stds = self.standardsInformation
      fs = stds.compositeFramingSize
      return thickness_in if fs.empty?
      fs = fs.get.downcase

      # Parse out the stud spacing
      # from this: 2x4
      match = /x(\d+)/.match(fs)
      return thickness_in if match.nil?
      thickness_in = match[1].to_i
    
    end
    
    return thickness_in

  end
  
  # Determine the R-value of the cavity insulation
  # in a stud wall based on the standards composite
  # cavity insulation field
  #
  # @return [Double] the cavity R-value, in "ft^2*h*R/Btu" 
  def nist_cavity_insulation_r_value()

    r_ip = nil

    # Get the standards composite
    # framing configuration
    stds = self.standardsInformation
    cav = stds.compositeCavityInsulation
    return r_ip if cav.empty?
    r_ip = cav.get.to_f
    return r_ip
  end   
  
  
  
  # Determine if the layer is insulation, based
  # on the standards category.
  def nist_is_insulation()
     
    is_ins = false

    # Get the standards category
    stds = self.standardsInformation
    cat = stds.standardsCategory
    return is_ins if cat.empty?
    cat = cat.get.downcase

    # If category includes 'Insulation'
    if cat.include?('insulation')
      is_ins = true
    end
    
    # Only include opaque materials,
    # not partitions, airwalls, or fenestration.
    if self.to_OpaqueMaterial.empty?
      is_ins = false
    end
    
    return is_ins
  
  end
  
end