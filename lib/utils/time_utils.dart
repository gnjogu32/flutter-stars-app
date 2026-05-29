import 'package:timeago/timeago.dart' as timeago;

class TimeUtils {
  static void init() {
    timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
  }

  static String formatShorthand(DateTime date) {
    return timeago.format(date, locale: 'en_short');
  }
}
