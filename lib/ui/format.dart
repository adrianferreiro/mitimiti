/// "30/09/2026".
String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.year}';

const _months = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', //
  'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

/// "Septiembre 2026".
String formatMonth(DateTime month) =>
    '${_months[month.month - 1]} ${month.year}';
