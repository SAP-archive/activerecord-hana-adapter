require 'spec_helper'

describe ActiveRecord::Hana::Adapter::OutputParameter do
  before(:all) do
    OutputParameter = ActiveRecord::Hana::Adapter::OutputParameter
    @value = Date.today
  end

  it 'can be initialized without a value' do
    expect { @output_parameter = OutputParameter.new }.not_to raise_error
    expect(@output_parameter.value).to be_nil
  end

  it 'can be initialized with a value' do
    @output_parameter = OutputParameter.new(@value)
    expect(@output_parameter.value).to eq(@value)
  end

  it 'has working accessors' do
    @output_parameter = OutputParameter.new
    @output_parameter.value = @value
    expect(@output_parameter.value).to eq(@value)
  end
end
