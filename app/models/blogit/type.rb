module Blogit
  class Type < ActiveRecord::Base
    has_many :posts
    self.table_name = "blog_post_types"

    validates_presence_of :name
    validates_uniqueness_of :name

    attr_accessible :name

    def self.to_options
      order('id').map { |t| [t.name, t.id] }
    end
  end
end
