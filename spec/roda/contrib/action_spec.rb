require 'roda/contrib/action'

describe RodaContrib::Action do
  it 'extend the class with forwardable when included' do
    dispatcher = Class.new do
      include ::RodaContrib::Action
    end

    expect(dispatcher.ancestors).to include ::Forwardable
    expect(dispatcher).to respond_to :def_delegators
  end

  it 'should automatically pick up modules defined under action module' do
    module RodaContrib::Action
      remove_const Actionable if defined? Actionable
    end

    dispatcher1 = Class.new do
      include ::RodaContrib::Action
    end

    module RodaContrib::Action
      module Actionable; end
    end

    dispatcher2 = Class.new do
      include ::RodaContrib::Action
    end

    expect(dispatcher1.ancestors).not_to include ::RodaContrib::Action::Actionable
    expect(dispatcher2.ancestors).to include ::RodaContrib::Action::Actionable
  end
end
