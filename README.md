# NIST BIRDS NEST - V2021

BIRDS NEST is a web API that calculates whole building life cycle assessment (wbLCA) results for 
residential buildings using a standardized format (based on HPXML) to submit the necessary building 
characteristics and performance. The wbLCA results include full life cycle analysis, including embodied 
and operational environmental impacts throughout a building’s service life. The wbLCA includes building 
materials (leveraging ASMI’s Impact Estimator for Buildings), building systems, and operational energy 
consumption throughout the selected study period. BIRDS NEST has a companion OpenStudio (OS) Measure to 
convert information from OS to the necessary format and communicate with BIRDS NEST.

The BIRDS NEST OpenStudio Measure communicates with NIST’s BIRDS NEST API to generate and report whole 
building life cycle assessment (wbLCA) results for residential buildings modeled in OpenStudio. The 
Measure combines automated input extraction from the OS model, E+ results, and user inputs required by 
the Measure (values not defined or cannot currently be identified within the OS model) into an 
HPXML-based file structure that is sent to the BIRDS NEST API, which in turn sends back wbLCA results 
that are provided in a Results Report within OS.

## Modeler Description
For single-family detached homes only.

## Measure Type
ReportingMeasure

## Taxonomy


## Arguments


### BIRDS NEST API Access Token

**Name:** birds_api_key,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### BIRDS API URL

**Name:** api_url,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### BIRDS NEST API Refresh Token

**Name:** birds_api_refresh_token,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### BIRDS API Token Refresh URL

**Name:** api_refresh_url,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Commercial or Residential Building

**Name:** com_res,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Building Type

**Name:** bldg_type,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Construction Quality

**Name:** const_qual,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### State

**Name:** state,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### City

**Name:** city,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### ZIP Code

**Name:** zip,
**Type:** Integer,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### ASHRAE Climate Zone

**Name:** climate_zone,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Number of Bedrooms

**Name:** num_bedrooms,
**Type:** Integer,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Number of Bathrooms

**Name:** num_bathrooms,
**Type:** Integer,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Exterior Door Material

**Name:** door_mat,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Percent Incandescent Lighting (Whole %)
Percentage of total lighting wattage that is incandescent.
**Name:** pct_inc_lts,
**Type:** Double,
**Units:** %,
**Required:** true,
**Model Dependent:** false

### Percent Metal Halide Lighting (Whole %)
Percentage of total lighting wattage that is metal halide.
**Name:** pct_mh_lts,
**Type:** Double,
**Units:** %,
**Required:** true,
**Model Dependent:** false

### Percent CFL or Linear Fluorescent Lighting (Whole %)
Percentage of total lighting wattage that is CFL or linear fluorescent.
**Name:** pcf_cfl_lf_lts,
**Type:** Double,
**Units:** %,
**Required:** true,
**Model Dependent:** false

### Percent LED Lighting (Whole %)
Percentage of total lighting wattage that is LED.
**Name:** pct_led_lts,
**Type:** Double,
**Units:** %,
**Required:** true,
**Model Dependent:** false

### Attic Type

**Name:** attic_type,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Foundation Characteristics

**Name:** found_chars,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Primary HVAC Type

**Name:** pri_hvac,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### HVAC Distribution Type (Air or Hydronic)

**Name:** ductwork,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Percent Ductwork Inside Conditioned Space
Ductwork inside the conditioned space is assumed to have no insulation.
**Name:** pct_ductwork_inside,
**Type:** Double,
**Units:** %,
**Required:** true,
**Model Dependent:** false

### Solar PV - Panel Type

**Name:** panel_type,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Solar PV - Inverter Type

**Name:** inverter_type,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Solar PV - Panel Source Country

**Name:** panel_country,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Solar Thermal System Type

**Name:** solar_thermal_sys_type,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Solar Thermal Collector Type

**Name:** solar_thermal_collector_type,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Solar Thermal Collector Loop Type

**Name:** solar_thermal_loop_type,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Clothes Washer - Efficiency

**Name:** appliance_clothes_washer,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Clothes dryer - Efficiency

**Name:** appliance_clothes_dryer,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Cooking range

**Name:** appliance_cooking_range,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Dishwasher

**Name:** appliance_dishwasher,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Refrigerator Size and Efficiency

**Name:** appliance_frig,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Freezer

**Name:** appliance_freezer,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Operational Energy LCIA Data

**Name:** oper_energy_lcia,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### LCA System Boundary

**Name:** lc_stage,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Study Period
Study period must be at least 60 yrs
**Name:** study_period,
**Type:** Integer,
**Units:** yrs,
**Required:** true,
**Model Dependent:** false




