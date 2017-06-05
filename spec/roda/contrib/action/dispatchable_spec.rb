require 'roda/contrib/action/dispatchable'
require 'roda/contrib/action'


describe RodaContrib::Action::Dispatchable do
  subject { Class.new { include ::RodaContrib::Action; self } }
  let!(:roda_app) { Class.new(Roda) }

  it 'should allow me to bind to a certain roda app' do
    subject.define_delegators(roda_app)

    expect(subject.instance_methods).to include :env
    expect(subject.instance_methods).to include :request
    expect(subject.instance_methods).to include :response
    expect(subject.instance_methods).to include :opts
    expect(subject.instance_methods).to include :session
  end

  it 'should allow me to define a route block' do
    subject.define_delegators(roda_app)
    subject.route { |r| 'hi' }

    dp = subject.new(roda_app.new({}))

    expect(dp.finish).to eql 'hi'
  end
end
