$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'jsonapi_spec_helpers'
require 'rails'

require 'kaminari'
require 'active_record'
require 'action_controller'

require File.expand_path(File.join(File.dirname(__FILE__), "./support/basic_rails_app"))
require 'rspec/rails'
require 'database_cleaner'

require 'pry'
require 'jsonapi_compliable'
require 'jsonapi_compliable/adapters/null'
require 'jsonapi_compliable/adapters/active_record'

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

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
ActiveRecord::Base.raise_in_transactional_callbacks = true

ActiveRecord::Schema.define(:version => 1) do
  create_table :authors do |t|
    t.string :first_name
    t.string :last_name
    t.string :dwelling_type
    t.integer :state_id
    t.integer :dwelling_id
    t.timestamps
  end

  create_table :author_hobbies do |t|
    t.integer :author_id
    t.integer :hobby_id
  end

  create_table :hobbies do |t|
    t.string :name
  end

  create_table :condos do |t|
    t.string :name
  end

  create_table :houses do |t|
    t.string :name
  end

  create_table :bios do |t|
    t.integer :author_id
    t.string :description
    t.string :picture
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
  belongs_to :dwelling, polymorphic: true
  belongs_to :state
  has_many :books
  has_many :author_hobbies
  has_many :hobbies, through: :author_hobbies
  has_one :bio
  accepts_nested_attributes_for :books
  accepts_nested_attributes_for :state
end

class Condo < ApplicationRecord
  has_many :authors, as: :dwelling
end

class House < ApplicationRecord
  has_many :authors, as: :dwelling
end

class AuthorHobby < ApplicationRecord
  belongs_to :author
  belongs_to :hobby
end

class Hobby < ApplicationRecord
  has_many :author_hobbies
  has_many :authors, through: :author_hobbies
end

class Bio < ApplicationRecord
  belongs_to :author
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

class SerializableAbstract < JSONAPI::Serializable::Resource
end

class SerializableAuthor < SerializableAbstract
  type 'authors'

  attribute :first_name
  attribute :last_name

  belongs_to :dwelling
  belongs_to :state
  has_many :books
  has_many :hobbies
  has_one :bio
end

class SerializableDwelling < SerializableAbstract
  type 'dwellings'

  attribute :name
end

class SerializableCondo < SerializableDwelling
  type 'condos'

  attribute :condo_description do
    'condo desc'
  end

  extra_attribute :condo_price do
    500_000
  end
end

class SerializableHouse < SerializableDwelling
  type 'houses'

  attribute :house_description do
    'house desc'
  end

  extra_attribute :house_price do
    1_000_000
  end
end

class SerializableHobby < SerializableAbstract
  type 'hobbies'

  attribute :name
  attribute :description do
    'hobby desc'
  end
  extra_attribute :reason do
    'hobby reason'
  end
end

class SerializableBio < SerializableAbstract
  type 'bios'

  attribute :description
  attribute :picture
  extra_attribute :created_at do
    Time.now
  end
end

class SerializableState < SerializableAbstract
  type 'states'

  attribute :name
  attribute :abbreviation do
    'abbr'
  end

  extra_attribute :population do
    10_000
  end
end

class SerializableTag < SerializableAbstract
  type 'tags'

  attribute :name
  belongs_to :book
end

class SerializableGenre < SerializableAbstract
  type 'genres'

  attribute :name
  has_many :books
end

class SerializableBook < SerializableAbstract
  type 'books'

  attribute :title

  attribute :pages do
    500
  end

  extra_attribute :alternate_title do
    'alt title'
  end

  belongs_to :genre
  belongs_to :author
  has_many :tags
end

# supports `render jsonapi: double`
class RSpec::Mocks::SerializableDouble < SerializableAbstract
  type 'doubles'

  id { rand(99999) }
end

JsonapiSpecHelpers::Payload.register(:book) do
  key(:title)
end

JsonapiSpecHelpers::Payload.register(:genre) do
  key(:name)
end

class ApplicationController < ActionController::Base
  include JsonapiCompliable

  jsonapi do
    use_adapter JsonapiCompliable::Adapters::ActiveRecord
  end

  prepend_before_action :fix_params!

  private

  # Honestly not sure why this is needed
  # Otherwise params is { params: actual_params }
  def fix_params!
    if Rails::VERSION::MAJOR == 4
      good_params = { action: action_name }.merge(params[:params] || {})
      self.params = ActionController::Parameters.new(good_params.with_indifferent_access)
    end
  end
end
