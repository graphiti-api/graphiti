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

  ## test non-standard table name
  create_table :author_hobby do |t|
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
    t.integer :state_id
    t.string :name
  end

  create_table :bios do |t|
    t.integer :author_id
    t.string :description
    t.string :picture
  end

  create_table :bio_labels do |t|
    t.integer :bio_id
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

  #create_table :tags do |t|
    #t.string :name
    #t.integer :book_id
    #t.timestamps
  #end
end

module Legacy
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  class State < ApplicationRecord
    has_many :books
  end

  class Author < ApplicationRecord
    belongs_to :dwelling, polymorphic: true
    belongs_to :state
    belongs_to :organization
    has_many :books
    has_many :author_hobbies
    has_many :hobbies, through: :author_hobbies
    has_one :bio
  end

  class Organization < ApplicationRecord
    belongs_to :parent, class_name: 'Organization', foreign_key: :parent_id
    has_many :children, class_name: 'Organization', foreign_key: :parent_id
  end

  class Condo < ApplicationRecord
    has_many :authors, as: :dwelling
  end

  class House < ApplicationRecord
    has_many :authors, as: :dwelling
    belongs_to :state
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
    has_many :bio_labels
  end

  class BioLabel < ApplicationRecord
    belongs_to :bio
  end

  class Genre < ApplicationRecord
    has_many :books
  end

  #class Tag < LegacyApplicationRecord
    #belongs_to :book
  #end

  class Book < ApplicationRecord
    belongs_to :author
    belongs_to :genre
    #has_many :tags
  end

  class LegacyApplicationSerializer < JSONAPI::Serializable::Resource
  end

  class ApplicationResource < JsonapiCompliable::Resource
    self.adapter = JsonapiCompliable::Adapters::ActiveRecord::Base.new
    self.abstract_class = true
  end

  class GenreResource < ApplicationResource
    attribute :name, :string
  end

  class BookResource < ApplicationResource
    attribute :author_id, :integer, only: :filterable

    attribute :title, :string
    attribute :pages, :integer do
      500
    end

    extra_attribute :alternate_title, :string do
      'alt title'
    end

    belongs_to :genre
  end

  class StateResource < ApplicationResource
    attribute :name, :string
    attribute :abbreviation, :string do
      'abbr'
    end

    extra_attribute :population, :integer do
      10_000
    end
  end

  class BioLabelResource < ApplicationResource
    attribute :bio_id, :integer, only: [:filterable]
  end

  class BioResource < ApplicationResource
    attribute :author_id, :integer, only: [:filterable]
    attribute :description, :string
    attribute :picture, :string

    extra_attribute :created_at, :datetime do
      Time.now
    end

    has_many :bio_labels do
      # Ensure if we get too many bios/labels, they
      # will still come back in the response.
      assign do |bios, labels|
        bios.each do |b|
          b.bio_labels = labels
        end
      end
    end
  end

  class HobbyResource < ApplicationResource
    attribute :name, :string
    attribute :description, :string do
      'hobby desc'
    end
    extra_attribute :reason, :string do
      'hobby reason'
    end
  end

  class HouseResource < ApplicationResource
    attribute :name, :string

    attribute :house_description, :string do
      'house desc'
    end

    extra_attribute :house_price, :integer do
      1_000_000
    end

    belongs_to :state
  end

  class CondoResource < ApplicationResource
    attribute :name, :string

    attribute :condo_description, :string do
      'condo desc'
    end

    extra_attribute :condo_price, :integer do
      500_000
    end
  end

  class OrganizationResource < ApplicationResource
    attribute :parent_id, :integer, only: [:filterable]
    attribute :name, :string

    has_many :children,
      resource: OrganizationResource
    belongs_to :parent,
      resource: OrganizationResource
  end

  class AuthorResource < ApplicationResource
    attribute :first_name, :string

    # todo autostats
    allow_stat total: [:count]

    has_many :books
    belongs_to :state
    belongs_to :organization
    has_one :bio
    many_to_many :hobbies

    polymorphic_belongs_to :dwelling do
      group_by(:dwelling_type) do
        on(:"Legacy::House")
        on(:"Legacy::Condo")
      end
    end
  end
end
