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
    # the +represent_err+ method is used for rendering the errors. The status
    # is default to 400, if you don't offer one. You can rednering model
    # objects or hash.
    #
    #   represent rc, status: 500
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
        e = SerializableError.create(title: 'Invalid JSON Doc Error', detail: err.message, status: 400)
        msg = JSONAPI::Serializable::ErrorRenderer.render(e, {})
        [400, { CONTENT_TYPE => JSONAPI_MEDIA_TYPE }, [msg]]
      }

      DEFAULT_RACK_PARSER_OPTS = {
        parsers: { JSONAPI_MEDIA_TYPE => DEFAULT_JSON_PARSER },
        handlers: { JSONAPI_MEDIA_TYPE => DEFAULT_ERROR_HANDLER }
      }.freeze

      class SerializableError < JSONAPI::Serializable::Error
        def self.create(rc)
          [new(rc)]
        end

        title { @title }
        status { @status }
        detail { @detail }
      end

      class SerializableValidationError < JSONAPI::Serializable::Error
        def self.create(rc)
          rc.errors.full_messages.each_with_object([]) do |msg, errs|
            errs << new(title: 'Validation Error', detail: msg)
          end
        end

        title { @title }
        detail { @detail }
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

        def represent_err(rc, options={})
          if rc.respond_to? :errors
            e = SerializableValidationError.create(rc)
          else
            e = SerializableError.create(rc)
          end
          s = options.delete(:status) || 400
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
            err = SerializableError.create(title: 'Invalid JSONAPI Doc Error', detail: e.message, status: 400)
            rendered = JSONAPI::Serializable::ErrorRenderer.render(err, {})

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
