require 'yard'
YARD::Templates::Engine.register_template_path File::expand_path("../../../yard_templates", __FILE__)

module Mattock
  module YARDExtensions
    class DefineHandler < YARD::Handlers::Ruby::Base
      handles :def

      def mattock_defining?(obj, method)
        check_list = obj.inheritance_tree
        until check_list.empty?
          check_list.each do |co|
            return true if [:CascadingDefinition, :Configurable, :Tasklib, :TaskLib].include? co.name and method == "define"
            return true if [:TaskMixin, :Task, :FileTask, :MultiTask].include? co.name and method == "action"
          end
          check_list = (check_list.find_all{|co| co.respond_to?(:mixins)}||[]).map{|co| co.mixins}.flatten
        end
      end

      def root
        ns = namespace
        until ns.root?
          ns = ns.namespace
        end
        ns
      end

      def process
        return unless mattock_defining?(namespace, statement[0][0])
        (root[:tasklibs] ||= []) << namespace
        namespace[:task_definition] = statement[2]
      end
    end

    class SettingHandler < YARD::Handlers::Ruby::Base
      include YARD::Parser::Ruby

      handles method_call(:setting)
      namespace_only

      def mattock_configurable?(obj)
        check_list = obj.inheritance_tree
        until check_list.empty?
          check_list.each do |co|
            return true if [:CascadingDefinition, :Configurable, :Task, :Tasklib, :TaskLib].include? co.name
          end
          check_list = check_list.find_all{|co| co.respond_to?(:mixins)}.map{|co| co.mixins}.flatten
        end
      end

      def extract_name(obj)
        case obj.type
        when :symbol_literal
          obj.jump(:ident, :op, :kw, :const)[0]
        when :string_literal
          obj.jump(:tstring_content)[0]
        else
          raise YARD::Parser::UndocumentableError, obj.source
        end
      end

      def append_name(sexp, name)
        prefix = sexp.jump(:ident, :tstring_content)
        if prefix == sexp
          raise YARD::Parser::UndocumentableError, sexp.source
        end

        "#{prefix[0]}.#{name}"
      end

      def setting_method_name
        "setting"
      end

      def synthetic_setting(name, value=nil)
        args = s( s(:string_literal, s(:string_content, s(:tstring_content, name))))
        args << value unless value.nil?
        args << false
        new_call = s(:fcall, s(:ident, setting_method_name), s(:arg_paren, args))
        new_call.line_range = (1..1)
        new_call.traverse do |node|
          node.full_source ||= ""
        end
        new_call.full_source = "#{setting_method_name}('#{name}'#{value.nil? ? "" : ", #{value.source}"})"
        new_call
      end

      def process
        return unless mattock_configurable?(namespace)

        #filter further based on NS === Configurable...
        name = extract_name(statement.parameters.first)

        value = statement.parameters(false)[1]
        if !value.nil? and value.type == :fcall and value.jump(:ident)[0] == "nested"
          remapped = (value.parameters.first||[]).map do |assoc|
            new_name =
                append_name(statement.parameters[0], extract_name(assoc[0]))
            synthetic_setting(new_name, assoc[1])
          end
          parser.process(remapped)
          return
        end

        setting = YARD::CodeObjects::MethodObject.new(namespace, name) do |set|
          unless value.nil?
            set['default_value'] = statement.parameters(false)[1].source
          end
          set.signature = "def #{name}"
          if statement.comments.to_s.empty?
            set.docstring = "The value of setting #{name}"
          else
            set.docstring = statement.comments
          end

          set.dynamic = true
        end

        register setting
        (namespace[:settings] ||= []) << setting
      end
    end

    class SettingsHandler < SettingHandler
      handles method_call(:settings)
      namespace_only

      def process
        return unless mattock_configurable?(namespace)

        remapped = statement.parameters(false).first.map do |assoc|
          synthetic_setting(extract_name(assoc[0]), assoc[1])
        end
        parser.process(remapped)
      end
    end

    class NilFieldsHandler < SettingHandler
      handles method_call(:nil_field)
      handles method_call(:nil_fields)
      namespace_only

      def a_nil
        v = s(:kw, nil)
        v.full_source = "nil"
        v
      end

      def process
        return unless mattock_configurable?(namespace)
        remapped = statement.parameters(false).map do |name|
          synthetic_setting(extract_name(name), a_nil)
        end
        parser.process(remapped)
      end
    end

    class RuntimeRequiredFieldsHandler < SettingHandler
      handles method_call(:runtime_required_field)
      handles method_call(:runtime_required_fields)
      namespace_only

      def setting_method_name
        "runtime_setting"
      end

      def process
        return unless mattock_configurable?(namespace)
        remapped = statement.parameters(false).map do |name|
          synthetic_setting(extract_name(name))
        end
        parser.process(remapped)
      end
    end

    class RequiredFieldsHandler < SettingHandler
      handles method_call(:required_field)
      handles method_call(:required_fields)
      namespace_only

      def process
        return unless mattock_configurable?(namespace)
        remapped = statement.parameters(false).map do |name|
          synthetic_setting(extract_name(name))
        end
        parser.process(remapped)
      end
    end
  end
end
