# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"

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
#         time_unit => one of "millisecond", "second", "day", "week", "year"
#         prettify_duration => one of true / false
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
  #     time_unit => ... # string (optionnal), default: "second"
  #     prettify_duration => ... # boolean (optionnal), default: false
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

  # The time unit needed to be used for time interval calculation.
  config :time_unit, :validate => :string
  
  # Apply Time.at(total_seconds).utc.strftime("%H:%M:%S") on the output result
  # Available for time interval < 24 hours
  # Will not display millisecond values
  config :prettify_duration, :calidate => :boolean

  public
  def initialize(config = {})
    super

    @first_parsers = Hash.new { |h,k| h[k] = [] }
    @second_parsers = Hash.new { |h,k| h[k] = [] }
    @first_field_name = String.new
    @second_field_name = String.new

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
      @logger.info("Generating first date parser", :field => first_field, :format => first_format)
      @logger.debug("Adding type with date config", :type => @type,
                    :field => first_field, :format => first_format)
      @first_parsers[first_field] << {
        :parser => parser,
        :format => first_format
      }

      @first_field_name = first_field
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
      @logger.info("Generating second date parser", :field => second_field, :format => second_format)
      @logger.debug("Adding type with date config", :type => @type,
                    :field => second_field, :format => second_format)
      @second_parsers[second_field] << {
        :parser => parser,
        :format => second_format
      }
      
      @second_field_name = second_field
    end
  end

  public
  def filter(event)
    @logger.debug? && @logger.debug("Duration filter: received event", :type => event["type"])
    # return nothing unless there's an actual filter even
    return unless filter?(event)

    first_date = Time.new
    second_date = Time.new

    @first_parsers.each do |field, fieldparsers|
   
      epochmillis = nil
      success = false
      last_exception = RuntimeError.new "Unknown"
      fieldparsers.each do |parserconfig|
        parser = parserconfig[:parser]
        begin
          @logger.info("First DAte Array values", :value => event[@first_field_name])
          epochmillis = parser.call(event[@first_field_name])
          success = true
          break # success
        rescue StandardError, JavaException => e
          last_exception = e
        end # begin
      end # fieldparsers.each 

      raise last_exception unless success
     
      @logger.info("epochmillis", :value => epochmillis) 
      first_date = Time.at(epochmillis / 1000, (epochmillis % 1000) * 1000)      
      
    end # @parsers.each

    @second_parsers.each do |field, fieldparsers|

      epochmillis = nil
      success = false
      last_exception = RuntimeError.new "Unknown"
      fieldparsers.each do |parserconfig|
        parser = parserconfig[:parser]
        begin
          @logger.info("First DAte Array values", :value => event[@second_field_name])
          epochmillis = parser.call(event[@second_field_name])
          success = true
          break # success
        rescue StandardError, JavaException => e
          last_exception = e
        end # begin
      end # fieldparsers.each

      raise last_exception unless success

      @logger.info("epochmillis", :value => epochmillis)
      second_date = Time.at(epochmillis / 1000, (epochmillis % 1000) * 1000)

    end # @parsers.each
    
    nb_sec = (second_date.to_f - first_date.to_f)

    if @time_unit
      case @time_unit
        when "millisecond"
          if @field_name
            event[@field_name] = (nb_sec * 1000).round
          else
            event["duration"] = (nb_sec * 1000).round
          end
        when "second"
          if @field_name
            event[@field_name] = (nb_sec).round
          else
            event["duration"] = (nb_sec).round
          end
        when "minute"
          if @field_name
            event[@field_name] = (nb_sec / 60).round
          else
            event["duration"] = (nb_sec / 60).round
          end
        when "hour"
          if @field_name
            event[@field_name] = (nb_sec / 3600).round
          else
            event["duration"] = (nb_sec / 3600).round
          end
        when "day"
          if @field_name
            event[@field_name] = (nb_sec / 86400).round
          else
            event["duration"] = (nb_sec / 86400).round
          end
        when "week"
          if @field_name
            event[@field_name] = (nb_sec / 604800).round
          else
            event["duration"] = (nb_sec / 604800).round
          end
        when "year"
          if @field_name
            event[@field_name] = (nb_sec / 31536000).round
          else
            event["duration"] = (nb_sec / 31536000).round
          end
      end 
    else  
      if @field_name
        event[@field_name] = (nb_sec).round
      else 
        event["duration"] = (nb_sec).round
      end
    end

    if @prettify_duration
      if @field_name
        event[@field_name] = Time.at(nb_sec).utc.strftime("%H:%M:%S")    
      else 
        event["duration"] = Time.at(nb_sec).utc.strftime("%H:%M:%S")
      end
    end
    filter_matched(event)  
  end # def filter
end # class LogStash::Filters::Duration
