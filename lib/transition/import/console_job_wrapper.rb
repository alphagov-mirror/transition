module Transition
  module Import
    module ConsoleJobWrapper
      class NullConsole
        [:print, :puts].each { |sym| define_method(sym) {|*_|} }
      end

      class Job
        def skip!
          @skip = true
        end

        def skipped?
          @skip
        end
      end

      def self.active=(value)
        @active = value
      end

      def self.active?
        @active.nil? ? true : @active
      end

      def console
        @console ||= ConsoleJobWrapper.active? ? $stderr : NullConsole.new
      end

      def console_puts(*args)
        console.puts *args
      end

      def console_print(*args)
        console.print *args
      end

      ##
      # Common idiom of doing a thing, then printing a done message on the same line
      def start(message, options = {doing: '...', done: 'done', skipped: 'skipped'})
        return unless block_given?

        console_print "#{message} #{options[:doing]} "
        job = Job.new
        yield job
        console_puts "#{job.skipped? ? options[:skipped] : options[:done]}"
      end
    end
  end
end
