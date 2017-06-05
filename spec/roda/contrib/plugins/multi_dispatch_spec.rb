require 'roda/contrib/plugins/multi_dispatch'
require 'rack/test'

shared_examples 'dispatchers' do
  it 'should work' do
    get '/hello'
    expect(last_response.body).to eql 'hello'
    get '/dwa'
    expect(last_response.body).to eql 'hi'
  end

  it 'should work when freezed' do
    md_app.freeze
    get '/hello'
    expect(last_response.body).to eql 'hello'
    get '/dwa'
    expect(last_response.body).to eql 'hi'
  end

  it 'should work fine when plugin loads before the dispatcher' do
    post '/hello'
    expect(last_response.body).to eql '&lt;a&gt;'
  end

  it 'should handle subclass correctly' do
    app = Class.new(md_app).app
    get '/hello'
    expect(last_response.body).to eql 'hello'
    get '/dwa'
    expect(last_response.body).to eql 'hi'
  end
end

describe RodaContrib::Plugins::MultiDispatch do
  include Rack::Test::Methods

  def app
    md_app.app
  end

  let!(:md_app) { Class.new(Roda) { plugin :contrib_multi_dispatch; self } }
  let!(:goodbye_dispatcher) {
    Class.new do
      include RodaContrib::Action

      def say_goodbye; 'goodbye'; end

      route { |r| r.get { say_goodbye } }
    end
  }

  after { md_app = nil }

  context 'without namespace' do
    before do
      md_app.plugin :h
      md_app.dispatch 'hello' do
        def say_hello; 'hello'; end

        route { |r| r.get { say_hello }; r.post { h('<a>') } }
      end

      md_app.route do |r|
        r.multi_dispatch
        'hi'
      end
    end

    it_behaves_like 'dispatchers'

    it 'should allow me to define method with the same name in different dispatchers' do
      md_app.dispatch 'tada' do
        def say_hello; 'another hello'; end

        route { |r| r.get { say_hello } }
      end

      get '/tada'
      expect(last_response.body).to eql 'another hello'
    end

    it 'should pick up newly add dispatchers' do
      md_app.dispatch 'yarn' do
        route { |r| r.get { 'yarn' } }
      end

      get '/yarn'
      expect(last_response.body).to eql 'yarn'
    end

    it 'should allow me to dispatch to a certain dispatcher' do
      md_app.dispatch 'goodbye', to: goodbye_dispatcher

      get '/goodbye'
      expect(last_response.body).to eql 'goodbye'
    end

    it 'should allow me to reopen the dispatcher class' do
      md_app.dispatch 'hello' do
        def say_hello; 'changed hello'; end
      end

      get 'hello'
      expect(last_response.body).to eql 'changed hello'
    end

    it 'should skip the dispatcher class if it is already defined' do
      md_app.dispatch 'hello', to: goodbye_dispatcher do
        def say_hello; 'changed hello'; end
      end

      get 'hello'
      expect(last_response.body).to eql 'changed hello'
    end
  end

  context 'with namespace' do
    before do
      md_app.plugin :h
      md_app.dispatch 'hello', namespace: 'somebody' do
        def say_hello; 'hello'; end

        route { |r| r.get { say_hello }; r.post { h('<a>') } }
      end

      md_app.route do |r|
        r.multi_dispatch('somebody')
        'hi'
      end
    end

    it_behaves_like 'dispatchers'

    it 'should allow me to define method with the same name in different dispatchers' do
      md_app.dispatch 'tada', namespace: 'somebody' do
        def say_hello; 'another hello'; end

        route { |r| r.get { say_hello } }
      end

      get '/tada'
      expect(last_response.body).to eql 'another hello'
    end

    it 'should pick up newly add dispatchers' do
      md_app.dispatch 'yarn', namespace: 'somebody' do
        route { |r| r.get { 'yarn' } }
      end

      get '/yarn'
      expect(last_response.body).to eql 'yarn'
    end

    it 'should allow me to dispatch to a certain dispatcher' do
      md_app.dispatch 'goodbye', to: goodbye_dispatcher, namespace: 'somebody'

      get '/goodbye'
      expect(last_response.body).to eql 'goodbye'
    end

    it 'should allow me to reopen the dispatcher class' do
      md_app.dispatch 'hello', namespace: 'somebody' do
        def say_hello; 'changed hello'; end
      end

      get 'hello'
      expect(last_response.body).to eql 'changed hello'
    end

    it 'should skip the dispatcher class if it is already defined' do
      md_app.dispatch 'hello', to: goodbye_dispatcher, namespace: 'somebody' do
        def say_hello; 'changed hello'; end
      end

      get 'hello'
      expect(last_response.body).to eql 'changed hello'
    end
  end

  it 'handles loading the plugin multiple times correctly' do
    md_app.dispatch 'hello' do
      def say_hello; 'hello'; end

      route { |r| r.get { say_hello } }
    end

    md_app.route do |r|
      r.multi_dispatch
      'hi'
    end

    md_app.plugin :contrib_multi_dispatch

    get '/hello'
    expect(last_response.body).to eql 'hello'
    get '/dwa'
    expect(last_response.body).to eql 'hi'
  end

  it 'should work even without dispatchers defined' do
    md_app.route do |r|
      r.multi_dispatch
      'hi'
    end

    get '/'
    expect(last_response.body).to eql 'hi'
  end

  it 'should allow me to call the dispatcher methods even in a dispatcher' do
    md_app.dispatch 'models', namespace: 'admin' do
      route { |r| r.get { 'this is admin models' } }
    end

    md_app.dispatch 'admin' do
      route { |r| r.multi_dispatch('admin') }
    end

    md_app.route do |r|
      r.multi_dispatch
      'hi'
    end

    get '/admin/models'
    expect(last_response.body).to eql 'this is admin models'
    get 'dawf'
    expect(last_response.body).to eql 'hi'
  end

  it 'should allow me to offer a block for the multi_dispatch request method' do
    md_app.dispatch 'hello' do
      route { |r| 'not cathced' }
    end

    md_app.route do |r|
      r.multi_dispatch do
        'default body'
      end
    end

    get '/hello'
    expect(last_response.body).to eql 'default body'
  end

  context 'use dispatcher directly' do
    it 'should work without namespace' do
      md_app.dispatch 'hello' do
        route { |r| r.get { 'hello' } }
      end

      md_app.route do |r|
        r.on 'said_hello' do
          r.dispatch 'hello'
        end
      end

      get '/said_hello'
      expect(last_response.body).to eql 'hello'
    end

    it 'should work with namespace' do
      md_app.dispatch 'hello', namespace: 'somebody' do
        route { |r| r.get { 'hello' } }
      end

      md_app.route do |r|
        r.on 'said_hello' do
          r.dispatch 'hello', namespace: 'somebody'
        end
      end

      get '/said_hello'
      expect(last_response.body).to eql 'hello'
    end
  end
end
