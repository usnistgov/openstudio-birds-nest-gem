# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class SolarTest < Minitest::Test
  def test_solar_measure
    # create an instance of the measure
    measure = NISTBIRDSNESTLCIAReport.new

    puts('Testing')

    # create an instance of a runner
    #runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # make an empty model
    #model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    #arguments = measure.arguments(model)
    #assert_equal(0, arguments.size)

    # set argument values to good values and run the measure on model with spaces
    #arguments = measure.arguments(model)
    #argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    #measure.run(model, runner, argument_map)
    #result = runner.result
    # show_output(result)
    #assert(result.value.valueName == 'Success')
    #assert(result.warnings.empty?)
    #assert(result.info.empty?)
  end
end