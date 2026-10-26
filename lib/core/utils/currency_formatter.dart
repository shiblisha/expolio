import 'package:intl/intl.dart';

import '../enums/app_currency.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(
      double amount,
      AppCurrency currency,
      ) {
    final formatter = NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: 2,
    );

    return formatter.format(amount);
  }

  static String formatCompact(
      double amount,
      AppCurrency currency,
      ) {
    final formatter = NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: 0,
    );

    return formatter.format(amount);
  }
}