$:.unshift(File.join(File.dirname(__FILE__)))
require 'zimbra/handsoap_service'
require 'zimbra/handsoap_account_service'
require 'zimbra/auth'
require 'zimbra/cos'
require 'zimbra/domain'
require 'zimbra/distribution_list'
require 'zimbra/account'
require 'zimbra/acl'
require 'zimbra/common_elements'
require 'zimbra/delegate_auth_token'
require 'zimbra/folder'
require 'zimbra/calendar'
require 'zimbra/appointment'
require 'zimbra/ext/hash'
require 'zimbra/extra/date_helpers'

# Manages a Zimbra SOAP session.  Offers ability to set the endpoint URL, log in, and enable debugging.
module Zimbra
  class << self

    # The URL that will be used to contact the Zimbra SOAP service
    def admin_api_url
      @@admin_api_url
    end
    # Sets the URL of the Zimbra SOAP service
    def admin_api_url=(url)
      @@admin_api_url = url
    end
    
    def account_api_url
      @@account_api_url
    end
    
    def account_api_url=(url)
      @@account_api_url = url
    end
    
    # Turn debugging on/off.  Outputs full SOAP conversations to stdout.
    #   Zimbra.debug = true
    #   Zimbra.debug = false
    def debug=(val)
      Handsoap::Service.logger = (val ? $stdout : nil)
      @@debug = val
    end

    # Whether debugging is enabled
    def debug
      @@debug ||= false
    end

    # Authorization token - obtained after successful login
    def auth_token
      @@auth_token
    end
    
    def account_auth_token
      @@account_auth_token
    end

    # Log into the zimbra SOAP service.  This is required before any other action is performed
    # If a login has already been performed, another login will not be attempted
    def login(username, password, http_options={})
      return @@auth_token if defined?(@@auth_token) && @@auth_token
      reset_login(username, password, http_options)
    end

    # re-log into the zimbra SOAP service
    def reset_login(username, password, http_options={})
      @@auth_token = Auth.login(username, password,  http_options)
    end
    
    def account_login(username)
      delegate_auth_token = DelegateAuthToken.for_account_name(username)
      return false unless delegate_auth_token
      @@account_auth_token = delegate_auth_token.token
      true
    end
  end
end


module Handsoap
  module Http
    module Drivers
      class CurbDriver < AbstractDriver

        def send_http_request(request)
          puts request.ssl_verify_mode
          http_client = get_curl(request.url)
          # Set credentials. The driver will negotiate the actual scheme
          if request.username && request.password
            http_client.userpwd = [request.username, ":", request.password].join
          end

            http_client.ssl_verify_peer = request.ssl_verify_mode
            http_client.cacert = request.trust_ca_file if request.trust_ca_file
            http_client.cert = request.client_cert_file if request.client_cert_file
            # I have submitted a patch for this to curb, but it's not yet supported. If you get errors, try upgrading curb.
            http_client.cert_key = request.client_cert_key_file if request.client_cert_key_file


          # pack headers
          headers = request.headers.inject([]) do |arr, (k,v)|
            arr + v.map {|x| "#{k}: #{x}" }
          end
          http_client.headers = headers
          # I don't think put/delete is actually supported ..
          case request.http_method
            when :get
              http_client.http_get
            when :post
              http_client.http_post(request.body)
            when :put
              http_client.http_put(request.body)
            when :delete
              http_client.http_delete
            else
              raise "Unsupported request method #{request.http_method}"
          end
          parse_http_part(http_client.header_str.gsub(/^HTTP.*\r\n/, ""), http_client.body_str, http_client.response_code, http_client.content_type)
        end
      end
    end
  end
end

module Handsoap
  class Service
    def make_http_request(uri, post_body, headers, http_options=nil)
      request = Handsoap::Http::Request.new(uri, :post)

      # SSL CA AND CLIENT CERTIFICATES
      if http_options
        request.set_trust_ca_file(http_options[:trust_ca_file]) if http_options[:trust_ca_file]
        request.set_client_cert_files(http_options[:client_cert_file], http_options[:client_cert_key_file]) if http_options[:client_cert_file] && http_options[:client_cert_key_file]
        request.set_ssl_verify_mode(http_options[:ssl_verify_mode]) if http_options.has_key? :ssl_verify_mode
      end

      headers.each do |key, value|
        request.add_header(key, value)
      end
      request.body = post_body
      debug do |logger|
        logger.puts request.inspect
      end
      on_after_create_http_request(request)
      request
    end
  end
end
