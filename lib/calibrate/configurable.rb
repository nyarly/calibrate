module Calibrate
  #Handles setting options on objects it's mixed into
  #
  #Settings can have default values or be required (as opposed to defaulting to
  #nil).  Settings and their defaults are inherited (and can be overridden) by
  #subclasses.
  #
  #Calibrate also includes a yard-extension that will document settings of a
  #Configurable
  #
  #@example (see ClassMethods)
  module Configurable
    class Exception < ::StandardError
    end

    class NoDefaultValue < Exception
      def initialize(field_name, klass)
        super("No default value for field #{field_name} on class #{klass.name}")
      end
    end
  end
end

require 'calibrate/configurable/field-metadata'
require 'calibrate/configurable/proxy-value'
require 'calibrate/configurable/field-processor'
require 'calibrate/configurable/class-methods'
require 'calibrate/configurable/instance-methods'
require 'calibrate/configurable/directory-structure'
