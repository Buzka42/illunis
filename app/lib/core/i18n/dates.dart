/// Civil dates in the instrument voice. English only for v1.
library;

const kWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const kMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const kMonthsShort = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

String formatLongDate(DateTime d) =>
    '${kWeekdays[d.weekday - 1]} ${d.day} ${kMonths[d.month - 1]}';

String formatShortDate(DateTime d) => '${d.day} ${kMonthsShort[d.month - 1]}';
