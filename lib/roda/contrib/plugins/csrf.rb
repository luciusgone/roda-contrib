require 'rack/csrf'

module RodaContrib
  module Plugins
    # The contrib_csrf plugin is a bit different from offical csrf plugin. It
    # offers only one instance methods instead of five. It is just my personal
    # flavor.
    #
    # You can use it like this:
    #   # in the routing tree
    #   csrf.field         # equivalent to offical csrf_field
    #   csrf.header        # equivalent to offical csrf_header
    #   csrf.metatag({})   # equivalent to offical csrf_metatag({})
    #   csrf.tag           # equivalent to offical csrf_tag
    #   csrf.token         # equivalent to offical csrf_token
    #
    # see alse Roda offical csrf plugin documentations
    module Csrf
      CSRF = ::Rack::Csrf

      def self.configure(app, opts={})
        return if opts[:skip_middleware]
        app.instance_exec do
          @middleware.each do |(mid, *rest), _|
            if mid.equal?(CSRF)
              rest[0].merge!(opts)
              build_rack_app
              return
            end
          end
          use CSRF, opts
        end
      end

      module InstanceMethods
        class CsrfDecorator
          def initialize(env)
            @env = env
          end

          def field
            CSRF.field
          end

          def header
            CSRF.header
          end

          def metatag(opts={})
            CSRF.metatag(@env, opts)
          end

          def tag
            CSRF.tag(@env)
          end

          def token
            CSRF.token(@env)
          end
        end

        def csrf
          @_csrf ||= CsrfDecorator.new(env)
        end
      end
    end
  end
end
