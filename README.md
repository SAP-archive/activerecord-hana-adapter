ActiveRecord HANA Adapter
=========================

Description
-----------

The Hana ActiveRecord adapter provides Hana access from Ruby on Rails applications.
The adapter is compatible with Ruby on Rails v3 and v4 and needs a ODBC connection to the Hana database (only available for Linux and Windows).

Installation
------------

Add this line to your application's Gemfile:

    gem 'activerecord-hana-adapter'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install activerecord-hana-adapter

Usage
-----

Install the odbc driver for HANA (only available for Linux and Windows)

Add a ODBC DSN in your odbc.ini

    [HANA]
	servernode=hanaDB.yourdomain.com:30015
	driver=/usr/lib/libodbcHDB.so`

To test your ODBC Connection use

	isql HANA username password

Install the ruby odbc support
	
	gem install ruby-odbc
	gem install activerecord-odbc-adapter

Install the activerecord hana adapter

	gem install activerecord-hana-adapter

Create your Rails App

Example for database.yml entry

	test:
     adapter: hana
     mode: odbc
     dsn: HANA
     username: username
     password: password
     database: schema_name_test


Contributing
------------

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

Acknowledgements
----------------

Special thanks to the Enterprise Platform and Integration Concepts (EPIC) chair of the Hasso Plattner Institute especially to team of Keven Richly for the important contribution to this project.