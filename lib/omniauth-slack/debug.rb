require 'omniauth-slack/refinements'
require 'logger'

# Appends 'TRACE' option to Logger levels.
sev_label_new = Logger::SEV_LABEL.dup
sev_label_new << 'TRACE'
Logger::Severity::TRACE = (sev_label_new.size - 1)
Logger.send(:remove_const, :SEV_LABEL)
Logger::SEV_LABEL = sev_label_new.freeze

module OmniAuth
  module Slack
    module Debug
      #using ObjectRefinements
      LOG_ALL = %w(1 true yes all debug)
      LOG_NONE = %w(0 false no none nil nill null)

      include CallerMethodName

      def self.included(other)
        other.send(:include, CallerMethodName)
        other.send(:extend, Extensions)
      end

      module Extensions
        def debug(method_name = nil, klass=nil, &block)
          method_name ||= caller_method_name
          klass ||= self
          filter = ENV['OMNIAUTH_SLACK_DEBUG']
          return if filter.nil? || filter.to_s=='' || LOG_NONE.include?(filter.to_s.downcase)
          klass = case klass
            when Class; klass.name
            when Module; klass.name
            when String; klass
            else klass.to_s
          end
          klass_name = klass.to_s.split('::').last.to_s
          log_text = yield
          full_text = "(#{klass_name} #{method_name}) #{log_text}"   #{Thread.current.object_id}

          if filter && !LOG_ALL.include?(filter.to_s.downcase)
            regexp = filter.is_a?(Regexp) ? filter : Regexp.new(filter.to_s, true)
            return unless full_text[regexp]
          end

          OmniAuth.logger.log(Logger::TRACE, full_text)
        end
      end

      def debug(method_name=nil, klass=nil, &block)
        method_name ||= caller_method_name
        self.class.debug(method_name, klass, &block)
      end

    end
  end
end
