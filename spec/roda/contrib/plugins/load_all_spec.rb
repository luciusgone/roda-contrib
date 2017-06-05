require 'roda/contrib/plugins/load_all'

describe RodaContrib::Plugins::LoadAll do
  let!(:app) { Class.new(Roda) }
  let!(:root) { File.expand_path '../../../../support/dummy', __FILE__ }
  let!(:file_a) { File.expand_path './models/a.rb', root }
  let!(:file_b) { File.expand_path './views/b.rb', root }

  before do
    module A
      def self.rm_consts
        remove_const :B if const_defined? :B
        remove_const :C if const_defined? :C
      end
    end
  end

  after do
    app = nil
    A.rm_consts
    $LOADED_FEATURES.delete(file_a)
    $LOADED_FEATURES.delete(file_b)
  end

  context 'when the root opts is set' do
    before { app.opts[:root] = root }

    it 'should allow me to use load all plugin without root option' do
      app.plugin :contrib_load_all
      expect(app).to respond_to :load_all
    end

    it 'should allow me to load all files under a specific folder' do
      app.plugin :contrib_load_all
      expect{A::B}.to raise_error NameError
      app.load_all :models
      expect(A::B).to eq '1.1'
    end

    it 'should allow me to load more than one folder at a time' do
      app.plugin :contrib_load_all
      expect{A::B}.to raise_error NameError
      expect{A::C}.to raise_error NameError
      app.load_all :models, :views
      expect(A::B).to eq '1.1'
      expect(A::C).to eq 1.1
    end
  end

  context 'when the root opts is not set' do
    it 'should raise ArgumentError when not providing root option' do
      expect{
        app.plugin :contrib_load_all
      }.to raise_error ArgumentError
    end

    it 'should allow me to load all files under a specific folder' do
      app.plugin :contrib_load_all, root: root
      expect{A::B}.to raise_error NameError
      app.load_all :models
      expect(A::B).to eq '1.1'
    end

    it 'should allow me to load more than one folder at a time' do
      app.plugin :contrib_load_all, root: root
      expect{A::B}.to raise_error NameError
      expect{A::C}.to raise_error NameError
      app.load_all :models, :views
      expect(A::B).to eq '1.1'
      expect(A::C).to eq 1.1
    end
  end
end
