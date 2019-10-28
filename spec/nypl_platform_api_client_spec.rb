require 'spec_helper'
require 'webmock/rspec'

describe NyplPlatformApiClient do
  before(:each) do
    ENV['PLATFORM_API_BASE_URL'] = 'https://example.com/api/v0.1/'
    ENV['NYPL_OAUTH_ID'] = Base64.strict_encode64 'fake-client'
    ENV['NYPL_OAUTH_SECRET'] = Base64.strict_encode64 'fake-secret'
    ENV['NYPL_OAUTH_URL'] = 'https://isso.example.com/'

    stub_request(:post, "#{ENV['NYPL_OAUTH_URL']}oauth/token").to_return(status: 200, body: '{ "access_token": "fake-access-token" }')
    stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}bibs/sierra-nypl/12082323").to_return(status: 200, body: File.read('./spec/fixtures/bib.json'))
  end

  describe :config do
    it "should throw error if api base url unset" do
      ENV['PLATFORM_API_BASE_URL'] = nil
      expect { NyplPlatformApiClient.new }.to raise_error(NyplPlatformApiClientError)
    end

    it "should throw error if client id unset" do
      ENV['NYPL_OAUTH_ID'] = nil
      expect { NyplPlatformApiClient.new }.to raise_error(NyplPlatformApiClientError)
    end

    it "should throw error if client secret unset" do
      ENV['NYPL_OAUTH_SECRET'] = nil
      expect { NyplPlatformApiClient.new }.to raise_error(NyplPlatformApiClientError)
    end

    it "should throw error if oauth url unset" do
      ENV['NYPL_OAUTH_URL'] = nil
      expect { NyplPlatformApiClient.new }.to raise_error(NyplPlatformApiClientError)
    end

    it "should allow configuration via constructor" do
      ENV['PLATFORM_API_BASE_URL'] = nil
      ENV['NYPL_OAUTH_ID'] = nil
      ENV['NYPL_OAUTH_SECRET'] = nil
      ENV['NYPL_OAUTH_URL'] = nil

      config = NyplPlatformApiClient.new({
        base_url: 'https://example.com/api/v0.1/',
        client_id: 'client-id',
        client_secret: 'client-secret',
        oauth_url: 'https://isso.example.com'
      }).instance_variable_get(:@config)

      expect(config).to be_a(Hash)
      expect(config[:base_url]).to eq('https://example.com/api/v0.1/')
      expect(config[:client_id]).to eq('client-id')
    end

    it "should prefer constructor config over ENV variables" do
      client = NyplPlatformApiClient.new({
        client_id: 'client-id-via-constructor-config'
      })
      expect(client.instance_variable_get(:@config)).to be_a(Hash)
      expect(client.instance_variable_get(:@config)[:client_id]).to eq('client-id-via-constructor-config')
    end

    it "should set default log_level to 'info'" do
      client = NyplPlatformApiClient.new
      expect(client.instance_variable_get(:@config)).to be_a(Hash)
      expect(client.instance_variable_get(:@config)[:log_level]).to eq('info')
    end

    it "should allow log_level override via constructor (only)" do
      ENV['LOG_LEVEL'] = 'debug'
      client = NyplPlatformApiClient.new
      expect(client.instance_variable_get(:@config)).to be_a(Hash)
      expect(client.instance_variable_get(:@config)[:log_level]).to eq('info')

      client = NyplPlatformApiClient.new(log_level: 'debug')
      expect(client.instance_variable_get(:@config)).to be_a(Hash)
      expect(client.instance_variable_get(:@config)[:log_level]).to eq('debug')
    end
  end

  describe :parse_http_options do
    it "should assume common defaults" do
      options = NyplPlatformApiClient.new.send :parse_http_options, {}

      expect(options[:authenticated]).to eq(true)
      expect(options[:headers]).to be_a(Hash)
      expect(options[:headers].keys.size).to eq(0)
    end

    it "should allow authentication override" do
      options = NyplPlatformApiClient.new.send :parse_http_options, { authenticated: false }

      expect(options[:authenticated]).to eq(false)
    end

    it "should allow custom Content-Type" do
      options = NyplPlatformApiClient.new.send :parse_http_options, { headers: { 'Content-Type' => 'text/plain' } }

      expect(options[:headers]).to be_a(Hash)
      expect(options[:headers]['Content-Type']).to be_a(String)
      expect(options[:headers]['Content-Type']).to eq('text/plain')
    end

    it "should allow extra header" do
      options = NyplPlatformApiClient.new.send :parse_http_options, { headers: { 'X-My-Header': 'header value' } }

      expect(options[:authenticated]).to eq(true)
      expect(options[:headers]).to be_a(Hash)
      expect(options[:headers]['X-My-Header']).to eq('header value')
    end
  end

  describe :authentication do

    it "should authenticate by default" do
      client = NyplPlatformApiClient.new

      # Verify no access token:
      expect(client.instance_variable_get(:@access_token)).to be_nil

      # Call an endpoint with authentication:
      expect(client.get('bibs/sierra-nypl/12082323')).to be_a(Object)

      # Verify access_token retrieved:
      expect(client.instance_variable_get(:@access_token)).to be_a(String)
      expect(client.instance_variable_get(:@access_token)).to eq('fake-access-token')
    end

    it "should authenticate when calling with :authenticated => true" do
      client = NyplPlatformApiClient.new

      # Verify no access token:
      expect(client.instance_variable_get(:@access_token)).to be_nil

      # Call an endpoint with authentication:
      expect(client.get('bibs/sierra-nypl/12082323', authenticated: true)).to be_a(Object)

      # Verify access_token retrieved:
      expect(client.instance_variable_get(:@access_token)).to be_a(String)
      expect(client.instance_variable_get(:@access_token)).to eq('fake-access-token')
    end

    it "should NOT authenticate when calling with :authenticated => false" do
      client = NyplPlatformApiClient.new

      # Verify no access token:
      expect(client.instance_variable_get(:@access_token)).to be_nil

      # Call an endpoint without authentication:
      expect(client.get('bibs/sierra-nypl/12082323', authenticated: false)).to be_a(Object)

      # Verify access_token retrieved:
      expect(client.instance_variable_get(:@access_token)).to be_nil
    end
  end

  describe :responses do
    it "should auto parse JSON if 200 response" do
      stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}some-path").to_return(status: 200, body: '{ "foo": "bar" }' )

      resp = NyplPlatformApiClient.new.get('some-path')
      expect(resp).to be_a(Hash)
      expect(resp['foo']).to eq('bar')
    end

    it "should auto parse JSON if 404 response" do
      stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}some-path").to_return(status: 404, body: '{ "foo": "bar" }' )

      resp = NyplPlatformApiClient.new.get('some-path')
      expect(resp).to be_a(Hash)
      expect(resp['foo']).to eq('bar')
    end

    it "should consider non-200, non-404 as errors" do
      stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}some-path").to_return(status: 300, body: '{ "foo": "bar" }' )
      expect { NyplPlatformApiClient.new.get('some-path') }.to raise_error(NyplPlatformApiClientError)

      stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}some-path").to_return(status: 500, body: '{ "foo": "bar" }' )
      expect { NyplPlatformApiClient.new.get('some-path') }.to raise_error(NyplPlatformApiClientError)
    end

    it "should throw NyplPlatformApiClientError if response is not valid json" do
      stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}some-path").to_return(status: 200, body: '' )
      expect { NyplPlatformApiClient.new.get('some-path') }.to raise_error(NyplPlatformApiClientError)

      stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}some-path").to_return(status: 200, body: '{ "foo": "bar' )
      expect { NyplPlatformApiClient.new.get('some-path') }.to raise_error(NyplPlatformApiClientError)
    end

    it "should throw NyplPlatformApiClientError for 401" do
      stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}some-path").to_return(status: 401, body: '' )

      expect { NyplPlatformApiClient.new.get('some-path') }.to raise_error(NyplPlatformApiClientTokenError)
    end

    it "should throw NyplPlatformApiClientError for 500" do
      stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}some-path").to_return(status: 500, body: '' )

      expect { NyplPlatformApiClient.new.get('some-path') }.to raise_error(NyplPlatformApiClientError)
    end
  end
end
