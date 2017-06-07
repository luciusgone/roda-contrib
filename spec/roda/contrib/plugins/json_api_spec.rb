require 'roda/contrib/plugins/json_api'
require 'rack/test'
require 'stringio'

describe RodaContrib::Plugins::JsonApi do
  include Rack::Test::Methods

  def app
    jsonapi_app
  end

  let(:jsonapi_app) { Class.new(Roda) { plugin :contrib_json_api; self } }
  let(:json_s) { "{\"data\":{\"id\":\"1\",\"type\":\"products\",\"attributes\":{\"name\":\"pen\",\"description\":\"a pen to use\",\"slug\":\"pen\"}}}" }
  let(:invalid_jsonapi_s) { "{\"data\":{\"id\":\"1\", \"type\":\"products\"}, \"errors\":[{\"title\":\"v error\"}]}" }

  before do
    jsonapi_app.route do |r|
      product = Class.new(Object) do
        attr_accessor :id, :name, :description, :slug

        def initialize(id, name, desc, slug)
          @id, @name, @description, @slug = id, name, desc, slug
        end
      end
      serializable_pd = Class.new(JSONAPI::Serializable::Resource) do
        type 'products'
        attributes :name, :description, :slug
      end

      r.get 'pd' do
        pd = product.new(1, 'pen', 'a pen to use', 'pen')
        represent pd, with: serializable_pd
      end

      r.post 'pd' do
        pd = json_params
        pd = product.new(2, pd[:name], pd[:description], pd[:slug])
        represent pd, with: serializable_pd
      end

      err_full_msg = Class.new(Object) do
        def full_messages
          ['an error msg', 'another error msg']
        end
      end

      r.get 'err' do
        err = err_full_msg.new
        represent_err err_full_msg
      end
    end
  end

  after { jsonapi_app = nil }

  it 'should return correct response rendering resources' do
    get '/pd'
    expect(last_response.body).to match /\"type\"\:\"products\"/
    expect(last_response.body).to match /\"id\"\:\"1\"/
    expect(last_response.body).to match /\"name\"\:\"pen\"/
  end

  it 'should offer me parsed JSON API doc' do
    header 'Content-Type', 'application/vnd.api+json'
    env 'rack.input', StringIO.new(json_s)
    post '/pd'

    expect(last_response.body).to match /\"type\"\:\"products\"/
    expect(last_response.body).to match /\"id\"\:\"2\"/
    expect(last_response.body).to match /\"name\"\:\"pen\"/

  end

  it 'should handle adding the Rack::Parser multiple times correctly' do
    jsonapi_app.plugin :contrib_json_api, {some: :options}

    get '/pd'
    expect(last_response.body).to match /\"type\"\:\"products\"/
    expect(last_response.body).to match /\"id\"\:\"1\"/
    expect(last_response.body).to match /\"name\"\:\"pen\"/
  end

  it 'should allow me to skip setting up the middleware' do
    japp = Class.new(Roda)
    japp.plugin :contrib_json_api, skip_middleware: true

    expect(japp.instance_methods).to include :represent
    expect(japp.instance_variable_get(:@middleware)).to be_empty
  end

  context 'when something wrong happened' do
    it 'should bail out the application when the json doc is invalid' do
      header 'Content-Type', 'application/vnd.api+json'
      env 'rack.input', StringIO.new('{')
      post '/pd'

      expect(last_response.status).to eql 400
      expect(last_response.body).to match /invalid\ JSON\ doc/
    end

    it 'should bail out the application if the JSON API doc is not comformant' do
      header 'Content-Type', 'application/vnd.api+json'
      env 'rack.input', StringIO.new(invalid_jsonapi_s)
      post '/pd'

      expect(last_response.status).to eql 400
      expect(last_response.body).to match /\"title\"\:\"Invalid\ JSONAPI\ doc\"/
    end
  end
end
