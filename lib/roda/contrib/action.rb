require 'forwardable'
require 'roda/contrib/action/dispatchable'

module RodaContrib
  # The mixin is intended to use with the multi_dispatch plugin. It ships with
  # Dispatchable module by default. Currently, it will load all modules defined
  # under the RodaContrib::Action module
  #
  # If you want to use this mixin seperately, you must define the delegators
  # properly:
  #
  #   SomeDispathcer.define_delegators(RodaApp)
  #
  # Examples:
  #   see the multi_dispatch plugin
  module Action
    def self.included(base)
      mod = self

      base.class_eval do
        extend ::Forwardable

        mod.constants.each do |k|
          c = mod.const_get(k)
          include c if c.is_a? Module
        end
      end
    end
  end
end
