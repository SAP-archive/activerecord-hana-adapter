require 'cases/hana_helper'
require 'cases/base_test'

class BasicsTest < ActiveRecord::TestCase

	def test_all_with_conditions
		if ::ActiveRecord::VERSION::MAJOR >= 4
			named_scope :ordered, :conditions => { :order => '"id" desc' }
			assert_equal Developer.ordered.all, Developer.order('"id" desc').all
		else
    			assert_equal Developer.find(:all, :order => '"id" desc'), Developer.order('"id" desc').all
		end
  end

 	def test_big_decimal_conditions
    m = NumericData.new(
      :bank_balance => 1586.43,
      :big_bank_balance => BigDecimal("1000234000567.95"),
      :world_population => 6000000000,
      :my_house_population => 3
    )
    assert m.save
    assert_equal 0, NumericData.where('"bank_balance > ?"', 2000.0).count
  end

  def test_limit_should_allow_sql_literal
		skip
  end

	def test_find_last
    last  = Developer.find :last
    assert_equal last, Developer.find(:first, :order => '"id" desc')
  end

  def test_inspect_limited_select_instance
    assert_equal %(#<Topic id: 1>), Topic.find(:first, :select => '"id"', :conditions => '"id" = 1').inspect
    assert_equal %(#<Topic id: 1, title: "The First Topic">), Topic.find(:first, :select => '"id", "title"', :conditions => '"id" = 1').inspect
  end

	def test_last
    assert_equal Developer.find(:first, :order => '"id" desc'), Developer.last
  end

	def test_load
    topics = Topic.find(:all, :order => '"id"')
    assert_equal(4, topics.size)
    assert_equal(topics(:first).title, topics.first.title)
  end

  def test_load_with_condition
    topics = Topic.find(:all, :conditions => '"author_name" = \'Mary\'')

    assert_equal(1, topics.size)
    assert_equal(topics(:second).title, topics.first.title)
  end

  def test_quoting_arrays
    replies = Reply.find(:all, :conditions => [ '"id" IN (?)', topics(:first).replies.collect(&:id) ])
    assert_equal topics(:first).replies.size, replies.size

    replies = Reply.find(:all, :conditions => [ '"id" IN (?)', [] ])
    assert_equal 0, replies.size
  end

	def test_count_with_join
    res = Post.count_by_sql 'SELECT COUNT(*) FROM "posts" LEFT JOIN "comments" ON "posts"."id"="comments"."post_id" WHERE "posts"."#{QUOTED_TYPE}" = \'Post\''
	if ::ActiveRecord::VERSION::MAJOR >= 4
		named_scope :filter,{:conditions => '"posts".#{QUOTED_TYPE} = \'Post\'', 
					:joins => 'LEFT JOIN "comments" ON "posts"."id"="comments"."post_id"'}
		res2 = Post.filter.count
	else
    		res2 = Post.count(:conditions => '"posts".#{QUOTED_TYPE} = \'Post\'', :joins => 'LEFT JOIN "comments" ON "posts"."id"="comments"."post_id"')
		end
    assert_equal res, res2

    res3 = nil
    assert_nothing_raised do
	if ::ActiveRecord::VERSION::MAJOR >= 4
		named_scope :filter,{:conditions => '"posts".#{QUOTED_TYPE} = \'Post\'',
                        :joins => 'LEFT JOIN "comments" ON "posts"."id"="comments"."post_id"'}
		res3 = Post.filter.count
	else
      		res3 = Post.count(:conditions => '"posts".#{QUOTED_TYPE} = \'Post\'',
                        :joins => 'LEFT JOIN "comments" ON "posts"."id"="comments"."post_id"')
		end
    end
    assert_equal res, res3

    res4 = Post.count_by_sql 'SELECT COUNT(p."id") FROM "posts" p, "comments" co WHERE p.#{QUOTED_TYPE} = \'Post\' AND p."id"=co."post_id"'
    res5 = nil
    assert_nothing_raised do
	if ::ActiveRecord::VERSION::MAJOR >= 4
		named_scope :filter,{:conditions => 'p.#{QUOTED_TYPE} = \'Post\' AND p."id"=co."post_id"',
                        :joins => 'p, "comments" co',
                        :select => 'p."id"'}
		res5 = Post.filter.count
	else
      		res5 = Post.count(:conditions => 'p.#{QUOTED_TYPE} = \'Post\' AND p."id"=co."post_id"',
                        :joins => 'p, "comments" co',
                        :select => 'p."id"')
		end
    end

    assert_equal res4, res5

    res6 = Post.count_by_sql 'SELECT COUNT(DISTINCT p."id") FROM "posts" p, "comments" co WHERE p.#{QUOTED_TYPE} = \'Post\' AND p."id"=co."post_id"'
    res7 = nil
    assert_nothing_raised do
	if ::ActiveRecord::VERSION::MAJOR >= 4
		named_scope :filter,{:conditions => 'p.#{QUOTED_TYPE} = \'Post\' AND p."id"=co."post_id"',
                        :joins => 'p, "comments" co',
                        :select => 'p."id"'}
		res7 = Post.distinct.filter.count
	else
      		res7 = Post.count(:conditions => 'p.#{QUOTED_TYPE} = \'Post\' AND p."id"=co."post_id"',
                        :joins => 'p, "comments" co',
                        :select => 'p."id"',
                        :distinct => true)
		end
    end
    assert_equal res6, res7
  end

 	def test_scoped_find_conditions
    scoped_developers = Developer.send(:with_scope, :find => { :conditions => '"salary" > 90000' }) do
      Developer.find(:all, :conditions => '"id" < 5')
    end
    assert !scoped_developers.include?(developers(:david)) # David's salary is less than 90,000
    assert_equal 3, scoped_developers.size
  end

	def test_scoped_find_limit_offset
    scoped_developers = Developer.send(:with_scope, :find => { :limit => 3, :offset => 2 }) do
      Developer.find(:all, :order => '"id"')
    end
    assert !scoped_developers.include?(developers(:david))
    assert !scoped_developers.include?(developers(:jamis))
    assert_equal 3, scoped_developers.size

    # Test without scoped find conditions to ensure we get the whole thing
    developers = Developer.find(:all, :order => '"id"')
    assert_equal Developer.count, developers.size
  end

  def test_scoped_find_order
    # Test order in scope
    scoped_developers = Developer.send(:with_scope, :find => { :limit => 1, :order => '"salary" DESC' }) do
      Developer.find(:all)
    end
    assert_equal 'Jamis', scoped_developers.first.name
    assert scoped_developers.include?(developers(:jamis))
    # Test scope without order and order in find
    scoped_developers = Developer.send(:with_scope, :find => { :limit => 1 }) do
      Developer.find(:all, :order => '"salary" DESC')
    end
    # Test scope order + find order, order has priority
    scoped_developers = Developer.send(:with_scope, :find => { :limit => 3, :order => '"id" DESC' }) do
      Developer.find(:all, :order => '"salary" ASC')
    end
    assert scoped_developers.include?(developers(:poor_jamis))
    assert ! scoped_developers.include?(developers(:david))
    assert ! scoped_developers.include?(developers(:jamis))
    assert_equal 3, scoped_developers.size

    # Test without scoped find conditions to ensure we get the right thing
    assert ! scoped_developers.include?(Developer.find(1))
    assert scoped_developers.include?(Developer.find(11))
  end

 	def test_scoped_find_limit_offset_including_has_many_association
    topics = Topic.send(:with_scope, :find => {:limit => 1, :offset => 1, :include => :replies}) do
      Topic.find(:all, :order => '"topics"."id"')
    end
    assert_equal 1, topics.size
    assert_equal 2, topics.first.id
  end

	def test_scoped_find_order_including_has_many_association
    developers = Developer.send(:with_scope, :find => { :order => '"developers"."salary" DESC', :include => :projects }) do
      Developer.find(:all)
    end
    assert developers.size >= 2
    for i in 1...developers.size
      assert developers[i-1].salary >= developers[i].salary
    end
  end

	def test_scoped_find_with_group_and_having
    developers = Developer.send(:with_scope, :find => { :group => '"developers"."salary"', :having => 'SUM("salary") > 10000', :select => 'SUM("salary") as salary' }) do
      Developer.find(:all)
    end
    assert_equal 3, developers.size
  end

	def test_find_ordered_last
    last  = Developer.find :last, :order => '"developers"."salary" ASC'
    assert_equal last, Developer.find(:all, :order => '"developers"."salary" ASC').last
  end

  def test_find_reverse_ordered_last
    last  = Developer.find :last, :order => '"developers"."salary" DESC'
    assert_equal last, Developer.find(:all, :order => '"developers"."salary" DESC').last
  end

  def test_find_multiple_ordered_last
    last  = Developer.find :last, :order => '"developers"."name", "developers"."salary" DESC'
    assert_equal last, Developer.find(:all, :order => '"developers"."name", "developers"."salary" DESC').last
  end

  def test_find_keeps_multiple_order_values
    combined = Developer.find(:all, :order => '"developers"."name", "developers"."salary"')
    assert_equal combined, Developer.find(:all, :order => ['"developers"."name"', '"developers"."salary"'])
  end

 	def test_find_keeps_multiple_group_values
    combined = Developer.find(:all, :group => '"developers"."name", "developers"."salary", "developers"."id", "developers"."created_at", "developers"."updated_at"')
    assert_equal combined, Developer.find(:all, :group => ['"developers"."name"', '"developers"."salary"', '"developers"."id"', '"developers"."created_at"', '"developers"."updated_at"'])
  end

	def test_find_scoped_ordered_last
    last_developer = Developer.send(:with_scope, :find => { :order => '"developers"."salary" ASC' }) do
      Developer.find(:last)
    end
    assert_equal last_developer, Developer.find(:all, :order => '"developers"."salary" ASC').last
  end

	def test_assert_queries
    query = lambda { ActiveRecord::Base.connection.execute 'select count(*) from "developers"' }
    assert_queries(2) { 2.times { query.call } }
    assert_queries 1, &query
    assert_no_queries { assert true }
  end

	class DeveloperCalledDavid < ActiveRecord::Base
		self.table_name = 'developers'
  	default_scope {where("\"name\" = 'David'")}
	end

  def test_reload_with_exclusive_scope
    dev = DeveloperCalledDavid.first
    dev.update_attributes!( :name => "NotDavid" )
    assert_equal dev, dev.reload
  end

  def test_readonly_attributes
    skip
  end

	class HanaTopic < Topic
		def destroy_children
      self.class.delete_all "\"parent_id\" = #{id}"
    end
	end

  def test_equality_of_destroyed_records
    topic_1 = HanaTopic.new(:title => 'test_1')
    topic_1.save
    topic_2 = HanaTopic.find(topic_1.id)
    topic_1.destroy
    assert_equal topic_1, topic_2
    assert_equal topic_2, topic_1
  end

	def test_limit_with_comma
  	skip
  end

	def test_create_after_initialize_without_block
    cb = CustomBulb.create(:name => 'Dude')
    assert_equal('Dude', cb.name)
    assert_equal(1, cb.frickinawesome)
  end

	def test_create_after_initialize_with_block
    cb = CustomBulb.create {|c| c.name = 'Dude' }
    assert_equal('Dude', cb.name)
    assert_equal(1, cb.frickinawesome)
  end

	def test_count_with_join
    res = Post.count_by_sql 'SELECT COUNT(*) FROM "posts" LEFT JOIN "comments" ON "posts"."id" = "comments"."post_id" WHERE "posts".' + QUOTED_TYPE + " = 'Post'"

	if ::ActiveRecord::VERSION::MAJOR >= 4
		named_scope :filter,{:conditions => '"posts".' + QUOTED_TYPE + " = 'Post'", :joins => 'LEFT JOIN "comments" ON "posts"."id" = "comments"."post_id"'}
		res2 = Post.filter.count
	else
		res2 = Post.count(:conditions => '"posts".' + QUOTED_TYPE + " = 'Post'", :joins => 'LEFT JOIN "comments" ON "posts"."id" = "comments"."post_id"')
		end    
	assert_equal res, res2

    res3 = nil
    assert_nothing_raised do
	if ::ActiveRecord::VERSION::MAJOR >= 4
		named_scope :filter,{:conditions => '"posts".' + QUOTED_TYPE + " = 'Post'",
                        :joins => 'LEFT JOIN "comments" ON "posts"."id" = "comments"."post_id"'}
		res3 = Post.filter.count
	else
     		res3 = Post.count(:conditions => '"posts".' + QUOTED_TYPE + " = 'Post'",
                        :joins => 'LEFT JOIN "comments" ON "posts"."id" = "comments"."post_id"')
		end
    end
    assert_equal res, res3

    res4 = Post.count_by_sql 'SELECT COUNT(p."id") FROM "posts" p, "comments" co WHERE p.' + QUOTED_TYPE + ' = \'Post\' AND p."id" = co."post_id"'
    res5 = nil
    assert_nothing_raised do
	if ::ActiveRecord::VERSION::MAJOR >= 4
		named_scope :filter,{:conditions => "p." + QUOTED_TYPE + ' = \'Post\' AND p."id" = co."post_id"',
                        :joins => 'p, "comments" co',
                        :select => 'p."id"'}
		res5 = Post.filter.count
	else
      		res5 = Post.count(:conditions => "p." + QUOTED_TYPE + ' = \'Post\' AND p."id" = co."post_id"',
                        :joins => 'p, "comments" co',
                        :select => 'p."id"')
		end
    end

    assert_equal res4, res5

    res6 = Post.count_by_sql 'SELECT COUNT(DISTINCT p."id") FROM "posts" p, "comments" co WHERE p.' + QUOTED_TYPE + ' = \'Post\' AND p."id" = co."post_id"'
    res7 = nil
    assert_nothing_raised do
	if ::ActiveRecord::VERSION::MAJOR >= 4
		named_scope :filter,{:conditions => 'p.' + QUOTED_TYPE + ' = \'Post\' AND p."id" = co."post_id"',
                        :joins => 'p, "comments" co',
                        :select => 'p."id"'}
		res7 = Post.distinct.filter.count
	else
     		 res7 = Post.count(:conditions => 'p.' + QUOTED_TYPE + ' = \'Post\' AND p."id" = co."post_id"',
                        :joins => 'p, "comments" co',
                        :select => 'p."id"',
                        :distinct => true)
		end
    end
    assert_equal res6, res7
  end

	def test_column_names_are_escaped
    conn      = ActiveRecord::Base.connection
    classname = conn.class.name[/[^:]*$/]
    badchar   = {
      'HanaAdapter'    => '"'
    }.fetch(classname) {
      raise "need a bad char for #{classname}"
    }

    quoted = conn.quote_column_name "foo#{badchar}bar"

    assert_equal("#{badchar}foo#{badchar * 2}bar#{badchar}", quoted)
  end

	def test_big_decimal_conditions
    m = NumericData.new(
      :bank_balance => 1586.43,
      :big_bank_balance => BigDecimal("1000234000567.95"),
      :world_population => 6000000000,
      :my_house_population => 3
    )
    assert m.save
    assert_equal 0, NumericData.where('"bank_balance" > ?', 2000.0).count
  end

	def test_attribute_names
    assert_equal ["account_id", "client_of", "description", "firm_id", "firm_name", "id", "name", "rating", "ruby_type", "type"], Company.attribute_names
  end
end

