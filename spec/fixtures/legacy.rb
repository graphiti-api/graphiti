ActiveRecord::Schema.define(:version => 1) do
  create_table :authors do |t|
    t.boolean :active, default: true
    t.string :first_name
    t.string :last_name
    t.string :dwelling_type
    t.integer :state_id
    t.integer :dwelling_id
    t.integer :organization_id
    t.timestamps
  end

  create_table :organizations do |t|
    t.string :name
    t.integer :parent_id
  end

  create_table :author_hobbies do |t|
    t.integer :author_id
    t.integer :hobby_id
  end

  create_table :hobbies do |t|
    t.string :name
  end

  create_table :condos do |t|
    t.integer :state_id
    t.string :name
  end

  create_table :houses do |t|
    t.integer :state_id
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

class LegacyApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class State < LegacyApplicationRecord
  has_many :books
end

class Author < LegacyApplicationRecord
  belongs_to :dwelling, polymorphic: true
  belongs_to :state
  belongs_to :organization
  has_many :books
  has_many :author_hobbies
  has_many :hobbies, through: :author_hobbies
  has_one :bio
  accepts_nested_attributes_for :books
  accepts_nested_attributes_for :state
end

class Organization < LegacyApplicationRecord
  belongs_to :parent, class_name: 'Organization', foreign_key: :parent_id
  has_many :children, class_name: 'Organization', foreign_key: :parent_id
end

class Condo < LegacyApplicationRecord
  has_many :authors, as: :dwelling
  belongs_to :state
end

class House < LegacyApplicationRecord
  has_many :authors, as: :dwelling
  belongs_to :state
end

class AuthorHobby < LegacyApplicationRecord
  belongs_to :author
  belongs_to :hobby
end

class Hobby < LegacyApplicationRecord
  has_many :author_hobbies
  has_many :authors, through: :author_hobbies
end

class Bio < LegacyApplicationRecord
  belongs_to :author
end

class Genre < LegacyApplicationRecord
  has_many :books
  accepts_nested_attributes_for :books
end

class Tag < LegacyApplicationRecord
  belongs_to :book
  accepts_nested_attributes_for :book
end

class Book < LegacyApplicationRecord
  belongs_to :author
  belongs_to :genre
  has_many :tags

  accepts_nested_attributes_for :author
  accepts_nested_attributes_for :genre
  accepts_nested_attributes_for :tags
end

class LegacySerializableAbstract < JSONAPI::Serializable::Resource
end

class SerializableAuthor < LegacySerializableAbstract
  type 'authors'

  attribute :first_name
  attribute :last_name

  belongs_to :dwelling
  belongs_to :state
  belongs_to :organization
  has_many :books
  has_many :hobbies
  has_one :bio
end

class SerializableOrganization < LegacySerializableAbstract
  type 'organizations'

  attribute :name

  has_many :children
  belongs_to :parent
end

class SerializableDwelling < LegacySerializableAbstract
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

  belongs_to :state
end

class SerializableHouse < SerializableDwelling
  type 'houses'

  attribute :house_description do
    'house desc'
  end

  extra_attribute :house_price do
    1_000_000
  end

  belongs_to :state
end

class SerializableHobby < LegacySerializableAbstract
  type 'hobbies'

  attribute :name
  attribute :description do
    'hobby desc'
  end
  extra_attribute :reason do
    'hobby reason'
  end
end

class SerializableBio < LegacySerializableAbstract
  type 'bios'

  attribute :description
  attribute :picture
  extra_attribute :created_at do
    Time.now
  end
end

class SerializableState < LegacySerializableAbstract
  type 'states'

  attribute :name
  attribute :abbreviation do
    'abbr'
  end

  extra_attribute :population do
    10_000
  end
end

class SerializableTag < LegacySerializableAbstract
  type 'tags'

  attribute :name
  belongs_to :book
end

class SerializableGenre < LegacySerializableAbstract
  type 'genres'

  attribute :name
  has_many :books
end

class SerializableBook < LegacySerializableAbstract
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
class RSpec::Mocks::SerializableDouble < LegacySerializableAbstract
  type 'doubles'

  id { rand(99999) }
end
