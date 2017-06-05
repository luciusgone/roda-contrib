require 'roda/contrib/plugins/csrf'
require 'rack/test'
require 'stringio'

describe RodaContrib::Plugins::Csrf do
  include Rack::Test::Methods

  def app
    @app
  end

  let(:io) { StringIO.new }
  let!(:route_blk) {
    proc do |r|
      r.get do
        response['TAG'] = csrf.tag
        response['METATAG'] = csrf.metatag
        response['TOKEN'] = csrf.token
        response['FIELD'] = csrf.field
        response['HEADER'] = csrf.header
        'g'
      end
      r.post 'foo' do
        'bar'
      end
      r.post do
        'p'
      end
    end
  }
  let(:env_proc) { proc { |h| h['Set-Cookie'] ? {'HTTP_COOKIE'=>h['Set-Cookie'].sub("; path=/; HttpOnly", '')} : {} } }

  it 'adds csrf protection and csrf helper methods' do
    blk = route_blk
    @app = Class.new(Roda) do
      use Rack::Session::Cookie, secret: '1'
      plugin :contrib_csrf, skip: ['POST:/foo']

      route &blk
    end

    post '/', {}, {'rack.input'=> io}
    expect(last_response.status).to eql 403

    post '/foo', {}, {'rack.input'=> io}
    expect(last_response.body).to eql 'bar'

    get '/'
    h = last_response.header
    f = h['FIELD']
    t = Regexp.escape(h['TOKEN'])
    expect(last_response.status).to eql 200
    expect(last_response.body).to eql 'g'
    expect(h['TAG']).to match /\A<input type="hidden" name="#{f}" value="#{t}" \/>\z/
    expect(h['METATAG']).to match /\A<meta name="#{f}" content="#{t}" \/>\z/

    e = env_proc[h].merge('rack.input' => io, "HTTP_#{h['HEADER']}" => h['TOKEN'])
    post '/', {}, e
    expect(last_response.status).to eql 200
    expect(last_response.body).to eql 'p'
  end

  it 'should allow me to add the plugin multiple times' do
    blk = route_blk
    @app = Class.new(Roda) do
      use Rack::Session::Cookie, secret: '1'
      plugin :contrib_csrf, skip: ['POST:/foo']

      route &blk
    end

    @app.plugin :csrf
    post '/foo', {}, {'rack.input' => io}
    expect(last_response.body).to eql 'bar'
  end

  it 'can optionally skip setting uo the middleware' do
    blk = route_blk
    sub_app = Class.new(Roda) do
      plugin :contrib_csrf, skip_middleware: true

      route &blk
    end

    @app = Class.new(Roda) do
      use Rack::Session::Cookie, :secret=>'1'
      plugin :contrib_csrf, :skip=>['POST:/foo/foo']

      route do |r|
        r.on 'foo' do
          r.run sub_app
        end
      end
    end

    post '/foo', {}, {'rack.input'=> io}
    expect(last_response.status).to eql 403

    post '/foo/foo', {}, {'rack.input'=> io}
    expect(last_response.body).to eql 'bar'

    get '/foo'
    h = last_response.header
    f = h['FIELD']
    t = Regexp.escape(h['TOKEN'])
    expect(last_response.status).to eql 200
    expect(last_response.body).to eql 'g'
    expect(h['TAG']).to match /\A<input type="hidden" name="#{f}" value="#{t}" \/>\z/
    expect(h['METATAG']).to match /\A<meta name="#{f}" content="#{t}" \/>\z/

    e = env_proc[h].merge('rack.input' => io, "HTTP_#{h['HEADER']}" => h['TOKEN'])
    post '/foo', {}, e
    expect(last_response.status).to eql 200
    expect(last_response.body).to eql 'p'

    m = sub_app.instance_variable_get(:@middleware)
    expect(m).not_to include ::Rack::Csrf
  end
end
