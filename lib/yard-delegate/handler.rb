require 'yard'
require 'pry'
module YARD
  module Delegate
    class Handler < YARD::Handlers::Ruby::Base

      handles method_call(:delegate)

      def delegate(*methods)
        options = methods.pop
        to = options[:to]

        prefix, allow_nil = options.values_at(:prefix, :allow_nil)


        method_prefix = \
          if prefix
            "#{prefix == true ? to : prefix}_"
          else
            ''
          end

        to = to.to_s
        to = 'self.class' if to == 'class'

        methods.each do |method|
          # Attribute writer methods only accept one argument. Makes sure []=
          # methods still accept two arguments.
          args = (method =~ /[^\]]=$/) ? %w[ arg ] : %w[ *args &block ]
          definition = args.join(', ')
          signature = "def #{method_prefix}#{method}(#{definition})"

          if allow_nil
            source = <<-EOS
              #{signature}
                if #{to} || #{to}.respond_to?(:#{method})
                  #{to}.#{method}(#{definition})
                end
              end
            EOS
          else
            exception = %(raise "\#{self.class}##{method_prefix}#{method} delegated to #{to}.#{method}, but #{to} is nil: \#{self.inspect}")

            source = <<-EOS
              #{signature}
                #{to}.#{method}(#{definition})
              rescue NoMethodError
                if #{to}.nil?
                  #{exception}
                else
                  raise
                end
              end
            EOS
          end

          register YARD::CodeObjects::MethodObject.new(namespace, "#{method_prefix}#{method}", scope) { |o|
            o.parameters = args.map{|a| [a, nil] }
            o.signature = signature
            o.source = source
            comment = statement.comments.to_s.empty? ? "Delegates to #{to}.#{method}" : statement.comments
            comment << "\n@see ##{to}"
            o.docstring = comment
            o.delegate = to
          }
        end
      rescue => ex
        p ex
        raise
      end

      process do
        instance_eval(statement.source, __FILE__, __LINE__)
      end
    end
  end
end
