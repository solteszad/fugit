
module Fugit

  # A natural language set of parsers for fugit.
  # Focuses on cron expressions. The rest is better left to Chronic and friends.
  #
  module Nat

    class << self

      def parse(s, opts={})

        return s if s.is_a?(Fugit::Cron) || s.is_a?(Fugit::Duration)

        return nil unless s.is_a?(String)

#p s; Raabro.pp(Parser.parse(s, debug: 3), colours: true)
#(p s; Raabro.pp(Parser.parse(s, debug: 1), colours: true)) rescue nil
        slots = Parser.parse(s)

        return nil unless slots

        #parse_crons(
        #  s, slots,
        #  opts[:multi] == true || (opts[:multi] && opts[:multi] != :fail))

        if opts[:multi] == true || (opts[:multi] && opts[:multi] != :fail)
          slots.to_crons
        else
          slots.to_cron
        end
      end

      def do_parse(s, opts={})

        parse(s, opts) ||
        fail(ArgumentError.new("could not parse a nat #{s.inspect}"))
      end
    end

    module Parser include Raabro

      one_to_nine =
        %w[ one two three four five six seven eight nine ]
      sixties =
        %w[ zero ] + one_to_nine +
        %w[ ten eleven twelve thirteen fourteen fifteen sixteen seventeen
            eighteen nineteen ] +
          %w[ twenty thirty fourty fifty ]
            .collect { |a|
              ([ nil ] + one_to_nine)
                .collect { |b| [ a, b ].compact.join('-') } }
            .flatten

      NHOURS = sixties[0, 13]
        .each_with_index
        .inject({}) { |h, (n, i)| h[n] = i; h }
        .merge!(
          'midnight' => 0, 'oh' => 0, 'noon' => 12)
      NMINUTES = sixties
        .each_with_index
        .inject({}) { |h, (n, i)| h[n] = i; h }
        .merge!(
          "o'clock" => 0, 'hundred' => 0)

      WEEKDAYS =
        Fugit::Cron::Parser::WEEKDAYS +
        Fugit::Cron::Parser::WEEKDS

      POINTS = %w[
        minutes? mins? seconds? secs? hours? hou h ]

      INTERVALS = %w[
        seconds? minutes? hours? days? months?
        sec min
        s m h d M ]

      oh = {
        '1st' => 1, '2nd' => 2, '3rd' => 3, '21st' => 21, '22nd' => 22,
        '23rd' => 23, '31st' => 31,
        'last' => -1 }
      (4..30)
        .each { |i| oh["#{i}th"] = i.to_i }
      %w[
        first second third fourth fifth sixth seventh eighth ninth tenth
        eleventh twelfth thirteenth fourteenth fifteenth sixteenth seventeenth
        eighteenth nineteenth twentieth twenty-first twenty-second twenty-third
        twenty-fourth twenty-fifth twenty-sixth twenty-seventh twenty-eighth
        twenty-ninth thirtieth thirty-first ]
          .each_with_index { |e, i| oh[e] = i + 1 }
      OMONTHDAYS = oh.freeze

      #
      # parsers bottom to top #################################################

      def _every(i); rex(nil, i, /[ \t]*every[ \t]+/i); end
      def _from(i); rex(nil, i, /[ \t]*from[ \t]+/i); end
      def _at(i); rex(nil, i, /[ \t]*at[ \t]+/i); end
      def _in(i); rex(nil, i, /[ \t]*in[ \t]+/i); end
      def _on(i); rex(nil, i, /[ \t]*on[ \t]+/i); end
      def _to(i); rex(nil, i, /[ \t]*to[ \t]+/i); end

      def _and(i); rex(nil, i, /[ \t]*and[ \t]+/i); end
      def _and_or_or(i); rex(nil, i, /[ \t]*(and|or)[ \t]+/i); end
      def _in_or_on(i); rex(nil, i, /(in|on)[ \t]+/i); end

      def _and_or_or_or_comma(i)
        rex(nil, i, /[ \t]*(,[ \t]*)?((and|or)[ \t]+|,[ \t]*)/i); end

      def _to_or_dash(i);
        rex(nil, i, /[ \t]*-[ \t]*|[ \t]+(to|through)[ \t]+/i); end

      #def _day(i); rex(nil, i, /[ \t]*day[ \t]+/i); end
      def _day_s(i); rex(nil, i, /[ \t]*days?[ \t]+/i); end
      def _the(i); rex(nil, i, /[ \t]*the[ \t]+/i); end

      def _space(i); rex(nil, i, /[ \t]+/); end
      def _sep(i); rex(nil, i, /([ \t]+|[ \t]*,[ \t]*)/); end
      #def _comma(i); rex(nil, i, /[ \t]*,[ \t]*/); end

      def count(i); rex(:count, i, /\d+/); end
      #def comma_count(i); seq(nil, i, :_comma, :count); end

