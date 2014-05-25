require 'savon'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash'

module Ottick
  class Ticket
    attr_reader :options, :client

    # Ticket.new(options)
    # for possible options see Savon.client()
    # http://savonrb.com/version2/client.html
    #
    def initialize(options = {})
      sanitize_options!(options)
      @otrs_credentials = otrs_credentials!(options)
      @options          = default_options.merge(options)
      @client           = Savon.client(@options)
    end

    def get(options = {})
      @client.call(:ticket_get, message: @otrs_credentials.merge(options))
    end

    def create(subject, text, options = {})
      return if (subject.blank? || text.blank?)
      ticket = create_ticket_opts!(options)
      ticket.merge!("Title" => subject)
      article = create_article_opts!(options)
      article.merge!("Subject" => subject).merge!("Body" => text)

      @client.call(:ticket_create, 
                    message: @otrs_credentials.merge("Ticket" => ticket).
		             merge("Article" => article).merge(options))
    end

    private
 
    def sanitize_options!(options)
      return if options.empty?
      options.symbolize_keys!
      if options.has_key?(:http_auth_user) or options.has_key?(:http_auth_passwd)
        raise RuntimeError, 
              "please use basic_auth: ['user', 'passwd'] instead of" +
              ":http_auth_user and http_auth_passwd"
      end
    end

    def otrs_credentials!(options)
      otrs_cred = options.extract!(:otrs_user, :otrs_passwd)
      {
        "UserLogin" => otrs_cred.fetch(:otrs_user, Ottick.otrs_user),
        "Password"  => otrs_cred.fetch(:otrs_passwd, Ottick.otrs_passwd)
      }
    end
 
    def default_options
      default_basic_options.merge(default_http_authentication)
    end

    def default_basic_options
      {
        wsdl: 	     Ottick.wsdl,
        endpoint:    Ottick.endpoint,
        env_namespace: :soapenv,
        convert_request_keys_to: :camelcase
      }
    end

    def default_http_authentication
      if Ottick.http_auth_user.blank?
        {}
      else
        { basic_auth: [Ottick.http_auth_user, Ottick.http_auth_passwd] }
      end
    end

    def create_ticket_opts!(options)
      ticket_opts = options.extract!("Ticket")
      sanitize_ticket_opts!(ticket_opts)
      { 
	"Queue"	=> Ottick.ticket_queue,
	"State"	=> Ottick.ticket_state,
	"Type"	=> Ottick.ticket_type,
	"Priority" => Ottick.ticket_priority,
	"CustomerUser" => Ottick.customer_user
      }.merge(ticket_opts)
    end

    def create_article_opts!(options)
      article_opts = options.extract!("Article")
      sanitize_article_opts!(article_opts)
      {
	"SenderType" => Ottick.article_sender_type,
	"Charset"    => Ottick.article_charset,
	"MimeType"   => Ottick.article_mime_type
      }.merge(article_opts)
    end

    def sanitize_ticket_opts!(opts)
      if opts.has_key?("QueueID")
        raise RuntimeError, "Please use Queue instead of QueueID"
      end
      if opts.has_key?("StateID")
        raise RuntimeError, "Please use State instead of StateID"
      end
      if opts.has_key?("PriorityID")
        raise RuntimeError, "Please use Priority instead of PriorityID"
      end
      if opts.has_key?("TypeID")
        raise RuntimeError, "Please use Type instead of TypeID"
      end
    end

    def sanitize_article_opts!(opts)
      if opts.has_key?("SenderTypeID")
        raise RuntimeError, "Please use Type instead of TypeID"
      end
    end
  end
end
