# encoding: utf-8

require 'spec_helper.rb'

describe Rack::JSONP do

  before :each do
    @response_status = 200
    @response_headers = {
     'Content-Type' => 'application/json',
     'Content-Length' => '15',
    }
    @response_body = ['{"key":"value"}']

    @app = lambda do |params|
      [@response_status, @response_headers, @response_body]
    end

    @callback = 'J50Npi.success'
  end

  describe 'when a valid jsonp request is made' do

    before :each do
      @request = Rack::MockRequest.env_for("/action.jsonp?callback=#{@callback}")
      @jsonp_response = Rack::JSONP.new(@app).call(@request)
      @jsonp_response_status, @jsonp_response_headers, @jsonp_response_body = @jsonp_response
    end

    it 'should not modify the response status code' do
      expect(@jsonp_response_status).to eq(@response_status)
    end

    it 'should update the response content length to the new value' do
      expect(@jsonp_response_headers['Content-Length']).to eq('32')
    end

    it 'should set the response content type as application/javascript' do
      expect(@jsonp_response_headers['Content-Type']).to eq('application/javascript')
    end

    it 'should wrap the response body in the Javasript callback' do
      expect(@jsonp_response_body).to eq(["#{@callback}(#{@response_body.first});"])
    end
  end

  describe 'when a valid jsonp request is made with multibyte characters' do
    before :each do
      @response_headers['Content-Type'] = 'application/json; charset=utf-8'
      @response_body = ['{"key":"√alue"}']
      @request = Rack::MockRequest.env_for("/action.jsonp?callback=#{@callback}")
      @jsonp_response = Rack::JSONP.new(@app).call(@request)
      @jsonp_response_status, @jsonp_response_headers, @jsonp_response_body = @jsonp_response
    end

    it 'should not modify the response status code' do
      expect(@jsonp_response_status).to eq(@response_status)
    end

    it 'should update the response content length to the new value' do
      expect(@jsonp_response_headers['Content-Length']).to eq('34')
    end

    it 'should set the response content type as application/javascript without munging the charset' do
      expect(@jsonp_response_headers['Content-Type']).to eq('application/javascript; charset=utf-8')
    end

    it 'should wrap the response body in the Javasript callback' do
      expect(@jsonp_response_body).to eq(["#{@callback}(#{@response_body.first});"])
    end
  end

  describe 'when a jsonp request is made wihtout a callback parameter present' do
    before :each do
      @request = Rack::MockRequest.env_for('/action.jsonp')
      @jsonp_response = Rack::JSONP.new(@app).call(@request)
      @jsonp_response_status, @jsonp_response_headers, @jsonp_response_body = @jsonp_response
    end

    it 'should set the response status to 400' do
      expect(@jsonp_response_status).to eq(400)
    end

    it 'should return an empty body' do
      expect(@jsonp_response_body).to eq([])
    end

    it 'should return empty headers' do
      expect(@jsonp_response_headers).to eq({})
    end
  end

  describe 'when a jsonp request is made with an invalid callback' do
    before :each do
      @callback = "alert('window.cookies');cb"
      @request = Rack::MockRequest.env_for("/action.jsonp?callback=#{@callback}")
      @jsonp_response = Rack::JSONP.new(@app).call(@request)
      @jsonp_response_status, @jsonp_response_headers, @jsonp_response_body = @jsonp_response
    end

    it 'should set the response status to 400' do
      expect(@jsonp_response_status).to eq(400)
    end

    it 'should return an empty body' do
      expect(@jsonp_response_body).to eq([])
    end

    it 'should return empty headers' do
      expect(@jsonp_response_headers).to eq({})
    end
  end

  describe 'when a non jsonp request is made' do
    before :each do
      @request = Rack::MockRequest.env_for('/action.json')
      @jsonp_response = Rack::JSONP.new(@app).call(@request)
      @jsonp_response_status, @jsonp_response_headers, @jsonp_response_body = @jsonp_response
    end

    it 'should not modify the response status' do
      expect(@jsonp_response_status).to eq(@response_status)
    end

    it 'should not modify the response headers' do
      expect(@jsonp_response_headers).to eq(@response_headers)
    end

    it 'should not modify the response body' do
      expect(@jsonp_response_body).to eq(@response_body)
    end
  end

  describe 'when the original response is not json' do
    before :each do
      @response_status = 403
      @response_headers = {
       'Content-Type' => 'text/html',
       'Content-Length' => '1'
      }
      @response_body = ['']

      @request = Rack::MockRequest.env_for("/action.jsonp?callback=#{@callback}")
      @jsonp_response = Rack::JSONP.new(@app).call(@request)
      @jsonp_response_status, @jsonp_response_headers, @jsonp_response_body = @jsonp_response
    end

    it 'should not modify the response body' do
      expect(@response_body).to eq(@response_body)
    end

    it 'should not odify the headers Content-Type' do
      expect(@jsonp_response_headers['Content-Type']).to eq(@response_headers['Content-Type'])
    end

    it 'should not modify the headers Content-Lenght' do
      expect(@jsonp_response_headers['Content-Lenght']).to eq(@response_headers['Content-Lenght'])
    end
  end

  describe 'when configured to be triggered by the presence of `callback` alone' do
    before :each do
      @response_headers = {
      'Content-Type' => 'text/javascript',
      'Content-Length' => '15',
      }
      @request = Rack::MockRequest.env_for("/action.js?callback=#{@callback}")
      @jsonp_response = Rack::JSONP.new(@app, trigger: :callback).call(@request)
      @jsonp_response_status, @jsonp_response_headers, @jsonp_response_body = @jsonp_response
    end

    it 'should wrap the response body in the JavaScript callback' do
      expect(@jsonp_response_body).to eq(["#{@callback}(#{@response_body.first});"])
    end
  end

  describe 'when configured to add extra security to output' do
    before :each do
      @request = Rack::MockRequest.env_for("/action.jsonp?callback=#{@callback}")
      @jsonp_response = Rack::JSONP.new(@app, extra_security: true).call(@request)
      @jsonp_response_status, @jsonp_response_headers, @jsonp_response_body = @jsonp_response
      @callback = '/**/J50Npi.success'
    end

    # Reference: http://miki.it/blog/2014/7/8/abusing-jsonp-with-rosetta-flash/
    it 'it prepends /**/ to the javascript output to thwart attacks' do
      expect(@jsonp_response_body).to eq(["#{@callback}(#{@response_body.first});"])
    end
  end
end
