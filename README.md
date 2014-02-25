Active Record HANA Adapter
==========================

Description
-----------

The HANA Active Record adapter provides HANA access from Ruby on Rails applications.
The adapter is compatible with Ruby on Rails v3 and v4 and needs an ODBC connection to the HANA database (only available for Linux and Windows).

Installation
------------

Add this line to your application's Gemfile:

```
gem 'activerecord-hana-adapter'
```

And then execute:

```
$ bundle
```

Or install it yourself as:

```
$ gem install activerecord-hana-adapter
```

Usage
-----

1. Install the ODBC driver for HANA (only available for Linux and Windows).

2. Add an ODBC DSN in your `odbc.ini`:

  ```
  [HANA]
  driver=/usr/lib/libodbcHDB.so
  servernode=hanaDB.yourdomain.com:30015
  ```

3. To test your ODBC connection use:

  ```
  isql HANA username password
  ```

4. Install the Active Record HANA adapter:

  ```
  gem install activerecord-hana-adapter
  ```

5. Create your Rails application.

6. Example for `database.yml` entry:

  ```
  test:
    adapter: hana
    dsn: HANA
    username: username
    password: password
    database: schema_name_test
  ```

Stored Procedures
-----------------

The Active Record HANA adapter includes support for stored procedures.

Stored procedures can be created and deleted by means of usual database migrations. Procedure definitions can either be provided as inline code or be read from a file.

```ruby
class CreateProcedures < ActiveRecord::Migration
  def up
    create_procedure(:dummy_procedures) { 'SELECT * FROM dummy' }
    create_procedure :demo_procedure, file: 'demo_procedure.sql'
  end

  def down
    drop_procedure :dummy_procedure
    drop_procedure :demo_procedure
  end
end
```

Assume `/db/procedures/demo_procedure.sql` includes the following SQLScript code:

```SQL
CREATE PROCEDURE "{name}" (IN first INTEGER, IN second VARCHAR(8), OUT result INTEGER)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER
READS SQL DATA
AS
BEGIN
	result := first * LENGTH(second);
END;
```

Stored procedures can be integrated into any application model by using the `use_stored_procedure` class method. The following code integrates the stored procedure `demo_procedure` into the model class `Model`. As output parameters are involved, their types have to be specified.

```ruby
class Model
  use_stored_procedure :demo_procedure, as: :demo, output_parameters: { result: :integer }
end
```

The stored procedure `demo_procedure` can now be executed by using the wrapper method `#demo`.

```ruby
Model.demo(1, 'foo') do |relation, output_values|
  @result = output_values[:result] # => 3
end
```

Contributing
------------

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

Acknowledgements
----------------

Special thanks to the Enterprise Platform and Integration Concepts (EPIC) chair of the Hasso Plattner Institute, especially to the team of Keven Richly for the important contribution to this project.
