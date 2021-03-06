require 'pathname'

module Rack
  class JSONP

    def initialize(app, options={})
      @app = app
      @trigger = options.fetch(:trigger, :extension)
      @extra_security = options[:extra_security] == true
    end

    def call(env)
      request = Rack::Request.new(env)
      callback = request.params['callback']
      requesting_jsonp = trigger_via_extesion?(request) || trigger_via_callback?(callback)

      return [400,{},[]] if requesting_jsonp && !self.valid_callback?(callback)

      if requesting_jsonp
        env['PATH_INFO'] = env['PATH_INFO'].sub(/\.jsonp/i, '.json')
        env['REQUEST_URI'] = env['PATH_INFO']
      end

      status, headers, body = @app.call(env)

      if requesting_jsonp && self.json_response?(headers['Content-Type'])
        json = ""
        body.each { |s| json << s }
        security_str = @extra_security ? '/**/' : ''
        body = ["#{security_str}#{callback}(#{json});"]
        headers['Content-Length'] = body.first.bytesize.to_s
        headers['Content-Type'] = headers['Content-Type'].sub(/^[^;]+(;?)/, "#{MIME_TYPE}\\1")
      end

      [status, headers, body]
    end

  protected
    
    # Do not allow arbitrary Javascript in the callback.
    #
    # @return [Regexp]
    VALID_CALLBACK_PATTERN = /^[a-zA-Z0-9\._]+$/

    # @return [String] the JSONP response mime type.
    MIME_TYPE = 'application/javascript'

    # Checks if the callback function name is safe/valid.
    #
    # @param [String] callback the string to be used as the JSONP callback function name.
    # @return [TrueClass|FalseClass]
    def valid_callback?(callback)
      !callback.nil? && !callback.match(VALID_CALLBACK_PATTERN).nil?
    end

    # Check if the response Content Type is JSON or JavaScript.
    #
    # @param [Hash] content_type the response Content Type
    # @return [TrueClass|FalseClass]
    def json_response?(content_type)
      !content_type.nil? && !content_type.match(/^application\/json|text\/javascript/i).nil?
    end

    def trigger_via_extesion?(request)
      Pathname(request.env['PATH_INFO']).extname =~ /^\.jsonp$/i
    end

    def trigger_via_callback?(callback)
      @trigger.to_s == 'callback' && !callback.nil?
    end
  end

end
