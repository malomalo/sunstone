# frozen_string_literal: true

module Sunstone
  
  class ServerError < ::RuntimeError
  end

  # RuntimeErrors don't get translated by Rails into
  # ActiveRecord::StatementInvalid which StandardError do. Would rather
  # use StandardError, but it's usefull with Sunstone to know when something
  # raises a Sunstone::Exception::NotFound or Forbidden
  class Exception < ::RuntimeError
    
    class UnexpectedResponse < Sunstone::Exception
    end

    class BadRequest < Sunstone::Exception
    end

    class Unauthorized < Sunstone::Exception
    end

    class Forbidden < Sunstone::Exception
    end

    class NotFound < Sunstone::Exception
    end

    class Gone < Sunstone::Exception
    end

    class MovedPermanently < Sunstone::Exception
    end
    
    class BadGateway < Sunstone::Exception
    end

    class ApiVersionUnsupported < Sunstone::Exception
    end

    class ServiceUnavailable < Sunstone::Exception
    end

  end
  
end

