require 'net/http'
require 'net/https'
require 'uri'

require_relative 'errors'

class NyplPlatformApiClient
  def initialize(config = {})
    @config = {
      base_url: ENV['PLATFORM_API_BASE_URL'],
      client_id: ENV['NYPL_OAUTH_ID'],
      client_secret: ENV['NYPL_OAUTH_SECRET'],
      oauth_url: ENV['NYPL_OAUTH_URL'],
      log_level: 'info'
    }.merge config

    raise NyplPlatformApiClientError.new 'Missing config: neither config.base_url nor ENV.PLATFORM_API_BASE_URL are set' unless @config[:base_url]
    raise NyplPlatformApiClientError.new 'Missing config: neither config.client_id nor ENV.NYPL_OAUTH_ID are set' unless @config[:client_id]
    raise NyplPlatformApiClientError.new 'Missing config: neither config.client_secret nor ENV.NYPL_OAUTH_SECRET are set ' unless @config[:client_secret]
    raise NyplPlatformApiClientError.new 'Missing config: neither config.oauth_url nor ENV.NYPL_OAUTH_URL are set ' unless @config[:oauth_url]
  end

  def get (path, options = {})
    options = parse_http_options options

    authenticate! if options[:authenticated]

    uri = URI.parse("#{@config[:base_url]}#{path}")

    logger.debug "NyplPlatformApiClient: Getting from platform api", { uri: uri }

    begin
      request = Net::HTTP::Get.new(uri)

      # Add bearer token header
      request["Authorization"] = "Bearer #{@access_token}" if options[:authenticated]

      # Execute request:
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme === 'https') do |http|
        http.request(request)
      end
    rescue Exception => e
      raise NyplPlatformApiClientError.new(e), "Failed to GET #{path}: #{e.message}"
    end

    logger.debug "NyplPlatformApiClient: Got platform api response", { code: response.code, body: response.body }

    parse_json_response response
  end

  def post (path, body, options = {})
    options = parse_http_options options

    # Default to POSTing JSON unless explicitly stated otherwise
    options[:headers]['Content-Type'] = 'application/json' unless options[:headers]['Content-Type']

    authenticate! if options[:authenticated]

    uri = URI.parse("#{@config[:base_url]}#{path}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === 'https'

    begin
      request = Net::HTTP::Post.new(uri.path, 'Content-Type' => options[:headers]['Content-Type'])
      request.body = body.to_json

      logger.debug "NyplPlatformApiClient: Posting to platform api", { uri: uri, body: body }

      # Add bearer token header
      request['Authorization'] = "Bearer #{@access_token}" if options[:authenticated]

      # Execute request:
      response = http.request(request)
    rescue Exception => e
      raise NyplPlatformApiClientError.new(e), "Failed to POST to #{path}: #{e.message}"
    end

    logger.debug "NyplPlatformApiClient: Got platform api response", { code: response.code, body: response.body }

    parse_json_response response
  end

  private

  def parse_http_options (_options)
    options = {
      authenticated: true
    }.merge _options

    options[:headers] = {
    }.merge(_options[:headers] || {})
      .transform_keys(&:to_s)

    options
  end

  def parse_json_response (response)
    # Among NYPL services, these are the only non-error statuses with useful JSON payloads:
    if ['200', '404'].include? response.code
      begin
        JSON.parse(response.body)
      rescue => e
        raise NyplPlatformApiClientError, "Error parsing response (#{response.code}): #{response.body}"
      end
    elsif response.code == "401"
      # Likely an expired access-token; Wipe it for next run
      # TODO: Implement token refresh
      @access_token = nil
      raise NyplPlatformApiClientTokenError.new("Got a 401: #{response.body}")
    else
      raise NyplPlatformApiClientError, "Error interpretting response (#{response.code}): #{response.body}"
    end
  end

  # Authorizes the request.
  def authenticate!
    # NOOP if we've already authenticated
    return nil if ! @access_token.nil?

    logger.debug "NyplPlatformApiClient: Authenticating with client_id #{@config[:client_id]}"

    uri = URI.parse("#{@config[:oauth_url]}oauth/token")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth(@config[:client_id], @config[:client_secret])
    request.set_form_data(
      "grant_type" => "client_credentials"
    )

    req_options = {
      use_ssl: uri.scheme == "https",
      request_timeout: 500
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end

    if response.code == '200'
      @access_token = JSON.parse(response.body)["access_token"]
    else
      nil
    end
  end

  def logger
    @logger ||= NyplLogFormatter.new(STDOUT, level: @config[:log_level])
  end
end
