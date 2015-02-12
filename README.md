# logstash-filter-duration

The filter will calculate the duration between two given dates (first_date and last_date).
The goal of this filter is to add a new field containing the value of the time interval between the two given dates.

The date formats allowed are anything allowed by Joda-Time (java time library). You can see the docs for this format here:
[joda.time.format.DateTimeFormat](http://joda-time.sourceforge.net/apidocs/org/joda/time/format/DateTimeFormat.html)

## Synopsis
```
  filter {
     duration {
       field_name => ... # string (optionnal), default: "duration"
       first_date => ... # hash (requiered), default: {}
       second_date => ... # hash (requiered), default: {}
       time_unit => ... # string (optionnal), default: "second"
       prettify_duration => ... # boolean (optionnal), default: false
     }
  }
```

## Example
```
  filter {
      duration {
         field_name => "new field name"
         first_date => ["first_logdate", "MMM dd YYY HH:mm:ss"]
         second_date => ["second_logdate", "MMM dd YYY HH:mm:ss"]
         time_unit => one of "millisecond", "second", "day", "week", "year"
         prettify_duration => one of true / false
      }
  }
```

## Details
### field_name

### first_date

### second_date

### time_unit

### prettify_duration
