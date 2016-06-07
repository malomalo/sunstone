module Sunstone
  
  class Exception < ::Exception
    
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

    class ApiVersionUnsupported < Sunstone::Exception
    end

    class ServiceUnavailable < Sunstone::Exception
    end

  end
  
end

