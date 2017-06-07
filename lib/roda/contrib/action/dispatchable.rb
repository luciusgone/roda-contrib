module RodaContrib
  module Action
    # Basic functionalities for +RodaContrib::Action+ mixin
    #
    # The call method is already taken by the roda app, so we have to introduce
    # a new method finish to actually executing the route block.
    module Dispatchable
      def self.included(base)
        base.class_eval do
          include InstanceMethods
          extend ClassMethods
        end
      end

      module InstanceMethods
        def initialize(scope)
          @scope = scope
        end

        attr_reader :scope

        def finish
          blk = self.class.route_block
          instance_exec(request, &blk)
        end
      end

      module ClassMethods
        attr_reader :route_block

        def route(&block)
          @route_block = block
        end

        def define_delegators(app)
          m = app.instance_methods - Object.instance_methods
          def_delegators :@scope, *m
        end
      end
    end
  end
end
