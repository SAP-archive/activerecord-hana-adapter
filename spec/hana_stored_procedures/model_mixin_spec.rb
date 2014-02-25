require 'spec_helper'

describe ActiveRecord::Hana::Adapter::ModelMixin do
  STORED_PROCEDURE_NAME ||= :test_procedure
  TABLE_NAME = "models_#{Time.now.to_i}"

  before(:all) do
    establish_connection
    silence_stream(STDOUT) do
      ActiveRecord::Migration.new.create_table(TABLE_NAME) do |table|
        table.string :name
      end
    end
  end

  before(:each) do
    class Model < ActiveRecord::Base; end
    Model.table_name = TABLE_NAME
  end

  after(:each) do
    Object.send(:remove_const, :Model)
  end

  after(:all) do
    silence_stream(STDOUT) do
      ActiveRecord::Migration.new.drop_table(TABLE_NAME)
    end
  end

  it 'provides an aliased class method for stored procedure integration' do
    expect(ActiveRecord::Base).to respond_to(:use_stored_procedure)
    expect(ActiveRecord::Base).to respond_to(:uses_stored_procedure)
  end

  it 'makes OutputParameter accessible in the class scope' do
    expect(Model::OutputParameter).to be_a(Class)
  end

  describe 'stored procedure integration' do
    it 'generates a class-side wrapper method' do
      Model.use_stored_procedure :foo
      expect(Model).to respond_to(:foo)
    end

    it 'supports instance-side methods' do
      Model.use_stored_procedure :foo, location: :instance
      expect(Model).not_to respond_to(:foo)
      expect(Model.new).to respond_to(:foo)
    end

    it 'can generate both methods' do
      Model.use_stored_procedure :foo, location: :both
      expect(Model).to respond_to(:foo)
      expect(Model.new).to respond_to(:foo)
    end

    it 'supports custom method naming' do
      Model.use_stored_procedure :foo, as: :bar
      expect(Model).to respond_to(:bar)
    end
  end 

  describe 'stored procedure execution' do
    after(:each) do
      reset(active_record_connection)
      drop_procedure(STORED_PROCEDURE_NAME)
    end

    it 'calls the stored procedure' do
      create_procedure(STORED_PROCEDURE_NAME, 'SELECT * FROM dummy')
      Model.use_stored_procedure STORED_PROCEDURE_NAME
      expect(active_record_connection).to receive(:select_all).with("CALL \"#{STORED_PROCEDURE_NAME}\"()")
      Model.send(STORED_PROCEDURE_NAME)
    end

    it 'passes the arguments' do
      create_procedure(STORED_PROCEDURE_NAME, 'CREATE PROCEDURE "{name}" (IN parameter INTEGER) AS BEGIN END')
      Model.use_stored_procedure STORED_PROCEDURE_NAME
      argument = 23
      expect(active_record_connection).to receive(:select_all).with("CALL \"#{STORED_PROCEDURE_NAME}\"(#{argument})")
      Model.send(STORED_PROCEDURE_NAME, argument)
    end

    it 'supports blocks' do
      create_procedure(STORED_PROCEDURE_NAME, 'SELECT * FROM dummy')
      Model.use_stored_procedure(STORED_PROCEDURE_NAME) do |relation, output_values|
        expect(relation).to be_an(Array)
        expect(output_values).to be_a(Hash)
      end
      Model.send(STORED_PROCEDURE_NAME)
    end

    context 'when involving relations' do
      before(:each) do
        @names = %w[foo bar baz].each do |name|
          Model.create(name: name)
        end
        create_procedure(STORED_PROCEDURE_NAME, "SELECT * FROM \"#{TABLE_NAME}\"")
      end

      after(:each) do
        Model.delete_all
        drop_procedure(STORED_PROCEDURE_NAME)
      end

      it 'fetches the relation' do
        Model.use_stored_procedure STORED_PROCEDURE_NAME
        relation = Model.send(STORED_PROCEDURE_NAME)
        expect(relation).to be_an(Array)
        expect(relation.count).to eq(@names.count)
      end

      it 'provides indifferent access' do
        Model.use_stored_procedure STORED_PROCEDURE_NAME
        relation = Model.send(STORED_PROCEDURE_NAME)
        expect(relation.first['name']).to eq(@names.first)
        expect(relation.first[:name]).to eq(@names.first)
      end

      it 'supports single results' do
        drop_procedure(STORED_PROCEDURE_NAME)
        create_procedure(STORED_PROCEDURE_NAME, "SELECT * FROM \"#{TABLE_NAME}\" LIMIT 1")
        Model.use_stored_procedure STORED_PROCEDURE_NAME, single: true
        expect(Model.send(STORED_PROCEDURE_NAME)).to be_a(Hash)
      end

      describe 'object instantiation' do
        it 'supports explicit instantiation' do
          Model.use_stored_procedure STORED_PROCEDURE_NAME, class: Model
          expect(Model.send(STORED_PROCEDURE_NAME).first).to be_a(Model)
        end

        it 'supports implicit instantiation' do
          Model.use_stored_procedure STORED_PROCEDURE_NAME, instantiate: true
          expect(Model.send(STORED_PROCEDURE_NAME).first).to be_a(Model)
        end
      end
    end

    context 'when involving output parameters' do
      before(:each) do
        create_procedure(STORED_PROCEDURE_NAME, 'CREATE PROCEDURE "{name}" (IN parameter INTEGER, OUT result INTEGER) AS BEGIN result := parameter; END')
        Model.use_stored_procedure STORED_PROCEDURE_NAME, output_parameters: {
          result: :integer
        }
      end

      it 'supports explicit OutputParameters' do
        input = 23
        @result = Model::OutputParameter.new
        Model.send(STORED_PROCEDURE_NAME, input, @result)
        expect(@result.value).to eq(input)
      end

      it 'supports implicit OutputParameters' do
        input = 23
        Model.send(STORED_PROCEDURE_NAME, input) do |relation, output_values|
          @result = output_values[:result]
        end
        expect(@result).to eq(input)
      end

      it 'supports multiple output parameters' do
        drop_procedure(STORED_PROCEDURE_NAME)
        create_procedure(STORED_PROCEDURE_NAME, 'CREATE PROCEDURE "{name}" (OUT first TINYINT, OUT second INTEGER, OUT third VARCHAR(8)) AS BEGIN first := 0; second := 23; third := \'third\'; END')
        Model.use_stored_procedure STORED_PROCEDURE_NAME, output_parameters: {
          first: :tinyint,
          second: :integer,
          third: :varchar
        }
        Model.send(STORED_PROCEDURE_NAME) do |relation, output_values|
          expect(output_values[:first]).to be_a(Numeric)
          expect(output_values[:second]).to be_a(Numeric)
          expect(output_values[:third]).to be_a(String)
        end
      end

      describe 'supported types' do
        before(:all) do
          @create_type_test_procedure = Proc.new do |type, symbol, value|
            create_procedure(STORED_PROCEDURE_NAME, "CREATE PROCEDURE \"{name}\" (OUT result #{type}) AS BEGIN result := #{value}; END")
            Model.use_stored_procedure STORED_PROCEDURE_NAME, output_parameters: {
              result: symbol
            }
          end
        end

        before(:each) do
          drop_procedure(STORED_PROCEDURE_NAME)
          @result = Model::OutputParameter.new
        end

        it 'raises an error for unsupported types' do
          @create_type_test_procedure.call('SECONDDATE', :second_date, "'2014-01-01 00:00:00'")
          expect { Model.send(STORED_PROCEDURE_NAME, @result) }.to raise_error(TypeError)
        end

        it 'supports BIGINT' do
          @create_type_test_procedure.call('BIGINT', :bigint, 23)
          Model.send(STORED_PROCEDURE_NAME, @result)
          expect(@result.value).to eq(23)
        end

        it 'supports CHAR' do
          @create_type_test_procedure.call('CHAR(4)', :char, "'foo'")
          Model.send(STORED_PROCEDURE_NAME, @result)
          expect(@result.value).to eq('foo')
        end

        it 'supports DATE' do
          @create_type_test_procedure.call('DATE', :date, 'CURRENT_DATE')
          Model.send(STORED_PROCEDURE_NAME, @result)
          expect(@result.value).to be_a(Date)
        end

        it 'supports DECIMAL' do
          @create_type_test_procedure.call('DECIMAL', :decimal, '23.0')
          Model.send(STORED_PROCEDURE_NAME, @result)
          expect(@result.value).to eq(23)
        end

        it 'supports DOUBLE' do
          @create_type_test_procedure.call('DOUBLE', :double, '23.0')
          Model.send(STORED_PROCEDURE_NAME, @result)
          expect(@result.value).to eq(23)
        end

        it 'supports FLOAT' do
          @create_type_test_procedure.call('FLOAT', :float, '23.0')
          Model.send(STORED_PROCEDURE_NAME, @result)
          expect(@result.value).to eq(23)
        end

        it 'supports INTEGER' do
          @create_type_test_procedure.call('INTEGER', :integer, 23)
          Model.send(STORED_PROCEDURE_NAME, @result)
          expect(@result.value).to eq(23)
        end

        it 'supports REAL' do
          @create_type_test_procedure.call('REAL', :real, '23.0')
          Model.send(STORED_PROCEDURE_NAME, @result)
          expect(@result.value).to eq(23)
        end

        it 'supports SMALLINT' do
          @create_type_test_procedure.call('SMALLINT', :smallint, 23)
          Model.send(STORED_PROCEDURE_NAME, @result)
          expect(@result.value).to eq(23)
        end

        it 'supports TIME' do
          @create_type_test_procedure.call('TIME', :time, 'NOW()')
          Model.send(STORED_PROCEDURE_NAME, @result)
          expect(@result.value).to be_a(Time)
        end

        it 'supports TINYINT' do
          @create_type_test_procedure.call('TINYINT', :tinyint, 0)
          Model.send(STORED_PROCEDURE_NAME, @result)
          expect(@result.value).to eq(0)
        end

        it 'supports VARCHAR' do
          @create_type_test_procedure.call('VARCHAR(4)', :varchar, "'foo'")
          Model.send(STORED_PROCEDURE_NAME, @result)
          expect(@result.value).to eq('foo')
        end
      end
    end
  end
end
