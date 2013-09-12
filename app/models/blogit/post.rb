module Blogit
  class Post < ActiveRecord::Base
    before_save :set_default_type
    before_validation :set_blogger

    require "acts-as-taggable-on"
    require "kaminari"

    include ::ActionView::Helpers::TextHelper

    acts_as_taggable

    self.table_name = "blog_posts"

    self.paginates_per Blogit.configuration.posts_per_page

    # ==============
    # = Attributes =
    # ==============
    attr_accessible :title, :body, :tag_list, :blogger_type, :blogger_id, :type_id, :type

    def short_body
      truncate(body, length: 400, separator: "\n")
    end

    # ===============
    # = Validations =
    # ===============

    validates :title, presence: true, length: { minimum: 1, maximum: 66 }
    validates :body,  presence: true, length: { minimum: 10 }
    validates :blogger_id, presence: true

    # =================
    # = Assosciations =
    # =================

    belongs_to :blogger, :polymorphic => true
    belongs_to :type

    has_many :comments, :class_name => "Blogit::Comment"

    def comments
      check_comments_config
      super()
    end
    def comments=(value)
      check_comments_config
      super(value)
    end

    # ==========
    # = Scopes =
    # ==========

    # Returns the blog posts paginated for the index page
    # @scope class
    scope :for_index, lambda { |page_no = 1| order("created_at DESC").page(page_no) }
    scope :paginated_by_type, lambda { |type = 'blog', page_no = 1| for_index(page_no).joins(:type).where("name = ?", type) }

    # ====================
    # = Instance Methods =
    # ====================

    def to_param
      "#{id}-#{title.parameterize}"
    end

    # If there's a current blogger and the display name method is set, returns the blogger's display name
    # Otherwise, returns an empty string
    def blogger_display_name
      if self.blogger and !self.blogger.respond_to?(Blogit.configuration.blogger_display_name_method)
        raise ConfigurationError,
        "#{self.blogger.class}##{Blogit.configuration.blogger_display_name_method} is not defined"
      elsif self.blogger.nil?
        ""
      else
        self.blogger.send Blogit.configuration.blogger_display_name_method
      end
    end

    private

    def check_comments_config
      raise RuntimeError.new("Posts only allow active record comments (check blogit configuration)") unless Blogit.configuration.include_comments == :active_record
    end

    def set_default_type
      if type.blank?
        self.type = Type.find_or_create_by_name(:blog)
      end
    end

    def set_blogger
      if blogger.blank?
        self.blogger = User.find_by_username('admin')
      end
    end
  end
end
