module Blogit

  # Using explicit ::Blogit::ApplicationController fixes NoMethodError 'blogit_authenticate' in
  # the main_app
  class PostsController < ::Blogit::ApplicationController
    load_and_authorize_resource

    # If using Blogit's Create, Update and Destroy actions AND ping_search_engines is
    # set, call ping_search_engines after these requests
    if Blogit.configuration.include_admin_actions
      after_filter :ping_search_engines, only: [:create, :update, :destroy], :if => lambda { Blogit.configuration.ping_search_engines }
    end
    
    # Raise a 404 error if the admin actions aren't to be included
    # We can't use blogit_conf here because it sometimes raises NoMethodError in main app's routes
    unless Blogit.configuration.include_admin_actions
      before_filter :raise_404, except: [:index, :show, :tagged]
    end

    blogit_authenticate(except: [:index, :show, :tagged])

    blogit_cacher(:index, :show, :tagged)
    blogit_sweeper(:create, :update, :destroy)

    def index
      @types = Blogit::Type.all.map(&:name)
      if type = params['type']
        @posts = Post.for_index(params[:page]).joins(:type).where('name = ?', type).per(40)
      else
        @posts = Post.for_index(params[:page]).per(40)
      end
    end

    def show
      @post = Post.find(params[:id])
    end

    def tagged
      @posts = Post.for_index(params[:page]).tagged_with(params[:tag])
      render :index
    end

    def new
      @post = current_blogger.blog_posts.new(params[:post])
    end

    def edit
      @post = Post.find(params[:id])
    end

    def create
      @post = Post.new(params[:post])
      @post.blogger = current_blogger
      if @post.save
        redirect_to @post, notice: t(:blog_post_was_successfully_created, scope: 'blogit.posts')
      else
        render action: "new"
      end
    end

    def update
      @post = Post.find(params[:id])
      if @post.update_attributes(params[:post])
        redirect_to @post, notice: t(:blog_post_was_successfully_updated, scope: 'blogit.posts')
      else
        render action: "edit"
      end
    end

    def destroy
      @post = Blogit::Post.find(params[:id])
      @post.destroy
      redirect_to posts_url, notice: t(:blog_post_was_successfully_destroyed, scope: 'blogit.posts')
    end

    private

    def raise_404
      # Don't include admin actions if include_admin_actions is false
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
    end
    
    
    # @See the Pingr gem for more info https://github.com/KatanaCode/pingr
    def ping_search_engines
      case blogit_conf.ping_search_engines
      when Array
        search_engines = blogit_conf.ping_search_engines
      when true
        search_engines = Pingr::SUPPORTED_SEARCH_ENGINES
      end
      for search_engine in search_engines
        Pingr::Request.new(search_engine, posts_url(format: :xml)).ping
      end
    end

  end

end