OMONTHDAY_REX = /#{OMONTHDAYS.keys.join('|')}/i
      def omonthday(i)
        rex(:omonthday, i, OMONTHDAY_REX)
      end
MONTHDAY_REX = /3[0-1]|[0-2]?[0-9]/
      def monthday(i)
        rex(:monthday, i, MONTHDAY_REX)
      end
WEEKDAY_REX = /(#{WEEKDAYS.join('|')})(?=($|[-, \t]))/i
  # prevent "mon" from eating "monday"
      def weekday(i)
        rex(:weekday, i, WEEKDAY_REX)
      end

      def omonthdays(i); jseq(nil, i, :omonthday, :_and_or_or_or_comma); end
      def monthdays(i); jseq(nil, i, :monthday, :_and_or_or_or_comma); end
      def weekdays(i); jseq(nil, i, :weekday, :_and_or_or_or_comma); end

      def on_the(i); seq(nil, i, :_the, :omonthdays); end

      def on_thes(i); jseq(:on_thes, i, :on_the, :_and_or_or_or_comma); end
      def on_days(i); seq(:on_days, i, :_day_s, :monthdays); end
      def on_weekdays(i); ren(:on_weekdays, i, :weekdays); end

      def on_object(i)
        alt(nil, i, :on_days, :on_weekdays, :on_thes)
      end
      def on_objects(i)
        jseq(nil, i, :on_object, :_and)
      end

        #'every month on day 2 at 10:00' => '0 10 2 * *',
        #'every month on day 2 and 5 at 10:00' => '0 10 2,5 * *',
        #'every month on days 1,15 at 10:00' => '0 10 1,15 * *',
        #
        #'every week on monday 18:23' => '23 18 * * 1',
        #
        # every month on the 1st
      def on(i)
        seq(:on, i, :_on, :on_objects)
      end

      def city_tz(i)
        rex(nil, i, /[A-Z][a-zA-Z0-9+\-]+(\/[A-Z][a-zA-Z0-9+\-_]+){0,2}/)
      end
      def named_tz(i)
        rex(nil, i, /Z|UTC/)
      end
      def delta_tz(i)
        rex(nil, i, /[-+]([01][0-9]|2[0-4])(:?(00|15|30|45))?/)
      end
      def tz(i)
        alt(:tz, i, :city_tz, :named_tz, :delta_tz)
      end
      def tzone(i)
        seq(nil, i, :_in_or_on, '?', :tz)
      end

      def digital_hour(i)
        rex(
          :digital_hour, i,
          /(2[0-4]|[0-1]?[0-9]):([0-5][0-9])([ \t]*(am|pm))?/i)
      end

      def ampm(i)
        rex(:ampm, i, /[ \t]*(am|pm)/i)
      end
      def dark(i)
        rex(:dark, i, /[ \t]*dark/i)
      end

      def simple_h(i)
         rex(:simple_h, i, /#{(0..24).to_a.reverse.join('|')}/)
      end
      def simple_hour(i)
        seq(:simple_hour, i, :simple_h, :ampm, '?')
      end

NAMED_M_REX = /#{NMINUTES.keys.join('|')}/i
      def named_m(i)
        rex(:named_m, i, NAMED_M_REX)
      end
      def named_min(i)
        seq(nil, i, :_space, :named_m)
      end

NAMED_H_REX = /#{NHOURS.keys.join('|')}/i
      def named_h(i)
        rex(:named_h, i, NAMED_H_REX)
      end
      def named_hour(i)
        seq(:named_hour, i, :named_h, :dark, '?', :named_min, '?', :ampm, '?')
      end

POINT_REX = /(#{POINTS.join('|')})[ \t]+/i
      def _point(i); rex(:point, i, POINT_REX); end

      def counts(i)
        jseq(nil, i, :count, :_and_or_or_or_comma)
      end

      def at_p(i)
        seq(:at_p, i, :_point, :counts)
      end
      def at_point(i)
        jseq(nil, i, :at_p, :_and_or_or)
      end

        # at five
        # at five pm
        # at five o'clock
        # at 16:30
        # at noon
        # at 18:00 UTC <-- ...tz
      def at_object(i)
        alt(nil, i, :named_hour, :digital_hour, :simple_hour, :at_point)
      end
      def at_objects(i)
        jseq(nil, i, :at_object, :_and_or_or_or_comma)
      end

      def at(i)
        seq(:at, i, :_at, '?', :at_objects)
      end

INTERVAL_REX = /[ \t]*(#{INTERVALS.join('|')})/
      def interval(i)
        rex(:interval, i, INTERVAL_REX)
      end

        # every day
        # every 1 minute
      def every_interval(i)
        seq(:every_interval, i, :count, '?', :interval)
      end

      def every_single_interval(i)
        rex(:every_single_interval, i, /(1[ \t]+)?(week|year)/)
      end

      def to_weekday(i)
        seq(:to_weekday, i, :weekday, :_to_or_dash, :weekday)
      end
      def weekdays(i)
        jseq(:weekdays, i, :weekday, :_and_or_or_or_comma)
      end

      def weekday_range(i)
        alt(nil, i, :to_weekday, :weekdays)
      end

      def to_omonthday(i)
        seq(:to_omonthday, i,
          :_the, '?', :omonthday, :_to, :_the, '?', :omonthday)
      end

      def from_object(i)
        alt(nil, i, :to_weekday, :to_omonthday)
      end
      def from_objects(i)
        jseq(nil, i, :from_object, :_and_or_or)
      end
      def from(i)
        seq(nil, i, :_from, :from_objects)
      end

        # every monday
        # every Fri-Sun
        # every Monday and Tuesday
      def every_weekday(i)
        jseq(nil, i, :weekday_range, :_and_or_or)
      end

      def otm(i)
        rex(nil, i, /[ \t]+of the month/)
      end

        # every 1st of the month
        # every first of the month
        # Every 2nd of the month
        # Every second of the month
        # every 15th of the month
      def every_of_the_month(i)
        seq(nil, i, :omonthdays, :otm)
      end

      def every_named(i)
        rex(:every_named, i, /weekday/i)
      end

      def every_object(i)
        alt(
          nil, i,
          :every_weekday, :every_of_the_month,
          :every_interval, :every_named, :every_single_interval)
      end
      def every_objects(i)
        jseq(nil, i, :every_object, :_and_or_or)
      end

      def every(i)
        seq(:every, i, :_every, :every_objects)
      end

      def nat_elt(i)
        alt(nil, i, :every, :at, :from, :tzone, :on)
      end
      def nat(i)
        jseq(:nat, i, :nat_elt, :_sep)
      end

      #
      # rewrite parsed tree ###################################################

      def slot(key, data0, data1=nil)
        Slot.new(key, data0, data1)
      end

      def _rewrite_subs(t, key=nil)
        t.subgather(key).collect { |ct| rewrite(ct) }
      end
      def _rewrite_sub(t, key=nil)
        st = t.sublookup(key)
        st ? rewrite(st) : nil
      end

      def rewrite_on_thes(t)
        _rewrite_subs(t, :omonthday)
      end
      def rewrite_on_days(t)
        _rewrite_subs(t, :monthday)
      end

      def rewrite_on(t)
        _rewrite_subs(t)
      end

      def rewrite_monthday(t)
        slot(:monthday, t.string.to_i)
      end

      def rewrite_omonthday(t)
        slot(:monthday, OMONTHDAYS[t.string.downcase])
      end

      def rewrite_at_p(t)
        pt = t.sublookup(:point).strinp
        pt = pt.match?(/\Amon/i) ? 'M' : pt[0, 1]
        pts = t.subgather(:count).collect { |e| e.string.to_i }
#p [ pt, pts ]
        case pt
        when 'm' then slot(:m, pts)
        when 's' then slot(:second, pts)
else fail("argh")
        end
      end

      def rewrite_every_single_interval(t)
        case t.string
        when /year/i then [ slot(:month, 1, :weak), slot(:monthday, 1, :weak) ]
        #when /week/i then xxx...
        else slot(:weekday, 0, :weak)
        end
      end

      def rewrite_every_interval(t)

#Raabro.pp(t, colours: true)
        ci = t.subgather(nil).collect(&:string)
        i = ci.pop.strip[0, 3]
        c = (ci.pop || '1').strip
        i = (i == 'M' || i.downcase == 'mon') ? 'M' : i[0, 1].downcase
        cc = c == '1' ? '*' : "*/#{c}"

        case i
        when 'M' then slot(:month, cc)
        when 'd' then slot(:monthday, cc, :weak)
        when 'h' then slot(:hm, cc, 0)
        when 'm' then slot(:hm, '*', cc)
        when 's' then slot(:second, cc)
        else {}
        end
      end

      def rewrite_every_named(t)

        case s = t.string
        when /weekday/i then slot(:weekday, '1-5', :weak)
        when /week/i then slot(:weekday, '0', :weak)
        else fail "cannot rewrite #{s.inspect}"
        end
      end

      def rewrite_tz(t)
        slot(:tz, t.string)
      end

      def rewrite_weekday(t)
        Fugit::Cron::Parser::WEEKDS.index(t.string[0, 3].downcase)
      end

      def rewrite_weekdays(t)
#Raabro.pp(t, colours: true)
        slot(:weekday, _rewrite_subs(t, :weekday))
      end
      alias rewrite_on_weekdays rewrite_weekdays

      def rewrite_to_weekday(t)
        wd0, wd1 = _rewrite_subs(t, :weekday)
        wd1 = 7 if wd1 == 0
        slot(:weekday, "#{wd0}-#{wd1}")
      end

      def rewrite_to_omonthday(t)
Raabro.pp(t, colours: true)
        md0, md1 = _rewrite_subs(t, :omonthday).collect(&:_data0)
        md1 = 'l' if md1 == -1
        slot(:monthday, "#{md0}-#{md1}")
      end

      def rewrite_digital_hour(t)
        h, m, ap = t.string.split(/[: \t]+/)
        h, m = h.to_i, m.to_i
        h += 12 if ap && ap.downcase == 'pm'
        slot(:hm, h.to_i, m.to_i)
      end

      def rewrite_simple_hour(t)
        a = t.subgather(nil).collect(&:string)
        h = a[0].to_i
        h = h + 12 if a[1] && a[1].match?(/pm\z/)
        slot(:hm, h, 0)
      end

      def rewrite_named_hour(t)
#Raabro.pp(t, colours: true)

        ht = t.sublookup(:named_h)
        mt = t.sublookup(:named_m)
        apt = t.sublookup(:ampm)

        h = ht.strinp
        m = mt ? mt.strinp : 0
#p [ 0, '-->', h, m ]
        h = NHOURS[h]
        m = NMINUTES[m] || m
#p [ 1, '-->', h, m ]

        h += 12 if h < 13 && apt && apt.strinpd == 'pm'

        slot(:hm, h, m)
      end

      def rewrite_at(t)
        _rewrite_subs(t)
      end

      def rewrite_every(t)
        _rewrite_sub(t)
      end

      def rewrite_nat(t)
#Raabro.pp(t, colours: true)
        Fugit::Nat::SlotGroup.new(_rewrite_subs(t).flatten)
      end
    end

    class Slot
      attr_reader :key
      attr_accessor :_data0, :_data1
      def initialize(key, data0, data1)
        @key = key
        @_data0 = data0
        @weak, @_data1 = (data1 == :weak) ? [ true, nil ] : [ false, data1 ]
      end
      def weak?; @weak; end
      def data0; @data0 ||= Array(@_data0); end
      def data1; @data1 ||= Array(@_data1); end
      def inspect
        a = [ @key, @_data0 ]
        a << @_data1 if @_data1 != nil
        a << :w if @weak
        "(slot #{a.collect(&:inspect).join(' ')})"
      end
      def append(slot)
        @_data0 = conflate(@_data0, slot.data0, slot.weak?)
        @_data1 = conflate(@_data1, slot.data1, slot.weak?)
      end
      protected
      def conflate(da, db, weakb)
        return db if da.nil? || weak?
        return da if db.nil? || weakb
        Array(da).concat(Array(db))
      end
    end

    # minute          * or 0–59
    # hour            * or 0–23
    # day-of-month    * or 1–31
    # month           * or 1–12 or a name
    # day-of-week     * or 0–7 or a name

    class SlotGroup

      def initialize(slots)

p slots
        @slots =
          slots.inject({}) { |h, s|
            if hs = h[s.key]
              hs.append(s)
            else
              h[s.key] = s
            end
            h }

        if mi = @slots.delete(:m)
          if hm = @slots[:hm]
            hm._data1 = mi._data0
          else
            @slots[:hm] = make_slot(:hm, '*', mi._data0)
          end
        end

        if @slots[:monthday] || @slots[:weekday]
          @slots[:hm] ||= make_slot(:hm, 0, 0)
        elsif @slots[:month]
          @slots[:hm] ||= make_slot(:hm, 0, 0)
          @slots[:monthday] ||= make_slot(:monthday, 1)
        end
      end

      def to_crons
        determine_hms.collect { |hm| parse_cron(hm) }
      end
      def to_cron
        parse_cron(determine_hms.first)
      end

      protected

      def make_slot(key, data0, data1=nil)

        Fugit::Nat::Slot.new(key, data0, data1)
      end

      def determine_hms(count=-1)

# FIXME for multi:
        [ @slots[:hm] || Slot.new(:hm, '*', '*') ]
      end

      def parse_cron(hm)

        a = [
          slot(:second, '0'),
          hm.data1,
          hm.data0,
          slot(:monthday, '*'),
          slot(:month, '*'),
          slot(:weekday, '*') ]
        tz = @slots[:tz]
        a << tz.data0 if tz
        a.shift if a.first == [ '0' ]
p a

        s = a
          .collect { |e| e.uniq.sort.collect(&:to_s).join(',') }
          .join(' ')
p s

        Fugit::Cron.parse(s)
      end

      def slot(key, default)
        s = @slots[key]
        s ? s.data0 : [ default ]
      end
    end
  end
end

