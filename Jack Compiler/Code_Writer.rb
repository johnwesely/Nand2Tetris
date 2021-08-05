class CodeWriter
    def initialize 
        @class_name = ''
        @subroutine_name = ''
        @vm = ''
        @arg_count = 0
    end

    # set current class name
    def set_class_name(name)
        @class_name = name
    end
    
    #write subroutine name
    def write_subroutine_name(name)
      @vm += "function #{@class_name}.#{name} "
    end
    
    # increment argument counter 
    def increment_arg_count
        @arg_count += 1
    end
    
    # reset arg count
    def reset_arg_count
        @arg_count = 0
    end

    #write argument count of current subroutine and resets arg count to zero
    def write_subroutine_arg_count
        ac = @arg_count
        @arg_count = 0
        return "#{ac}"
    end

    # write subroutine call
    def write_subroutine_call
        @vm += "#{@subroutine_name} #{write_subroutine_arg_count} \n "
    end
    
    # get vm
    def get_vm
        @vm
    end
    
    # set subroutine name
    def set_subroutine_name(name)
      @subroutine_name = name
    end
end
        