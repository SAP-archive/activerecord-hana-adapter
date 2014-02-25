require 'spec_helper'

describe ActiveRecord::Hana::Adapter::MigrationMixin do
  include ActiveRecord::Hana::Adapter::ConnectionHelper

  STATEMENT = 'SELECT * FROM dummy;'
  STORED_PROCEDURE_NAME ||= :test_procedure

  before(:all) do
    establish_connection
    @migration = ActiveRecord::Migration.new
  end

  it 'provides migration methods for stored procedures' do
    expect(@migration).to respond_to(:create_procedure)
    expect(@migration).to respond_to(:drop_procedure)
  end

  it 'provides aliased methods' do
    expect(@migration).to respond_to(:create_stored_procedure)
    expect(@migration).to respond_to(:drop_stored_procedure)
  end

  describe 'creating a stored procedure' do
    before(:each) do
      expect(stored_procedures).not_to include(STORED_PROCEDURE_NAME)
    end

    after(:each) do
      reset(active_record_connection)
      @migration.drop_procedure(STORED_PROCEDURE_NAME)
    end

    it 'supports placeholder substitution' do
      sql = "CREATE PROCEDURE {name} LANGUAGE SQLSCRIPT AS BEGIN #{STATEMENT} END;"
      expect(active_record_connection).to receive(:execute).with(sql.sub('{name}', STORED_PROCEDURE_NAME.to_s))
      @migration.create_procedure(STORED_PROCEDURE_NAME) { sql }
      expect(active_record_connection).to receive(:execute)
    end

    describe 'SQLScript file handling' do
      before(:each) do
        @file_name = 'foo.sql'
        @rails_root = '/home/rails'
        expect(Rails).to receive(:root).and_return(@rails_root)
      end

      it 'can read SQLScript from an existing file' do
        expect(File).to receive(:exists?).and_return(true)
        expect(File).to receive(:read).with("#{@rails_root}/db/procedures/#{@file_name}").and_return(STATEMENT)
        @migration.create_procedure(STORED_PROCEDURE_NAME, file: @file_name)
      end

      it 'raises an error if the file does not exist' do
        expect { @migration.create_procedure(STORED_PROCEDURE_NAME, file: @file_name) }.to raise_error(IOError)
      end
    end

    context 'with a valid definition' do
      before(:all) do
        @proc = Proc.new do
          @migration.create_procedure(STORED_PROCEDURE_NAME) { STATEMENT }
        end
      end

      context 'without a full create statement' do
        it 'creates read-only procedures by default' do
          expect(active_record_connection).to receive(:execute).with(/READS SQL DATA/i)
          @proc.call
        end

        it 'supports writing procedures' do
          expect(active_record_connection).to receive(:execute) do |argument|
            expect(argument).not_to match(/READS SQL DATA/i)
          end
          @migration.create_procedure(STORED_PROCEDURE_NAME, read_only: false) { STATEMENT }
        end

        it 'produces indented SQLScript code' do
          expected_sql = [
            "CREATE PROCEDURE \"#{STORED_PROCEDURE_NAME}\"",
            "\tLANGUAGE SQLSCRIPT",
            "\tSQL SECURITY INVOKER",
            "\tREADS SQL DATA",
            'AS',
            'BEGIN',
            "\t#{STATEMENT}",
            'END',
            ''
          ].join("\n")
          expect(active_record_connection).to receive(:execute).with(expected_sql)
          @proc.call
        end
      end

      context 'when not defined yet' do
        it 'does not raise an error' do
          expect(@proc).not_to raise_error
        end

        it 'adds the stored procedure' do
          @proc.call
          expect(stored_procedures).to include(STORED_PROCEDURE_NAME)
        end
      end

      context 'when already defined' do
        it 'raises an error' do
          @proc.call
          expect(@proc).to raise_error
        end
      end
    end

    context 'with an invalid definition' do
      it 'raises an error' do
        expect { @migration.create_procedure }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'dropping a stored procedure' do
    context 'with an existing stored procedure' do
      before(:each) do
        @migration.create_procedure(STORED_PROCEDURE_NAME) { STATEMENT }
      end

      it 'does not raise an error' do
        expect { @migration.drop_procedure STORED_PROCEDURE_NAME }.not_to raise_error
      end

      it 'drops the stored procedure' do
        @migration.drop_procedure STORED_PROCEDURE_NAME
        expect(stored_procedures).not_to include(STORED_PROCEDURE_NAME)
      end
    end

    context 'with a non-existing stored procedure' do
      it 'does not raise an error' do
        expect { @migration.drop_procedure :non_existent }.not_to raise_error
      end
    end
  end
end
