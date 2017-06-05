require 'roda/contrib/action'

module RodaContrib
  module Plugins
    # The +multi_dispatch+ plugin let you process the your request in a
    # different context rather than the main roda app. It borrows a lot of code
    # from the official +multi_route+ plugin.
    #
    # === Rationals
    # The original rational behind it is simple: avoiding huge interface which
    # is hard to maintain. The reason why this approach is viable is that
    # all routing methods lives within the +Roda::RodaRequest+ class. Thus,
    # wherever you can access the request object, you can route and proceed
    # your request.
    #
    # === Features
    # The +RodaContrib+ ships a mixin to make the plugin work. You can also use
    # this plugin in a more object oriented way.
    #
    # Just like +multi_route+ plugin support namespaced routes, +multi_dispatch+
    # plugin support namespace but a bit differently. Also there can be an
    # extra block pass to the +multi_dispatch+ method to handle requests not
    # handled by dispatchers.
    #
    # === Things you should take care of
    # The +multi_dispatch+ plugin should work fine with most of other plugins.
    # The +render+ plugin is an exception, for it is evaluated in the roda app
    # instance. You should either specify the scope option explicitly or use
    # the +view_options+ plugin to set the scope in the routing tree before you
    # render anything.
    #
    # There is one more thing you should pay attention to. You should always
    # define dispatch after you load all the plugins and the helper mixins into
    # your class.
    #
    # === Example
    #   class App < Roda
    #     plugin :contrib_multi_dispatch
    #
    #     # define dispatchers
    #     dispatch 'hello' do
    #       def say_hello
    #         'hello'
    #       end
    #
    #       route do |r|
    #         r.get do
    #           say_hello
    #         end
    #       end
    #     end
    #
    #     dispatch 'hi' do
    #       # we can define method with the same name in different dispatchers
    #       def say_hello
    #         'said hi instead of hello'
    #       end
    #
    #       route do |r|
    #         r.get do
    #           say_hello
    #         end
    #       end
    #     end
    #
    #     # namespaced dispatcher
    #     dispatch 'yarn', namespace: 'somebody' do
    #       def yarn
    #         'somebody yarned'
    #       end
    #
    #       route do |r|
    #         r.get do
    #           yarn
    #         end
    #       end
    #     end
    #
    #     # class based dispatcher
    #     class SayGoodbye
    #       include ::RodaContrib::Action
    #
    #       def say_good_bye
    #         'goodbye'
    #       end
    #
    #       route do |r|
    #         r.get do
    #           say_good_bye
    #         end
    #       end
    #     end
    #
    #     dispatch 'goodbye', to: SayGoodbye
    #
    #     route do |r|
    #       # dispatch request without namespace
    #       r.multi_dispatch
    #
    #       r.on 'somebody' do
    #         # dispatch namespaced dispatchers
    #         r.multi_dispatch('somebody')
    #       end
    #     end
    #   end
    #
    # the example above shows you how to add dispatchers, how to use namespaced
    # dispatchers, how to use class based dispatchers, how to dispatch request
    # to dispatchers.
    module MultiDispatch
      def self.configure(app)
        app.opts[:namespaced_dispatchers] ||= {}
        app::RodaRequest.instance_variable_set(:@namespaced_dispatchers_regexps, {})
        app.opts[:namespaced_dispatchers].each do |ns, dispatchers|
          app::RodaRequest.build_named_dispatcher_regexp!(ns)
        end
      end

      module ClassMethods
        def freeze
          opts[:namespaced_dispatchers].freeze
          opts[:namespaced_dispatchers].each_value(&:freeze)
          super
        end

        def inherited(subclass)
          super
          sub_ndps = subclass.opts[:namespaced_dispatchers] = {}
          opts[:namespaced_dispatchers].each do |k1, v1|
            sub_ndps[k1] = {}
            v1.each do |k2, v2|
              sub_ndps[k1][k2] = v2.dup
            end
          end
          subclass::RodaRequest.instance_variable_set(:@namespaced_dispatchers_regexps, {})
          sub_ndps.each { |k, v| subclass::RodaRequest.build_named_dispatcher_regexp!(k) }
        end

        def named_dispathers(namespace=nil)
          targets = opts[:namespaced_dispatchers][namespace]
          targets ? targets.keys : []
        end

        def named_dispatcher(name, namespace=nil)
          opts[:namespaced_dispatchers][namespace][name]
        end

        def dispatch(name, namespace: nil, to: nil, &block)
          opts[:namespaced_dispatchers][namespace] ||= {}

          if dispatcher = opts[:namespaced_dispatchers][namespace][name]
            dispatcher.class_eval(&block)
          elsif to.nil?
            roda_app = self
            dispatcher = Class.new do
              include ::RodaContrib::Action
              define_delegators(roda_app)
              class_eval(&block)
            end
          else
            to.define_delegators(self)
          end

          opts[:namespaced_dispatchers][namespace][name] = dispatcher || to
          self::RodaRequest.clear_named_dispatcher_regexp!(namespace)
          self::RodaRequest.build_named_dispatcher_regexp!(namespace)
        end
      end

      module RequestClassMethods
        def clear_named_dispatcher_regexp!(namespace=nil)
          @namespaced_dispatchers_regexps.delete(namespace)
        end

        def build_named_dispatcher_regexp!(namespace=nil)
          @namespaced_dispatchers_regexps[namespace] = /(#{Regexp.union(dispatcher_ary(namespace))})/
        end

        def named_dispatcher_regexp(namespace=nil)
          @namespaced_dispatchers_regexps[namespace]
        end

        private
        def dispatcher_ary(namespace)
          roda_class.named_dispathers(namespace).select{ |s| s.is_a?(String) }.sort.reverse
        end
      end

      module RequestMethods
        def multi_dispatch(namespace=nil)
          on self.class.named_dispatcher_regexp(namespace) do |section|
            r = dispatch(section, namespace: namespace)
            if block_given?
              yield
            else
              r
            end
          end
        end

        def dispatch(name, namespace: nil)
          dispatcher = roda_class.named_dispatcher(name, namespace)
          dispatcher.new(scope).finish
        end
      end
    end
  end
end
