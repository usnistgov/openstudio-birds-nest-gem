# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

def define_arguments()

    args = OpenStudio::Measure::OSArgumentVector.new

    # Make a temporary string argument for IP address. This allows for us to correctly hit the BIRDS NEST server.
    # Remove before publishing as this should be hard coded to the BIRDS NEST server.
    # birds_ip_address = OpenStudio::Measure::OSArgument::makeStringArgument('birds_ip_address', true)
    # birds_ip_address.setDisplayName('BIRDS server IP address')
    # birds_ip_address.setDefaultValue('129.6.70.60')    # Tzong Hao provides this IP address
    # args << birds_ip_address

    # Make a temporary string argument for port.
    # Remove before publishing as this should be hard coded to the BIRDS NEST server.
    # birds_port = OpenStudio::Measure::OSArgument::makeStringArgument('birds_port', true)
    # birds_port.setDisplayName('BIRDS server port')
    # birds_port.setDefaultValue('2473')					# Tzong Hao provides this Port.
    # args << birds_port

	# User must provide their specific API key
	# Keys can be obtained by contacting NIST (Joshua Kneifel at joshua.kneifel@nist.gov)
	birds_api_key = OpenStudio::Measure::OSArgument::makeStringArgument('birds_api_key', true)
    birds_api_key.setDisplayName('BIRDS NEST API Access Token')
    birds_api_key.setDefaultValue('')					# Defaulted to blank to limit to only users with their own key.
    args << birds_api_key

    birds_api_key = OpenStudio::Measure::OSArgument::makeStringArgument('api_url', true)
    birds_api_key.setDisplayName('BIRDS API URL')
    birds_api_key.setDefaultValue('https://birdsnest.nist.gov/api/lcia/')
    args << birds_api_key

    birds_api_key = OpenStudio::Measure::OSArgument::makeStringArgument('birds_api_refresh_token', true)
    birds_api_key.setDisplayName('BIRDS NEST API Refresh Token')
    birds_api_key.setDefaultValue('')
    args << birds_api_key

    birds_api_key = OpenStudio::Measure::OSArgument::makeStringArgument('api_refresh_url', true)
    birds_api_key.setDisplayName('BIRDS API Token Refresh URL')
    birds_api_key.setDefaultValue('https://birdsnest.nist.gov/api/token/refresh/')
    args << birds_api_key

    # Make a choice argument for commercial vs residential building type. Everything is commented out except low rise residential because that is the only option.
    com_res_chs = OpenStudio::StringVector.new
    # com_res_chs << 'Commercial'
    com_res_chs << 'LowRiseResidential'
    # com_res_chs << 'NonLowRiseResidential'
    com_res = OpenStudio::Measure::OSArgument::makeChoiceArgument('com_res', com_res_chs, true)
    com_res.setDisplayName('Commercial or Residential Building')
    com_res.setDefaultValue('LowRiseResidential')
    args << com_res

    # Make a choice argument for building type. Limit to single family options for now.
    bldg_type_chs = OpenStudio::StringVector.new
    #bldg_type_chs << 'SingleFamilyAttached'
    bldg_type_chs << 'SingleFamilyDetached'
    #bldg_type_chs << 'MultiFamily'
    bldg_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('bldg_type', bldg_type_chs, true)
    bldg_type.setDisplayName('Building Type')
    bldg_type.setDefaultValue('SingleFamilyDetached')
    args << bldg_type

    # Make a choice argument for construction quality. This cannot be provided by OS model and must be user defined.
    const_qual_chs = OpenStudio::StringVector.new
    const_qual_chs << 'Average'
    const_qual_chs << 'Custom'
    const_qual_chs << 'Luxury'
    const_qual = OpenStudio::Measure::OSArgument::makeChoiceArgument('const_qual', const_qual_chs, true)
    const_qual.setDisplayName('Construction Quality')
    const_qual.setDefaultValue('Average')
    args << const_qual

    # # Make a string argument for state city. We could eventually provide a more complete list in the future.
    # state_city_chs = OpenStudio::StringVector.new
    # state_city_chs << 'AK - Anchorage'
    # state_city_chs << 'AK - Barrow'
    # state_city_chs << 'AK - Fairbanks'
    # state_city_chs << 'AK - Juneau'
    # state_city_chs << 'AK - Kodiak'
    # state_city_chs << 'AK - Nome'
    # state_city_chs << 'AL - Birmingham'
    # state_city_chs << 'AL - Huntsville'
    # state_city_chs << 'AL - Mobile'
    # state_city_chs << 'AL - Montgomery'
    # state_city_chs << 'AR - Fort Smith'
    # state_city_chs << 'AR - Little Rock'
    # state_city_chs << 'AZ - Flagstaff'
    # state_city_chs << 'AZ - Phoenix'
    # state_city_chs << 'AZ - Prescott'
    # state_city_chs << 'AZ - Tucson'
    # state_city_chs << 'AZ - Winslow'
    # state_city_chs << 'AZ - Yuma'
    # state_city_chs << 'CA - Arcata'
    # state_city_chs << 'CA - Bakersfield'
    # state_city_chs << 'CA - Daggett'
    # state_city_chs << 'CA - Fresno'
    # state_city_chs << 'CA - Long Beach'
    # state_city_chs << 'CA - Los Angeles'
    # state_city_chs << 'CA - Riverside'
    # state_city_chs << 'CA - Sacramento'
    # state_city_chs << 'CA - San Diego'
    # state_city_chs << 'CA - San Francisco'
    # state_city_chs << 'CA - Santa Maria'
    # state_city_chs << 'CO - Alamosa'
    # state_city_chs << 'CO - Boulder'
    # state_city_chs << 'CO - Colorado Springs'
    # state_city_chs << 'CO - Eagle'
    # state_city_chs << 'CO - Grand Junction'
    # state_city_chs << 'CO - Pueblo'
    # state_city_chs << 'CT - Bridgeport'
    # state_city_chs << 'CT - Hartford'
    # state_city_chs << 'DC - Washington'
    # state_city_chs << 'DE - Wilmington'
    # state_city_chs << 'FL - Daytona Beach'
    # state_city_chs << 'FL - Jacksonville'
    # state_city_chs << 'FL - Key West'
    # state_city_chs << 'FL - Miami'
    # state_city_chs << 'FL - Tallahassee'
    # state_city_chs << 'FL - Tampa'
    # state_city_chs << 'FL - West Palm Beach'
    # state_city_chs << 'GA - Athens'
    # state_city_chs << 'GA - Atlanta'
    # state_city_chs << 'GA - Augusta'
    # state_city_chs << 'GA - Columbus'
    # state_city_chs << 'GA - Macon'
    # state_city_chs << 'GA - Savannah'
    # state_city_chs << 'HI - Hilo'
    # state_city_chs << 'HI - Honolulu'
    # state_city_chs << 'IA - Burlington'
    # state_city_chs << 'IA - Des Moines'
    # state_city_chs << 'IA - Mason City'
    # state_city_chs << 'IA - Sioux City'
    # state_city_chs << 'IA - Waterloo'
    # state_city_chs << 'ID - Boise'
    # state_city_chs << 'ID - Lewiston'
    # state_city_chs << 'ID - Pocatello'
    # state_city_chs << 'IL - Chicago'
    # state_city_chs << 'IL - Moline'
    # state_city_chs << 'IL - Peoria'
    # state_city_chs << 'IL - Rockford'
    # state_city_chs << 'IL - Springfield'
    # state_city_chs << 'IN - Evansville'
    # state_city_chs << 'IN - Fort Wayne'
    # state_city_chs << 'IN - Indianapolis'
    # state_city_chs << 'IN - South Bend'
    # state_city_chs << 'KS - Dodge City'
    # state_city_chs << 'KS - Goodland'
    # state_city_chs << 'KS - Topeka'
    # state_city_chs << 'KS - Wichita'
    # state_city_chs << 'KY - Covington'
    # state_city_chs << 'KY - Lexington'
    # state_city_chs << 'KY - Louisville'
    # state_city_chs << 'LA - Baton Rouge'
    # state_city_chs << 'LA - Lake Charles'
    # state_city_chs << 'LA - New Orleans'
    # state_city_chs << 'LA - Shreveport'
    # state_city_chs << 'MA - Boston'
    # state_city_chs << 'MA - Worcester'
    # state_city_chs << 'MD - Baltimore'
    # state_city_chs << 'ME - Caribou'
    # state_city_chs << 'ME - Portland'
    # state_city_chs << 'MI - Alpena'
    # state_city_chs << 'MI - Detroit'
    # state_city_chs << 'MI - Flint'
    # state_city_chs << 'MI - Grand Rapids'
    # state_city_chs << 'MI - Houghton'
    # state_city_chs << 'MI - Lansing'
    # state_city_chs << 'MI - Muskegon'
    # state_city_chs << 'MI - Sault Ste Marie'
    # state_city_chs << 'MI - Traverse City'
    # state_city_chs << 'MN - Duluth'
    # state_city_chs << 'MN - International Falls'
    # state_city_chs << 'MN - Minneapolis'
    # state_city_chs << 'MN - Rochester'
    # state_city_chs << 'MN - Saint Cloud'
    # state_city_chs << 'MO - Columbia'
    # state_city_chs << 'MO - Kansas City'
    # state_city_chs << 'MO - St Louis'
    # state_city_chs << 'MO - Springfield'
    # state_city_chs << 'MS - Jackson'
    # state_city_chs << 'MS - Meridian'
    # state_city_chs << 'MT - Billings'
    # state_city_chs << 'MT - Cut Bank'
    # state_city_chs << 'MT - Glasgow'
    # state_city_chs << 'MT - Great Falls'
    # state_city_chs << 'MT - Helena'
    # state_city_chs << 'MT - Kalispell'
    # state_city_chs << 'MT - Lewistown'
    # state_city_chs << 'MT - Miles City'
    # state_city_chs << 'MT - Missoula'
    # state_city_chs << 'NC - Asheville'
    # state_city_chs << 'NC - Charlotte'
    # state_city_chs << 'NC - Greensboro'
    # state_city_chs << 'NC - Cape Hatteras'
    # state_city_chs << 'NC - Raleigh'
    # state_city_chs << 'NC - Wilmington'
    # state_city_chs << 'ND - Bismarck'
    # state_city_chs << 'ND - Fargo'
    # state_city_chs << 'ND - Minot'
    # state_city_chs << 'NE - Grand Island'
    # state_city_chs << 'NE - Norfolk'
    # state_city_chs << 'NE - North Platte'
    # state_city_chs << 'NE - Omaha'
    # state_city_chs << 'NE - Scottsbluff'
    # state_city_chs << 'NH - Concord'
    # state_city_chs << 'NJ - Atlantic City'
    # state_city_chs << 'NJ - Newark'
    # state_city_chs << 'NM - Albuquerque'
    # state_city_chs << 'NM - Roswell'
    # state_city_chs << 'NM - Tucumcari'
    # state_city_chs << 'NV - Elko'
    # state_city_chs << 'NV - Ely'
    # state_city_chs << 'NV - Las Vegas'
    # state_city_chs << 'NV - Reno'
    # state_city_chs << 'NV - Tonopah'
    # state_city_chs << 'NV - Winnemucca'
    # state_city_chs << 'NY - Albany'
    # state_city_chs << 'NY - Binghamton'
    # state_city_chs << 'NY - Buffalo'
    # state_city_chs << 'NY - Massena'
    # state_city_chs << 'NY - New York-Central Park'
    # state_city_chs << 'NY - Rochester'
    # state_city_chs << 'NY - Syracuse'
    # state_city_chs << 'OH - Akron'
    # state_city_chs << 'OH - Cleveland'
    # state_city_chs << 'OH - Columbus'
    # state_city_chs << 'OH - Mansfield'
    # state_city_chs << 'OH - Toledo'
    # state_city_chs << 'OH - Youngstown'
    # state_city_chs << 'OK - Oklahoma City'
    # state_city_chs << 'OK - Tulsa'
    # state_city_chs << 'OR - Astoria'
    # state_city_chs << 'OR - Burns'
    # state_city_chs << 'OR - Eugene'
    # state_city_chs << 'OR - Medford'
    # state_city_chs << 'OR - North Bend'
    # state_city_chs << 'OR - Pendleton'
    # state_city_chs << 'OR - Portland'
    # state_city_chs << 'OR - Redmond'
    # state_city_chs << 'OR - Salem'
    # state_city_chs << 'PA - Allentown'
    # state_city_chs << 'PA - Bradford'
    # state_city_chs << 'PA - Erie'
    # state_city_chs << 'PA - Harrisburg'
    # state_city_chs << 'PA - Philadelphia'
    # state_city_chs << 'PA - Pittsburgh'
    # state_city_chs << 'PA - Wilkes-Barre'
    # state_city_chs << 'PA - Williamsport'
    # state_city_chs << 'RI - Providence'
    # state_city_chs << 'SC - Charleston'
    # state_city_chs << 'SC - Columbia'
    # state_city_chs << 'SC - Greenville'
    # state_city_chs << 'SD - Huron'
    # state_city_chs << 'SD - Pierre'
    # state_city_chs << 'SD - Sioux Falls'
    # state_city_chs << 'TN - Bristol'
    # state_city_chs << 'TN - Chattanooga'
    # state_city_chs << 'TN - Knoxville'
    # state_city_chs << 'TN - Memphis'
    # state_city_chs << 'TN - Nashville'
    # state_city_chs << 'TX - Abilene'
    # state_city_chs << 'TX - Amarillo'
    # state_city_chs << 'TX - Austin'
    # state_city_chs << 'TX - Brownsville'
    # state_city_chs << 'TX - Corpus Christi'
    # state_city_chs << 'TX - Del Rio'
    # state_city_chs << 'TX - El Paso'
    # state_city_chs << 'TX - Fort Worth'
    # state_city_chs << 'TX - Houston'
    # state_city_chs << 'TX - Lubbock'
    # state_city_chs << 'TX - Lufkin'
    # state_city_chs << 'TX - Midland'
    # state_city_chs << 'TX - Port Arthur'
    # state_city_chs << 'TX - San Angelo'
    # state_city_chs << 'TX - San Antonio'
    # state_city_chs << 'TX - Victoria'
    # state_city_chs << 'TX - Waco'
    # state_city_chs << 'TX - Wichita Falls'
    # state_city_chs << 'UT - Cedar City'
    # state_city_chs << 'UT - Salt Lake City'
    # state_city_chs << 'VA - Lynchburg'
    # state_city_chs << 'VA - Norfolk'
    # state_city_chs << 'VA - Richmond'
    # state_city_chs << 'VA - Roanoke'
    # state_city_chs << 'VT - Burlington'
    # state_city_chs << 'WA - Olympia'
    # state_city_chs << 'WA - Quillayute'
    # state_city_chs << 'WA - Seattle'
    # state_city_chs << 'WA - Spokane'
    # state_city_chs << 'WA - Yakima'
    # state_city_chs << 'WI - Eau Claire'
    # state_city_chs << 'WI - Green Bay'
    # state_city_chs << 'WI - La Crosse'
    # state_city_chs << 'WI - Madison'
    # state_city_chs << 'WI - Milwaukee'
    # state_city_chs << 'WV - Charleston'
    # state_city_chs << 'WV - Elkins'
    # state_city_chs << 'WV - Huntington'
    # state_city_chs << 'WY - Casper'
    # state_city_chs << 'WY - Cheyenne'
    # state_city_chs << 'WY - Lander'
    # state_city_chs << 'WY - Rock Springs'
    # state_city_chs << 'WY - Sheridan'
    # state_city = OpenStudio::Measure::OSArgument::makeChoiceArgument('state_city', state_city_chs, true)
    # state_city.setDisplayName('State and City')
    # state_city.setDefaultValue('DC - Washington')
    # args << state_city

	# Make a string argument for ZIP Code
    state = OpenStudio::Measure::OSArgument::makeStringArgument('state', true)
    state.setDisplayName('State')
	state.setDefaultValue('')
    args << state

	# Make a string argument for City
    city = OpenStudio::Measure::OSArgument::makeStringArgument('city', true)
    city.setDisplayName('City')
	city.setDefaultValue('')
    args << city

    # Make a string argument for ZIP Code
    zip = OpenStudio::Measure::OSArgument::makeIntegerArgument('zip', true)
    zip.setDisplayName('ZIP Code')
	zip.setDefaultValue('')
    args << zip

	# Make a string argument for Climate Zone
    climate_zone_chs = OpenStudio::StringVector.new
    climate_zone_chs << '1A'
    climate_zone_chs << '1B'
    climate_zone_chs << '1C'
    climate_zone_chs << '2A'
    climate_zone_chs << '2B'
    climate_zone_chs << '2C'
    climate_zone_chs << '3A'
    climate_zone_chs << '3B'
    climate_zone_chs << '3C'
    climate_zone_chs << '4A'
    climate_zone_chs << '4B'
    climate_zone_chs << '4C'
    climate_zone_chs << '5A'
    climate_zone_chs << '5B'
    climate_zone_chs << '5C'
    climate_zone_chs << '6A'
    climate_zone_chs << '6B'
    climate_zone_chs << '6C'
    climate_zone_chs << '7'
    climate_zone_chs << '8'
    climate_zone = OpenStudio::Measure::OSArgument::makeChoiceArgument('climate_zone', climate_zone_chs, true)
    climate_zone.setDisplayName('ASHRAE Climate Zone')
	climate_zone.setDefaultValue('4A')
    args << climate_zone

	# Make an integer argument for number of bedroooms
    num_bedrooms = OpenStudio::Measure::OSArgument::makeIntegerArgument('num_bedrooms', true)
    num_bedrooms.setDisplayName('Number of Bedrooms')
	num_bedrooms.setDefaultValue('3')
    args << num_bedrooms

	# Make an integer argument for number of bathrooms
    num_bathrooms = OpenStudio::Measure::OSArgument::makeIntegerArgument('num_bathrooms', true)
    num_bathrooms.setDisplayName('Number of Bathrooms')
	num_bathrooms.setDefaultValue('2')
    args << num_bathrooms

	# Make a string argument for exterior door material
    door_mat_chs = OpenStudio::StringVector.new
    door_mat_chs << 'Uninsulated Fiberglass'
    door_mat_chs << 'Insulated Fiberglass'
    door_mat_chs << 'Uninsulated Metal (Aluminum)'
    door_mat_chs << 'Insulated Metal (Aluminum)'
    door_mat_chs << 'Uninsualted Metal (Steel)'
    door_mat_chs << 'Insulated Metal (Steel)'
    door_mat_chs << 'Solid Wood'
    door_mat_chs << 'Hollow Wood'
	door_mat_chs << 'Glass'
	door_mat_chs << 'Other'
    door_mat = OpenStudio::Measure::OSArgument::makeChoiceArgument('door_mat', door_mat_chs, true)
    door_mat.setDisplayName('Exterior Door Material')
    door_mat.setDefaultValue('Uninsulated Fiberglass')
    args << door_mat

	# The types of lighting cannot be pulled from the model and must be provided by the user.

    # Make a double argument for percent incandescent lighting
    pct_inc_lts = OpenStudio::Measure::OSArgument::makeDoubleArgument('pct_inc_lts', true)
    pct_inc_lts.setDisplayName('Percent Incandescent Lighting (Whole %)')
    pct_inc_lts.setDescription('Percentage of total lighting wattage that is incandescent.')
    pct_inc_lts.setUnits('%')
    pct_inc_lts.setDefaultValue(0)
    args << pct_inc_lts

    # Make a double argument for percent metal halide lighting
    pct_mh_lts = OpenStudio::Measure::OSArgument::makeDoubleArgument('pct_mh_lts', true)
    pct_mh_lts.setDisplayName('Percent Metal Halide Lighting (Whole %)')
    pct_mh_lts.setDescription('Percentage of total lighting wattage that is metal halide.')
    pct_mh_lts.setUnits('%')
    pct_mh_lts.setDefaultValue(0)
    args << pct_mh_lts

    # Make a double argument for percent CFL or linear fluorescent lighting
    pcf_cfl_lf_lts = OpenStudio::Measure::OSArgument::makeDoubleArgument('pcf_cfl_lf_lts', true)
    pcf_cfl_lf_lts.setDisplayName('Percent CFL or Linear Fluorescent Lighting (Whole %)')
    pcf_cfl_lf_lts.setDescription('Percentage of total lighting wattage that is CFL or linear fluorescent.')
    pcf_cfl_lf_lts.setUnits('%')
    pcf_cfl_lf_lts.setDefaultValue(100.0)
    args << pcf_cfl_lf_lts

    # Make a double argument for percent incandescent lighting
    pct_led_lts = OpenStudio::Measure::OSArgument::makeDoubleArgument('pct_led_lts', true)
    pct_led_lts.setDisplayName('Percent LED Lighting (Whole %)')
    pct_led_lts.setDescription('Percentage of total lighting wattage that is LED.')
    pct_led_lts.setUnits('%')
    pct_led_lts.setDefaultValue(0)
    args << pct_led_lts

	# Make a string argument for attic type
    attic_type = OpenStudio::StringVector.new
    attic_type << 'VENTED_ATTIC'
    attic_type << 'VENTING_UNKNOWN_ATTIC'
	attic_type << 'CATHEDRAL_CEILING'
    attic_type << 'CAPE_COD'
    attic_type << 'OTHER_ATTIC_TYPE'
	attic_type << 'FLAT_ROOF'
    attic_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('attic_type', attic_type, true)
    attic_type.setDisplayName('Attic Type')
    attic_type.setDefaultValue('VENTED_ATTIC')
    args << attic_type

    # Make a double argument for foundation characteristics
    found_chs = OpenStudio::StringVector.new
    found_chs << 'Basement, Slab R-0, Wall R-0'
    found_chs << 'Basement, Slab R-0, Wall R-5'
    found_chs << 'Basement, Slab R-0, Wall R-8'
    found_chs << 'Basement, Slab R-0, Wall R-10'
    found_chs << 'Basement, Slab R-0, Wall R-15'
    found_chs << 'Basement, Slab R-0, Wall R-20'
    found_chs << 'Basement, Slab R-0, Wall R-22'
    found_chs << 'Basement, Slab R-0, Wall R-25'
    found_chs << 'Basement, Slab R-10, Wall R-0'
    found_chs << 'Basement, Slab R-10, Wall R-5'
    found_chs << 'Basement, Slab R-10, Wall R-8'
    found_chs << 'Basement, Slab R-10, Wall R-10'
    found_chs << 'Basement, Slab R-10, Wall R-15'
    found_chs << 'Basement, Slab R-10, Wall R-20'
    found_chs << 'Basement, Slab R-10, Wall R-22'
    found_chs << 'Basement, Slab R-10, Wall R-25'
    found_chs << 'Crawlspace, R-13'
    found_chs << 'Crawlspace, R-19'
    found_chs << 'Crawlspace, R-30'
    found_chs << 'Crawlspace, R-38'
    found_chs << 'Slab On/In Grade, R-0 0 ft'
    found_chs << 'Slab On/In Grade, R-5 2 ft'
    found_chs << 'Slab On/In Grade, R-10 2 ft'
    found_chs << 'Slab On/In Grade, R-10 4 ft'
    found_chars = OpenStudio::Measure::OSArgument::makeChoiceArgument('found_chars', found_chs, true)
    found_chars.setDisplayName('Foundation Characteristics')
    found_chars.setDefaultValue('Basement, Slab R-10, Wall R-22')
    args << found_chars

    # Make a choice argument for primary HVAC system type
    pri_hvac_chs = OpenStudio::StringVector.new
    pri_hvac_chs << 'Resid_CentralAC_Furnace_Gas'
	#pri_hvac_chs << 'Resid_CentralAC_Furnace_Oil'
	#pri_hvac_chs << 'Resid_CentralAC_Furnace_Propane'
    pri_hvac_chs << 'Resid_CentralAC_Furnace_Electric'
	pri_hvac_chs << 'Resid_CentralAC_Baseboard_Electric'
	pri_hvac_chs << 'Resid_CentralAC_Boiler_Electric'
	pri_hvac_chs << 'Resid_CentralAC_Boiler_Gas'
	pri_hvac_chs << 'Resid_CentralAC_Boiler_Oil'
	pri_hvac_chs << 'Resid_CentralAC_Boiler_Propane'
    pri_hvac_chs << 'Resid_CentralAC_NoHeat_NoFuel'
	pri_hvac_chs << 'Resid_NoAC_Furnace_Gas'
	pri_hvac_chs << 'Resid_NoAC_Furnace_Electric'
	pri_hvac_chs << 'Resid_NoAC_Boiler_Electric'
	pri_hvac_chs << 'Resid_NoAC_Boiler_Gas'
	pri_hvac_chs << 'Resid_NoAC_Boiler_Oil'
	pri_hvac_chs << 'Resid_NoAC_Boiler_Propane'
	pri_hvac_chs << 'Resid_NoAC_Baseboard_Electric'
	pri_hvac_chs << 'Resid_HeatPump_AirtoAir_Std'
	pri_hvac_chs << 'Resid_HeatPump_AirtoAir_SDHV'
	pri_hvac_chs << 'Resid_HeatPump_AirtoAir_MiniSplitDucted'
	pri_hvac_chs << 'Resid_HeatPump_AirtoAir_MiniSplitNonDucted'
	#pri_hvac_chs << 'Resid_HeatPump_Geothermal_Horizontal'
	pri_hvac_chs << 'Resid_HeatPump_Geothermal_Vertical'
	#pri_hvac_chs << 'Resid_HeatPump_Geothermal_Slinky'
    pri_hvac_chs << 'Resid_RoomAC_Furnace_Gas'
	#pri_hvac_chs << 'Resid_RoomAC_Furnace_Oil'
	#pri_hvac_chs << 'Resid_RoomAC_Furnace_Propane'
    pri_hvac_chs << 'Resid_RoomAC_Furnace_Electric'
	pri_hvac_chs << 'Resid_RoomAC_Baseboard_Electric'
	#pri_hvac_chs << 'Resid_RoomAC_Boiler_Electric'
	#pri_hvac_chs << 'Resid_RoomAC_Boiler_Gas'
	#pri_hvac_chs << 'Resid_RoomAC_Boiler_Oil'
	#pri_hvac_chs << 'Resid_RoomAC_Boiler_Propane'
    pri_hvac = OpenStudio::Measure::OSArgument::makeChoiceArgument('pri_hvac', pri_hvac_chs, true)
    pri_hvac.setDisplayName('Primary HVAC Type')
    pri_hvac.setDefaultValue('Resid_HeatPump_AirtoAir_Std')
    args << pri_hvac

	# Make a choice for secondary HVAC system type. These are defaulted to 'none'. This will be changed in the future for homes with multiple systems.
    ductwork_chs = OpenStudio::StringVector.new
    ductwork_chs << 'None'
	ductwork_chs << 'Standard Ductwork'
	ductwork_chs << 'Small Duct High Velocity Ductwork'
	ductwork_chs << 'Hydronic Distribution'
    ductwork = OpenStudio::Measure::OSArgument::makeChoiceArgument('ductwork', ductwork_chs, true)
    ductwork.setDisplayName('HVAC Distribution Type (Air or Hydronic)')
    ductwork.setDefaultValue('None')
    args << ductwork

   # Make a double argument for percent ductwork inside conditioned space
    pct_ductwork_inside = OpenStudio::Measure::OSArgument::makeDoubleArgument('pct_ductwork_inside', true)
    pct_ductwork_inside.setDisplayName('Percent Ductwork Inside Conditioned Space')
    pct_ductwork_inside.setDescription('Ductwork inside the conditioned space is assumed to have no insulation.')
    pct_ductwork_inside.setUnits('%')
    pct_ductwork_inside.setDefaultValue(100)
    args << pct_ductwork_inside

    # Make a choice for secondary HVAC system type. These are defaulted to 'none'. This will be changed in the future for homes with multiple systems.
    #sec_hvac_chs = OpenStudio::StringVector.new
    #sec_hvac_chs << 'None'
    #sec_hvac = OpenStudio::Measure::OSArgument::makeChoiceArgument('sec_hvac', sec_hvac_chs, true)
    #sec_hvac.setDisplayName('Secondary HVAC System Type')
    #sec_hvac.setDefaultValue('None')
    #args << sec_hvac

    # Make a choice argument for solar PV panel details. This cannot be provided by OS model and must be user defined.
    panel_type_chs = OpenStudio::StringVector.new
    panel_type_chs << 'None'
    panel_type_chs << 'POLYCRYSTALLINE'
    panel_type_chs << 'MONOCRYSTALLINE'
	panel_type_chs << 'THIN_FILM'
    panel_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('panel_type', panel_type_chs, true)
    panel_type.setDisplayName('Solar PV - Panel Type')
    panel_type.setDefaultValue('None')
    args << panel_type

    # Make a choice argument for solar PV inverter details. This cannot be provided by OS model and must be user defined.
    inverter_type_chs = OpenStudio::StringVector.new
    inverter_type_chs << 'None'
    inverter_type_chs << 'String'
    inverter_type_chs << 'Optimizer'
	inverter_type_chs << 'Micro'
    inverter_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('inverter_type', inverter_type_chs, true)
    inverter_type.setDisplayName('Solar PV - Inverter Type')
    inverter_type.setDefaultValue('None')
    args << inverter_type

	# Make a choice argument for solar PV panel source country. This cannot be provided by OS model and must be user defined.
    panel_country_chs = OpenStudio::StringVector.new
    panel_country_chs << 'None'
    panel_country_chs << 'USA'
    panel_country_chs << 'China'
	panel_country_chs << 'Other'
    panel_country = OpenStudio::Measure::OSArgument::makeChoiceArgument('panel_country', panel_country_chs, true)
    panel_country.setDisplayName('Solar PV - Panel Source Country')
    panel_country.setDefaultValue('None')
    args << panel_country

	# Make a choice argument for solar thermal system. This cannot be provided by OS model and must be user defined.
    solar_thermal_sys_type_chs = OpenStudio::StringVector.new
    solar_thermal_sys_type_chs << 'None'
    solar_thermal_sys_type_chs << 'Hot Water'
    solar_thermal_sys_type_chs << 'Space Heating'
	solar_thermal_sys_type_chs << 'Hot Water and Space Heating'
	solar_thermal_sys_type_chs << 'Hybrid'
    solar_thermal_sys_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('solar_thermal_sys_type', solar_thermal_sys_type_chs, true)
    solar_thermal_sys_type.setDisplayName('Solar Thermal System Type')
    solar_thermal_sys_type.setDefaultValue('None')
    args << solar_thermal_sys_type

	# Make a choice argument for solar thermal collector type. This cannot be provided by OS model and must be user defined.
    solar_thermal_collector_type_chs = OpenStudio::StringVector.new
    solar_thermal_collector_type_chs << 'None'
    solar_thermal_collector_type_chs << 'Integrated Collector Storage'
    solar_thermal_collector_type_chs << 'Evacuated Tube'
	solar_thermal_collector_type_chs << 'Double Glazing Selective'
	solar_thermal_collector_type_chs << 'Double Glazing Black'
	solar_thermal_collector_type_chs << 'Single Glazing Selective'
	solar_thermal_collector_type_chs << 'Single Glazing Black'
    solar_thermal_collector_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('solar_thermal_collector_type', solar_thermal_collector_type_chs, true)
    solar_thermal_collector_type.setDisplayName('Solar Thermal Collector Type')
    solar_thermal_collector_type.setDefaultValue('None')
    args << solar_thermal_collector_type

	# Make a choice argument for solar thermal collector type. This cannot be provided by OS model and must be user defined.
    solar_thermal_loop_type_chs = OpenStudio::StringVector.new
    solar_thermal_loop_type_chs << 'None'
    solar_thermal_loop_type_chs << 'Passive Thermosyphon'
    solar_thermal_loop_type_chs << 'Liquid Indirect'
	solar_thermal_loop_type_chs << 'Liquid Direct'
	solar_thermal_loop_type_chs << 'Air Indirect'
	solar_thermal_loop_type_chs << 'Air Direct'
    solar_thermal_loop_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('solar_thermal_loop_type', solar_thermal_loop_type_chs, true)
    solar_thermal_loop_type.setDisplayName('Solar Thermal Collector Loop Type')
    solar_thermal_loop_type.setDefaultValue('None')
    args << solar_thermal_loop_type

	# Appliances - Clothes Washer
    appliance_clothes_washer_chs = OpenStudio::StringVector.new
    appliance_clothes_washer_chs << 'No Clothes Washer'
	appliance_clothes_washer_chs << 'Standard'
	appliance_clothes_washer_chs << 'EnergyStar'
    appliance_clothes_washer = OpenStudio::Measure::OSArgument::makeChoiceArgument('appliance_clothes_washer', appliance_clothes_washer_chs, true)
    appliance_clothes_washer.setDisplayName('Clothes Washer - Efficiency')
    appliance_clothes_washer.setDefaultValue('Standard')
    args << appliance_clothes_washer

	# Appliances - Clothes Dryer
    appliance_clothes_dryer_chs = OpenStudio::StringVector.new
    appliance_clothes_dryer_chs << 'No Clothes Dryer'
	appliance_clothes_dryer_chs << 'Electric'
	appliance_clothes_dryer_chs << 'Electric Heat Pump'
	appliance_clothes_dryer_chs << 'Electric Premium'
	appliance_clothes_dryer_chs << 'Gas'
	appliance_clothes_dryer_chs << 'Gas Premium'
	appliance_clothes_dryer_chs << 'Propane'
    appliance_clothes_dryer = OpenStudio::Measure::OSArgument::makeChoiceArgument('appliance_clothes_dryer', appliance_clothes_dryer_chs, true)
    appliance_clothes_dryer.setDisplayName('Clothes dryer - Efficiency')
    appliance_clothes_dryer.setDefaultValue('Electric')
    args << appliance_clothes_dryer

	# Appliances - Cooking Range
    appliance_cooking_range_chs = OpenStudio::StringVector.new
    appliance_cooking_range_chs << 'No Cooking Range'
	appliance_cooking_range_chs << 'Electric'
	appliance_cooking_range_chs << 'Electric Induction'
	appliance_cooking_range_chs << 'Gas'
	appliance_cooking_range_chs << 'Propane'
    appliance_cooking_range = OpenStudio::Measure::OSArgument::makeChoiceArgument('appliance_cooking_range', appliance_cooking_range_chs, true)
    appliance_cooking_range.setDisplayName('Cooking range')
    appliance_cooking_range.setDefaultValue('Electric')
    args << appliance_cooking_range

	# Appliances - Dishwasher
    appliance_dishwasher_chs = OpenStudio::StringVector.new
    appliance_dishwasher_chs << 'No Dishwasher'
	appliance_dishwasher_chs << '290 rated kWh'
	appliance_dishwasher_chs << '318 rated kWh'
    appliance_dishwasher = OpenStudio::Measure::OSArgument::makeChoiceArgument('appliance_dishwasher', appliance_dishwasher_chs, true)
    appliance_dishwasher.setDisplayName('Dishwasher')
    appliance_dishwasher.setDefaultValue('290 rated kWh')
    args << appliance_dishwasher

	# Appliances - Refrigerator
    appliance_frig_chs = OpenStudio::StringVector.new
    appliance_frig_chs << 'None'
	appliance_frig_chs << 'BottomFreezer_EF_10.2_Cap_24_EnergyStar'
	appliance_frig_chs << 'BottomFreezer_EF_13.6_Cap_24_EnergyStar'
	appliance_frig_chs << 'BottomFreezer_EF_15.9_Cap_24_EnergyStar'
	appliance_frig_chs << 'BottomFreezer_EF_19.8_Cap_24_EnergyStar'
	appliance_frig_chs << 'BottomFreezer_EF_20.1_Cap_24_EnergyStar'
	appliance_frig_chs << 'BottomFreezer_EF_21.3_Cap_24_EnergyStar'
	appliance_frig_chs << 'BottomFreezer_EF_4.5_Cap_24_EnergyStar'
	appliance_frig_chs << 'BottomFreezer_EF_6.7_Cap_24_EnergyStar'
    appliance_frig_chs << 'SideFreezer_EF_10.8_Cap_24_EnergyStar'
    appliance_frig_chs << 'SideFreezer_EF_13.8_Cap_24_EnergyStar'
    appliance_frig_chs << 'SideFreezer_EF_15.7_Cap_24_EnergyStar'
    appliance_frig_chs << 'SideFreezer_EF_19.6_Cap_24_EnergyStar'
    appliance_frig_chs << 'SideFreezer_EF_19.8_Cap_24_EnergyStar'
    appliance_frig_chs << 'SideFreezer_EF_20.6_Cap_24_EnergyStar'
    appliance_frig_chs << 'SideFreezer_EF_6.5_Cap_24_EnergyStar'
    appliance_frig_chs << 'SideFreezer_EF_4.4_Cap_24_EnergyStar'
	appliance_frig_chs << 'TopFreezer_EF_10.5_Cap_24_EnergyStar'
	appliance_frig_chs << 'TopFreezer_EF_14.1_Cap_24_EnergyStar'
	appliance_frig_chs << 'TopFreezer_EF_15.9_Cap_24_EnergyStar'
	appliance_frig_chs << 'TopFreezer_EF_17.6_Cap_24_EnergyStar'
	appliance_frig_chs << 'TopFreezer_EF_19.9_Cap_24_EnergyStar'
	appliance_frig_chs << 'TopFreezer_EF_20.4_Cap_24_EnergyStar'
	appliance_frig_chs << 'TopFreezer_EF_21.9_Cap_24_EnergyStar'
	appliance_frig_chs << 'TopFreezer_EF_4.4_Cap_24_EnergyStar'
	appliance_frig_chs << 'TopFreezer_EF_6.9_Cap_24_EnergyStar'
	#Expand to include all options.
	appliance_frig = OpenStudio::Measure::OSArgument::makeChoiceArgument('appliance_frig', appliance_frig_chs, true)
    appliance_frig.setDisplayName('Refrigerator Size and Efficiency')
    appliance_frig.setDefaultValue('TopFreezer_EF_10.5_Cap_24_EnergyStar')
    args << appliance_frig

	# Appliances - Freezer
    appliance_freezer_chs = OpenStudio::StringVector.new
    appliance_freezer_chs << 'No_Freezer'
	appliance_freezer_chs << 'Chest_EF_10'
	appliance_freezer_chs << 'Chest_EF_13'
	appliance_freezer_chs << 'Chest_EF_18'
	appliance_freezer_chs << 'Chest_EF_24'
	appliance_freezer_chs << 'Chest_EF_27'
	appliance_freezer_chs << 'Chest_EF_29'
	appliance_freezer_chs << 'Upright_EF_12'
	appliance_freezer_chs << 'Upright_EF_16'
	appliance_freezer_chs << 'Upright_EF_18'
	appliance_freezer_chs << 'Upright_EF_20'
	appliance_freezer_chs << 'Upright_EF_6'
	appliance_freezer_chs << 'Upright_EF_9'
    appliance_freezer = OpenStudio::Measure::OSArgument::makeChoiceArgument('appliance_freezer', appliance_freezer_chs, true)
    appliance_freezer.setDisplayName('Freezer')
    appliance_freezer.setDefaultValue('No_Freezer')
    args << appliance_freezer


	# Operational Energy LCIA Data Assumptions
	oper_energy_lcia_chs = OpenStudio::StringVector.new
    oper_energy_lcia_chs << 'ATTRIBUTIONAL'
	oper_energy_lcia_chs << 'PROJECTION_REFERENCE'
	oper_energy_lcia_chs << 'PROJECTION_LOW_RENEWABLE_COST'
    oper_energy_lcia = OpenStudio::Measure::OSArgument::makeChoiceArgument('oper_energy_lcia', oper_energy_lcia_chs, true)
    oper_energy_lcia.setDisplayName('Operational Energy LCIA Data')
    oper_energy_lcia.setDefaultValue('ATTRIBUTIONAL')
    args << oper_energy_lcia

	# LCA System Boundary
    lc_stage_chs = OpenStudio::StringVector.new
    lc_stage_chs << 'A-C'
	lc_stage_chs << 'A-D'
    lc_stage = OpenStudio::Measure::OSArgument::makeChoiceArgument('lc_stage', lc_stage_chs, true)
    lc_stage.setDisplayName('LCA System Boundary')
    lc_stage.setDefaultValue('A-C')
    args << lc_stage

    # Make a string argument for study_period
    study_period = OpenStudio::Ruleset::OSArgument::makeIntegerArgument('study_period', true)
    study_period.setDisplayName('Study Period')
    study_period.setDescription('Study period must be at least 60 yrs')
    study_period.setUnits('yrs')
    study_period.setMinValue(60)		# not sure if this is doing anything
	study_period.setDefaultValue(60)
    args << study_period

	# Make a double argument for each life cycle impact assessment weight
    # env_wts = {}
    # env_wts['Global Warming'] = 14.29
    # env_wts['Acidification'] = 14.29
    # env_wts['HH_Respiratory'] = 14.29
    # env_wts['Ozone Depletion'] = 14.29
    # env_wts['Eutrophication'] = 14.28
    # env_wts['Smog'] = 14.28
    # env_wts['Primary Energy'] = 14.28

    # env_wts.each do |cat, wt|
      # cat_var = cat.downcase.gsub(' ','_').to_s
      # wt_arg = OpenStudio::Measure::OSArgument::makeDoubleArgument(cat_var, true)
	  # wt_arg.setDisplayName(cat)
      # wt_arg.setDefaultValue(wt)
      # wt_arg.setDescription('LCIA weights must add up to 100')
      # args << wt_arg
    # end

    return args


end
