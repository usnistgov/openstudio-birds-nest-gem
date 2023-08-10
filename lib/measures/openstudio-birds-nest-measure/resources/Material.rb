# frozen_string_literal: true

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
    # Get the standards category
    stds = self.standardsInformation
    cat = stds.standardsCategory
    return nil if cat.empty?

    mat = cat.get

    # Convert enumerations
    if mat.include?('Batt')
      'Batt'
    elsif mat.include?('Board')
      'Board'
    elsif mat.include?('Loose')
      'LooseFill'
    elsif mat.include?('Spray')
      'SprayApplied'
    else
      'Other'
    end
  end

  # Determine the material that makes up the wall,
  # based on the standards category.
  #
  # @return [String] the wall material.
  # Possible values are nil, Wood, Metal, Concrete
  def nist_wall_material()
    # Removed from walls but stil used by fondation walls
    # Get the standards category
    stds = self.standardsInformation
    cat = stds.standardsCategory
    return nil if cat.empty?

    cat = cat.get.downcase

    # Determine the material added CLT as a structural layer option
    if cat.include?('metal')
      'Metal'
    elsif cat.include?('wood') || cat.include?('sips')
      'WoodWood'
    elsif cat.include?('concrete') || cat.include?('icf') || cat.include?('masonry')
      'MassConcrete'
    elsif cat.include?('clt')
      'CROSS_LAMINATED_TIMBER'
    end
  end

  # Determine the material that makes up the wall,
  # based on the standards category.
  #
  # @return [String] the wall material.
  # Possible values are nil, Wood, Metal, Concrete
  def nist_roof_material()
    # Get the standards category
    stds = self.standardsInformation
    cat = stds.standardsCategory
    return nil if cat.empty?

    cat = cat.get.downcase

    # Determine the material
    if cat.include?('metal') && cat.include?('frame')
      'Steel'
    elsif cat.include?('wood') && cat.include?('frame') || cat.include?('sips')
      'Wood'
    elsif cat.include?('concrete') || cat.include?('icf') || cat.include?('masonry')
      'IEAD'
    end
  end

  # Determine the stud spacing
  # based on the standards composite
  # framing configuration.
  #
  # @return [Double] the stud spacing, in inches.
  def nist_stud_spacing_inches()
    # Get the standards composite
    # framing configuration
    stds = self.standardsInformation
    fc = stds.compositeFramingConfiguration
    return nil if fc.empty?

    fc = fc.get.downcase

    # Parse out the stud spacing
    # from this: Wall16inOC or Roof16inOC
    match = /(\d+)inoc/.match(fc)
    return nil if match.nil?

    match[1].to_f
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
      thickness_in = OpenStudio.convert(thickness_m, 'm', 'in').get.to_i
    end

    # No Mass Materials
    if self.to_MasslessOpaqueMaterial.is_initialized
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

    thickness_in
  end

  # Determine the R-value of the cavity insulation
  # in a stud wall based on the standards composite
  # cavity insulation field
  #
  # @return [Double] the cavity R-value, in "ft^2*h*R/Btu" 
  def nist_cavity_insulation_r_value()
    # Get the standards composite
    # framing configuration
    stds = self.standardsInformation
    cav = stds.compositeCavityInsulation
    return nil if cav.empty?

    cav.get.to_f
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
    is_ins = true if cat.include?('insulation')

    # Only include opaque materials,
    # not partitions, airwalls, or fenestration.
    is_ins = false if self.to_OpaqueMaterial.empty?

    is_ins

  end

end
