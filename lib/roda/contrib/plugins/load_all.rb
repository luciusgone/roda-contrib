module RodaContrib
  module Plugins
    # the load_all plugin helps to write clean code loading related parts of
    # the main roda app.
    #
    # It favors the +:root+ option of the roda app. If you set the +:root+
    # option before you load this plugin, you can omit the +:root+ option of
    # the plugin.
    #
    # Besides, you can load multiple directories at the same time, if loading
    # order does not matter.
    #
    # === Example
    #   class App < Roda
    #     plugin :contrib_load_all, root: __dir__
    #
    #     # load multiple resources at the same time
    #     load_all :models, :views
    #     # load only one folder
    #     load_all :helpers
    #   end
    #
    # It will immediately load models and helpers files under the defined root
    # dir.
    module LoadAll
      def self.configure(app, opts={})
        raise ArgumentError, 'Invalid root option' unless app.opts[:root] || opts[:root]
        app.opts[:root] = opts[:root] if opts[:root]
      end

      module ClassMethods
        def load_all(*rcs)
          rcs.each do |rc|
            patterns = File.expand_path "./#{rc}/**/*.rb", opts[:root]
            Dir[patterns].each { |f| require f }
          end
          nil
        end
      end
    end
  end
end
