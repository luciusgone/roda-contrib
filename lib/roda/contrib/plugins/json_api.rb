require 'rack/parser'
require 'jsonapi/serializable'
require 'jsonapi/deserializable'

module RodaContrib
  module Plugins
    # This plugin intergrate Roda with the jsonapi-rb gem. It offers a simple
    # interface to users, but a bit opinioned.
    #
    # === Prerequest
    # To use this plugin, you should install the +rack-parser+ and the
    # +jsonapi-rb+ gem first.
    #
    # === Configuration
    # The +contrib_json_api+ plugin will not complain if you offer nothing to
    # configure the boring middleware.
    #
    #   App.plugin :contrib_json_api
    #
    # You can use options pass to this plugin to configure the +Rack::Parser+.
    #
    #   App.plugin :contrib_json_api, {
    #     :parser => { 'application/json' => proc { |data| MultiJSON.parse(data) } },
    #     :handler => { 'application/json' => proc { |e, t| [400, {'Content-Type' => t}, ["broke"]] }
    #   }
    #
    # Check the rack-parser documentation for more information
    #
    # Optionally, if you already have the rack-parser middleware and don't want
    # to setup the middleware again, you can use +:skip_middleware+ option to
    # do so:
    #
    #  App.plugin :contrib_json_api, skip_middleware: true
    #
    # === Usage
    # The +contrib_json_api+ plugin only expose three methods to use.
    #
    # the +represent+ method is used for rendering the resources
    #   represent rc, with: SerializableRc
    #
    # the +represent_err+ method is used for rendering the errors, if you don't
    # offer a title, 'model field validation error' will be used as title. the
    # status is default to 400.
    #
    #   represent rc.errors, title: 'gateway not reachable', status: 500
    #
    # the +json_params+ method is used to get the parsed data from the request
    # body.
    #
    # a lot of options could be applied to customize the +represent+ and
    # +represent_err+ method. Checkout the official jsonapi-rb documentation:
    # https://jsonapi-rb.org/guides
    #
    # === Exmaple
    #   class App < Roda
    #     plugin :contrib_json_api
    #
    #     route do |r|
    #       r.on 'product' do
    #         r.is :id do |id|
    #           @rc = Product.with_pk(id.to_i)
    #
    #           r.get do
    #             represent @rc, with: SerializableProduct
    #           end
    #
    #           r.post do
    #             @rc.set_fields(json_params)
    #             if @rc.valid?
    #               @rc.save_changes
    #               represent @rc, with: SerializableProduct
    #             else
    #               represent_err @rc.errors
    #             end
    #           end
    #         end
    #       end
    #     end
    #   end
    module JsonApi
      CONTENT_TYPE             = 'Content-Type'.freeze

      JSONAPI_MEDIA_TYPE       = 'application/vnd.api+json'.freeze

      RACK_PASER_PARAMS        = 'rack.parser.result'.freeze

      DEFAULT_JSON_PARSER      = proc { |data| JSON.parse(data) }

      DEFAULT_ERROR_HANDLER    = proc { |err, type|
        e = [SerializableError.new(title: 'invalid JSON doc', err: err, status: 400)]
        msg = JSONAPI::Serializable::ErrorRenderer.render(e, {})
        [400, { CONTENT_TYPE => JSONAPI_MEDIA_TYPE }, [msg]]
      }

      DEFAULT_RACK_PARSER_OPTS = {
        parsers: { JSONAPI_MEDIA_TYPE => DEFAULT_JSON_PARSER },
        handlers: { JSONAPI_MEDIA_TYPE => DEFAULT_ERROR_HANDLER }
      }.freeze

      class SerializableError < JSONAPI::Serializable::Error
        title { @title }
        status { @status }
        detail { @err.is_a?(Exception) ? @err.message : @err }
      end

      def self.configure(app, opts={})
        return if opts[:skip_middleware]

        app.instance_exec do
          @middleware.each do |(mid, *rest), _|
            if mid.equal?(::Rack::Parser)
              rest[0].merge!(opts)
              build_rack_app
              return
            end
          end

          if opts.empty?
            use ::Rack::Parser, DEFAULT_RACK_PARSER_OPTS.dup
            return
          elsif opts[:parsers].nil? || opts[:pasers][JSONAPI_MEDIA_TYPE].nil?
            opts[:parsers] = { JSONAPI_MEDIA_TYPE => DEFAULT_JSON_PARSER }
            use ::Rack::Parser, opts
          end
        end
      end

      module InstanceMethods
        def represent(rc, options={})
          options[:class] = options.delete(:with) unless options[:class]
          rendered = JSONAPI::Serializable::Renderer.render(rc, options)

          response[CONTENT_TYPE] = JSONAPI_MEDIA_TYPE
          response.write(rendered)
          request.halt
        end

        def represent_err(errs, options={})
          t = options.delete(:title) || 'model field validation failed'
          s = options.delete(:status) || 400
          e = if errs.respond_to? :full_messages
                errs.full_messages.map { |err| SerializableError.new(title: t, err: err, status: s) }
              else
                [SerializableError.new(title: t, err: errs, status: s)]
              end
          rendered = JSONAPI::Serializable::ErrorRenderer.render(e, options)

          response.status = s
          response[CONTENT_TYPE] = JSONAPI_MEDIA_TYPE
          response.write(rendered)
          request.halt
        end

        def json_params
          parse_jsonapi env[RACK_PASER_PARAMS]
        end

        private
        def parse_jsonapi(rc, options={})
          klass = options[:with] || JSONAPI::Deserializable::Resource
          begin
            result = klass.call(rc)
          rescue JSONAPI::Parser::InvalidDocument => e
            errs = [SerializableError.new(title: 'Invalid JSONAPI doc', error: e, status: 400)]
            rendered = JSONAPI::Serializable::ErrorRenderer.render(errs, {})

            response.status = 400
            response[CONTENT_TYPE] = JSONAPI_MEDIA_TYPE
            response.write(rendered)
            request.halt
          end
          result
        end
      end
    end
  end
end
