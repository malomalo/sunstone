module Sunstone
  
  class RecordInvalid < ::Exception
  end
  
  class RecordNotSaved < ::Exception
  end
  
  class Exception < ::Exception
    
    class UnexpectedResponse < Sunstone::Exception
    end

    class BadRequest < Sunstone::Exception
      attr_reader :response
      def initialize(response)
        super
        @response = response
      end
    end

    class Unauthorized < Sunstone::Exception
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

