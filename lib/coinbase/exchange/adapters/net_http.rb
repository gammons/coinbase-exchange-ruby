module Coinbase
  module Exchange
    # Net-HTTP adapter
    class NetHTTPClient < APIClient
      def initialize(api_key = '', api_secret = '', api_pass = '', options = {})
        super(api_key, api_secret, api_pass, options)
        @conn = Net::HTTP.new(@api_uri.host, @api_uri.port)
        @conn.use_ssl = true if @api_uri.scheme == 'https'
        @conn.ssl_version = :TLSv1_2
      end

      private

      def http_verb(method, path, body = nil)
        case method
        when 'GET' then req = Net::HTTP::Get.new(path)
        when 'POST' then req = Net::HTTP::Post.new(path)
        when 'DELETE' then req = Net::HTTP::Delete.new(path)
        else raise
        end

        req.body = body

        req_ts = Time.now.utc.to_i.to_s

        req['Content-Type'] = 'application/json'
        req['CB-ACCESS-TIMESTAMP'] = req_ts
        req['CB-ACCESS-PASSPHRASE'] = @api_pass
        req['CB-ACCESS-KEY'] = @api_key
        req['CB-ACCESS-SIGN'] = signature(path, body, method)

        resp = @conn.request(req)
        case resp.code
        when '200' then yield(NetHTTPResponse.new(resp))
        when '400' then raise BadRequestError, resp.body
        when '401' then raise NotAuthorizedError, resp.body
        when '403' then raise ForbiddenError, resp.body
        when '404' then raise NotFoundError, resp.body
        when '429' then raise RateLimitError, resp.body
        when '500' then raise InternalServerError, resp.body
        end
        resp.body
      end

      def signature(request_path = '', body = '', method = 'GET')
        body = body.to_json if body.is_a?(Hash)
        timestamp = Time.now.utc.to_i

        what = "#{timestamp}#{method}#{request_path}#{body}"

        secret = Base64.decode64(@api_secret)
        hash = OpenSSL::HMAC.digest('sha256', secret, what)
        Base64.strict_encode64(hash)
      end
    end

    # Net-Http response object
    class NetHTTPResponse < APIResponse
      def body
        @response.body
      end

      def headers
        out = @response.to_hash.map do |key, val|
          [key.upcase.gsub('_', '-'), val.count == 1 ? val.first : val]
        end
        out.to_h
      end

      def status
        @response.code.to_i
      end
    end
  end
end
