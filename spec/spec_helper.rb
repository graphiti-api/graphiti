$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'jsonapi_spec_helpers'
require 'rails'

require 'kaminari'
require 'active_record'
require 'active_model_serializers'
require File.expand_path(File.join(File.dirname(__FILE__), "./support/basic_rails_app"))
require 'rspec/rails'
require 'database_cleaner'

require 'jsonapi_compliable'

::Rails.application = BasicRailsApp.generate

RSpec.configure do |config|
  config.include JsonapiSpecHelpers

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

ActiveModel::Serializer.config.adapter = :json_api

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
  self.abstract_class = true
end

class State < ApplicationRecord
  has_many :books
end

class Author < ApplicationRecord
  belongs_to :state
  has_many :books
  accepts_nested_attributes_for :books
  accepts_nested_attributes_for :state
end

class Genre < ApplicationRecord
  has_many :books
  accepts_nested_attributes_for :books
end

class Tag < ApplicationRecord
  belongs_to :book
  accepts_nested_attributes_for :book
end

class Book < ApplicationRecord
  belongs_to :author
  belongs_to :genre
  has_many :tags

  accepts_nested_attributes_for :author
  accepts_nested_attributes_for :genre
  accepts_nested_attributes_for :tags
end

class ApplicationSerializer < ActiveModel::Serializer
  include JsonapiAmsExtensions
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

JsonapiSpecHelpers::Payload.register(:book) do
  key(:title)
end

JsonapiSpecHelpers::Payload.register(:genre) do
  key(:name)
end
