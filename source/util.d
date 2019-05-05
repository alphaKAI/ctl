module util;
import std.string;
import std.datetime;
import core.stdc.stdlib, core.stdc.time;
import core.sys.posix.time;

tm to_tm(DateTime dt) {
  tm t;

  t.tm_year = dt.year - 1900;
  t.tm_mon = dt.month - 1;
  t.tm_mday = dt.day;

  t.tm_hour = dt.hour;
  t.tm_min = dt.minute;
  t.tm_sec = dt.second;

  return t;
}

DateTime to_dt(tm t) {
  auto date = Date(t.tm_year + 1900, t.tm_mon + 1, t.tm_mday);
  auto tod = TimeOfDay(t.tm_hour, t.tm_min, t.tm_sec);
  return DateTime(date, tod);
}

DateTime parse_time(string dstr, string fmt) {
  tm t;
  strptime(dstr.toStringz, fmt.toStringz, &t);
  return t.to_dt;
}
