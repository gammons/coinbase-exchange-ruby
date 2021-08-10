module Coinbase
  module Exchange
    # Websocket client for Coinbase Exchange
    class Websocket
      def initialize(options = {})
        @ws_url = options[:ws_url] || 'wss://ws-feed.pro.coinbase.com'
        @keepalive = options[:keepalive] || true

        # setup_default_callbacks
      end

      def start!
        if EventMachine.reactor_running?
          @reactor_owner = false
          refresh!
        else
          @reactor_owner = true
          EM.run { refresh! }
        end
      end

      def stop!
        @socket.onclose = if @reactor_owner == true
                            ->(_event) { EM.stop }
                          else
                            ->(_event) { nil }
                          end
        @socket.close
      end

      def refresh!
        @socket = Faye::WebSocket::Client.new(@ws_url)
        @socket.onmessage = method(:ws_received)
        @socket.onclose = method(:ws_closed)
        @socket.onerror = method(:ws_error)
      end

      def subscribe!(options = {})
        product_ids = options.fetch(:product_ids, [])
        channels = options.fetch(:channels, [])

        send({ type: 'subscribe', product_ids: product_ids, channels: channels })
      end

      def ping(options = {})
        msg = options[:payload] || Time.now.to_s
        @socket.ping(msg) do |resp|
          yield(resp) if block_given?
        end
      end

      # Run this before processing every message
      def message(&block)
        @message_cb = block
      end

      def received(&block)
        @received_cb = block
      end

      def open(&block)
        @open_cb = block
      end

      def match(&block)
        @match_cb = block
      end

      def change(&block)
        @change_cb = block
      end

      def done(&block)
        @done_cb = block
      end

      def error(&block)
        @error_cb = block
      end

      private

      def ws_received(event)
        data = APIObject.new(JSON.parse(event.data))
        @received_cb.call(data)
        case data['type']
        when 'open' then @open_cb.call(data)
        when 'match' then @match_cb.call(data)
        when 'change' then @change_cb.call(data)
        when 'done' then @done_cb.call(data)
        when 'error' then @error_cb.call(data)
        else @received_cb.call(data)
        end
      end

      def ws_closed(_event)
        if @keepalive
          refresh!
        else
          EM.stop
        end
      end

      def ws_error(event)
        raise WebsocketError, event.data
      end

      def send(msg)
        @socket.send(msg.to_json)
      end

      def setup_default_callbacks
        @message_cb = ->(_data) { nil }
        @received_cb = ->(_data) { nil }
        @open_cb = ->(_data) { nil }
        @match_cb = ->(_data) { nil }
        @change_cb = ->(_data) { nil }
        @done_cb = ->(_data) { nil }
        @error_cb = ->(_data) { nil }
      end
    end
  end
end
