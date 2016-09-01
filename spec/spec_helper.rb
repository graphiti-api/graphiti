$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require File.expand_path("../dummy/config/environment.rb", __FILE__)
require 'rspec/rails'
require 'support/json_api_helper'


RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
  config.include JSONAPIHelper

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
ActiveRecord::Base.raise_in_transactional_callbacks = true

ActiveRecord::Schema.define(:version => 1) do
  create_table :authors do |t|
    t.string :first_name
    t.string :last_name
    t.integer :state_id
    t.timestamps
  end

  create_table :genres do |t|
    t.string :name
    t.timestamps
  end

  create_table :books do |t|
    t.string :title
    t.integer :genre_id
    t.integer :author_id
    t.timestamps
  end

  create_table :states do |t|
    t.string :name
    t.timestamps
  end

  create_table :tags do |t|
    t.string :name
    t.integer :book_id
    t.timestamps
  end
end

class ApplicationRecord < ActiveRecord::Base
  include NestedAttributeReassignable
  self.abstract_class = true
end

class State < ApplicationRecord
  has_many :books
end

class Author < ApplicationRecord
  belongs_to :state
  has_many :books
  reassignable_nested_attributes_for :books
  reassignable_nested_attributes_for :state
end

class Genre < ApplicationRecord
  has_many :books
  reassignable_nested_attributes_for :books
end

class Tag < ApplicationRecord
  belongs_to :book
  reassignable_nested_attributes_for :book
end

class Book < ApplicationRecord
  belongs_to :author
  belongs_to :genre
  has_many :tags

  reassignable_nested_attributes_for :author
  reassignable_nested_attributes_for :genre
  reassignable_nested_attributes_for :tags
end

class ApplicationSerializer < ActiveModel::Serializer
  def self.extra_attribute(name)
    attribute name, if: :"allow_#{name}?"

    define_method :"allow_#{name}?" do
      if extra_fields = instance_options[:extra_fields]
        klass = ActiveModelSerializers::Adapter::JsonApi::ResourceIdentifier
        resource_object = klass.new(self, {}).as_json
        if extra_fields = extra_fields[resource_object[:type].to_sym]
          extra_fields.include?(name)
        end
      end
    end
  end

  def self.extra_attributes(*names)
    names.each do |name|
      extra_attribute name
    end
  end
end

class AuthorSerializer < ApplicationSerializer 
  attributes :first_name, :last_name
  belongs_to :state
  has_many :books
end

class StateSerializer < ApplicationSerializer 
  attributes :name
end

class TagSerializer < ApplicationSerializer 
  attributes :name
  belongs_to :book
end

class GenreSerializer < ApplicationSerializer 
  attributes :name
  has_many :books
end

class BookSerializer < ApplicationSerializer 
  attributes :title
  belongs_to :genre
  belongs_to :author
  has_many :tags
end

ActiveModel::Serializer.config.adapter = :json_api