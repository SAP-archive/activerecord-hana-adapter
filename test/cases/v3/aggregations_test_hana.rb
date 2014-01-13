require "cases/hana_helper"
require 'models/customer'

class AggregationsTest < ActiveRecord::TestCase
  fixtures :customers

  def test_find_single_value_object
    assert_equal 50, customers(:david).balance.amount
    assert_kind_of Money, customers(:david).balance
    assert_equal 300, customers(:david).balance.exchange_to("DKK").amount
  end

  def test_find_multiple_value_object
    assert_equal customers(:david).address_street, customers(:david).address.street
    assert(
      customers(:david).address.close_to?(Address.new("Different Street", customers(:david).address_city, customers(:david).address_country))
    )
  end

  #def test_change_single_value_object
  #  customers(:david).balance = Money.new(100)
  #  customers(:david).save
  #  assert_equal 100, customers(:david).reload.balance.amount
  #end

  def test_immutable_value_objects
    customers(:david).balance = Money.new(100)
    assert_raise(ActiveSupport::FrozenObjectError) { customers(:david).balance.instance_eval { @amount = 20 } }
  end

  def test_inferred_mapping
    skip
  end

  def test_reloaded_instance_refreshes_aggregations
    skip
  end

  def test_gps_equality
    assert_equal GpsLocation.new('39x110'), GpsLocation.new('39x110')
  end

  def test_gps_inequality
    assert_not_equal GpsLocation.new('39x110'), GpsLocation.new('39x111')
  end

  def test_allow_nil_gps_is_nil
    assert_nil customers(:zaphod).gps_location
  end

  def test_allow_nil_gps_set_to_nil
    customers(:david).gps_location = nil
    customers(:david).save
    customers(:david).reload
    assert_nil customers(:david).gps_location
  end

  def test_allow_nil_set_address_attributes_to_nil
    customers(:zaphod).address = nil
    assert_nil customers(:zaphod).attributes[:address_street]
    assert_nil customers(:zaphod).attributes[:address_city]
    assert_nil customers(:zaphod).attributes[:address_country]
  end

  def test_allow_nil_address_set_to_nil
    customers(:zaphod).address = nil
    customers(:zaphod).save
    customers(:zaphod).reload
    assert_nil customers(:zaphod).address
  end

  def test_nil_raises_error_when_allow_nil_is_false
    assert_raise(NoMethodError) { customers(:david).balance = nil }
  end

  def test_allow_nil_address_loaded_when_only_some_attributes_are_nil
    customers(:zaphod).address_street = nil
    customers(:zaphod).save
    customers(:zaphod).reload
    assert_kind_of Address, customers(:zaphod).address
    assert_nil customers(:zaphod).address.street
  end

  def test_nil_assignment_results_in_nil
    customers(:david).gps_location = GpsLocation.new('39x111')
    assert_not_nil customers(:david).gps_location
    customers(:david).gps_location = nil
    assert_nil customers(:david).gps_location
  end

  def test_custom_constructor
    assert_equal 'Barney GUMBLE', customers(:barney).fullname.to_s
    assert_kind_of Fullname, customers(:barney).fullname
  end

  def test_custom_converter
    customers(:barney).fullname = 'Barnoit Gumbleau'
    assert_equal 'Barnoit GUMBLEAU', customers(:barney).fullname.to_s
    assert_kind_of Fullname, customers(:barney).fullname
  end
end


