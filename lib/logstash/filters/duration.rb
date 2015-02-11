# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "date"

# The filter will calculate the duration between two given dates (first_date and last_date).
#
# The goal of this filter is to add a new field containing the value of the time interval (in seconds) between the two given dates.
#
# The date formats allowed are anything allowed by Joda-Time (java time library). You can see the docs for this format here:
#
# [joda.time.format.DateTimeFormat](http://joda-time.sourceforge.net/apidocs/org/joda/time/format/DateTimeFormat.html)
#
# The config looks like this:
#     filter {
#       duration {
#         field_name => "new field name"
#         first_date => ["first_logdate", "MMM dd YYY HH:mm:ss"]
#         second_date => ["second_logdate", "MMM dd YYY HH:mm:ss"]
#       }
#     }
#
class LogStash::Filters::Duration < LogStash::Filters::Base
  if RUBY_ENGINE == "jruby"
    JavaException = java.lang.Exception
    UTC = org.joda.time.DateTimeZone.forID("UTC")
  end

  # filter {
  #   duration {
  #     field_name => ... # string (optionnal), default: "duration"
  #     first_date => ... # hash (requiered), default: {}
  #     second_date => ... # hash (requiered), default: {}
  #   }
  # }
  config_name "duration"
  milestone 1

  # The name of the new field.
  config :field_name, :validate => :string

  # The pair of first log date filed name and the date pattern following Joda-Time (java time library):
  # [joda.time.format.DateTimeFormat](http://joda-time.sourceforge.net/apidocs/org/joda/time/format/DateTimeFormat.html)
  config :first_date, :validate => :array, :default => []

  # The pair of second log date filed name and the date pattern following Joda-Time (java time library):
  # [joda.time.format.DateTimeFormat](http://joda-time.sourceforge.net/apidocs/org/joda/time/format/DateTimeFormat.html)
  config :second_date, :validate => :array, :default => []

  public
  def initialize(config = {})
    super

    @first_parsers = Hash.new { |h,k| h[k] = [] }
    @second_parsers = Hash.new { |h,k| h[k] = [] }
  end # def initialize

  public
  def register
    require "java"
    if @first_date.length < 2
      raise LogStash::ConfigurationError, I18n.t("logstash.agent.configuration.invalid_plugin_register",
        :plugin => "filter", :type => "duration",
        :error => "The first_date setting should contains first a field name and one date format, current value is #{@first_date}")
    end
    if @second_date.length < 2
      raise LogStash::ConfigurationError, I18n.t("logstash.agent.configuration.invalid_plugin_register",
        :plugin => "filter", :type => "duration",
        :error => "The second_date setting should contains first a field name and one date format, current value is #{@second_date}")
    end
    setupMatcher(@config["first_date"].shift, @config["first_date"], @config["second_date"].shift,  @config["second_date"])
  end # def register

  private
  def setupMatcher(first_field, first_value, second_field, second_value)
    first_value.each do |first_format|
      case first_format
        when "ISO8601"
          joda_parser = org.joda.time.format.ISODateTimeFormat.dateTimeParser
          if @timezone
            joda_parser = joda_parser.withZone(org.joda.time.DateTimeZone.forID(@timezone))
          else
            joda_parser = joda_parser.withOffsetParsed
          end
          parser = lambda { |date| joda_parser.parseMillis(date) }
        when "UNIX" # unix epoch
          joda_instant = org.joda.time.Instant.java_class.constructor(Java::long).method(:new_instance)
          #parser = lambda { |date| joda_instant.call((date.to_f * 1000).to_i).to_java.toDateTime }
          parser = lambda { |date| (date.to_f * 1000).to_i }
        when "UNIX_MS" # unix epoch in ms
          joda_instant = org.joda.time.Instant.java_class.constructor(Java::long).method(:new_instance)
          parser = lambda do |date|
            #return joda_instant.call(date.to_i).to_java.toDateTime
            return date.to_i
          end
        when "TAI64N" # TAI64 with nanoseconds, -10000 accounts for leap seconds
          joda_instant = org.joda.time.Instant.java_class.constructor(Java::long).method(:new_instance)
          parser = lambda do |date|
            # Skip leading "@" if it is present (common in tai64n times)
            date = date[1..-1] if date[0, 1] == "@"
            #return joda_instant.call((date[1..15].hex * 1000 - 10000)+(date[16..23].hex/1000000)).to_java.toDateTime
            return (date[1..15].hex * 1000 - 10000)+(date[16..23].hex/1000000)
          end
        else
          joda_parser = org.joda.time.format.DateTimeFormat.forPattern(first_format).withDefaultYear(Time.new.year)
          if @timezone
            joda_parser = joda_parser.withZone(org.joda.time.DateTimeZone.forID(@timezone))
          else
            joda_parser = joda_parser.withOffsetParsed
          end
          parser = lambda { |date| joda_parser.parseMillis(date) }
      end
      @logger.debug("Adding type with date config", :type => @type,
                    :field => first_field, :format => first_format)
      @first_parsers[first_field] << {
        :parser => parser,
        :format => first_format
      }
    end
    second_value.each do |second_format|
      case second_format
        when "ISO8601"
          joda_parser = org.joda.time.format.ISODateTimeFormat.dateTimeParser
          if @timezone
            joda_parser = joda_parser.withZone(org.joda.time.DateTimeZone.forID(@timezone))
          else
            joda_parser = joda_parser.withOffsetParsed
          end
          parser = lambda { |date| joda_parser.parseMillis(date) }
        when "UNIX" # unix epoch
          joda_instant = org.joda.time.Instant.java_class.constructor(Java::long).method(:new_instance)
          parser = lambda { |date| (date.to_f * 1000).to_i }
        when "UNIX_MS" # unix epoch in ms
          joda_instant = org.joda.time.Instant.java_class.constructor(Java::long).method(:new_instance)
          parser = lambda do |date|
            return date.to_i
          end
        when "TAI64N" # TAI64 with nanoseconds, -10000 accounts for leap seconds
          joda_instant = org.joda.time.Instant.java_class.constructor(Java::long).method(:new_instance)
          parser = lambda do |date|
          # Skip leading "@" if it is present (common in tai64n times)
          date = date[1..-1] if date[0, 1] == "@"
          #return joda_instant.call((date[1..15].hex * 1000 - 10000)+(date[16..23].hex/1000000)).to_java.toDateTime
          return (date[1..15].hex * 1000 - 10000)+(date[16..23].hex/1000000)
        end
      else
        joda_parser = org.joda.time.format.DateTimeFormat.forPattern(second_format).withDefaultYear(Time.new.year)
          if @timezone
            joda_parser = joda_parser.withZone(org.joda.time.DateTimeZone.forID(@timezone))
          else
            joda_parser = joda_parser.withOffsetParsed
          end
          parser = lambda { |date| joda_parser.parseMillis(date) }
      end
      @logger.debug("Adding type with date config", :type => @type,
                    :field => second_field, :format => second_format)
      @second_parsers[second_field] << {
        :parser => parser,
        :format => second_format
      }
    end
  end

  public
  def filter(event)
    @logger.debug? && @logger.debug("Duration filter: received event", :type => event["type"])
    # return nothing unless there's an actual filter even
    return unless filter?(event)

    @first_parsers.each do |field, fieldparsers|
      @logger.debug? && @logger.debug("Date filter looking for field",
                                      :type => event["type"], :field => field)
      next unless event.include?(field)

      fieldvalues = event[field]
      fieldvalues = [fieldvalues] if !fieldvalues.is_a?(Array)
      fieldvalues.each do |value|
        next if value.nil?
        begin
          epochmillis = nil
          success = false
          last_exception = RuntimeError.new "Unknown"
          fieldparsers.each do |parserconfig|
            parserconfig[:parser].each do |parser|
              begin
                epochmillis = parser.call(value)
                success = true
                break # success
              rescue StandardError, JavaException => e
                last_exception = e
              end
            end # parserconfig[:parser].each
            break if success
          end # fieldparsers.each

          raise last_exception unless success

          # Convert joda DateTime to a ruby Time
          event["first"] = LogStash::Timestamp.at(epochmillis / 1000, (epochmillis % 1000) * 1000)

          @logger.debug? && @logger.debug("Date parsing done", :value => value, :timestamp => event[@target])
        filter_matched(event)
        rescue StandardError, JavaException => e
          @logger.warn("Failed parsing date from field", :field => field,
                       :value => value, :exception => e)
          # Raising here will bubble all the way up and cause an exit.
          # TODO(sissel): Maybe we shouldn't raise?
          # TODO(sissel): What do we do on a failure? Tag it like grok does?
          #raise e
        end # begin
      end # fieldvalue.each
    end # @first_parsers.each    

    @second_parsers.each do |field, fieldparsers|
      @logger.debug? && @logger.debug("Date filter looking for field",
                                      :type => event["type"], :field => field)
        next unless event.include?(field)

        fieldvalues = event[field]
        fieldvalues = [fieldvalues] if !fieldvalues.is_a?(Array)
        fieldvalues.each do |value|
          next if value.nil?
          begin
            epochmillis = nil
            success = false
            last_exception = RuntimeError.new "Unknown"
            fieldparsers.each do |parserconfig|
              parserconfig[:parser].each do |parser|
                begin
                  epochmillis = parser.call(value)
                  success = true
                  break # success
                rescue StandardError, JavaException => e
                  last_exception = e
                end
              end # parserconfig[:parser].each
              break if success
            end # fieldparsers.each

            raise last_exception unless success

            # Convert joda DateTime to a ruby Time
            event["second"] = LogStash::Timestamp.at(epochmillis / 1000, (epochmillis % 1000) * 1000)

            @logger.debug? && @logger.debug("Date parsing done", :value => value, :timestamp => event[@target])
          filter_matched(event)
          rescue StandardError, JavaException => e
            @logger.warn("Failed parsing date from field", :field => field,
                         :value => value, :exception => e)
            # Raising here will bubble all the way up and cause an exit.
            # TODO(sissel): Maybe we shouldn't raise?
            #raise e
        end # begin
      end # fieldvalue.each
    end # @second_parsers.each

    if @field_name
      event[@field_name] = "plop"
    else 
      event["duration"] = "plop"
    end
    
    return event 
  end # def filter
end # class LogStash::Filters::Duration
