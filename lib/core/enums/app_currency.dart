enum AppCurrency {
  inr,
  aed,
  usd,
  eur,
  gbp,
  sar,
  qar,
  kwd,
  omr,
}

extension AppCurrencyExtension on AppCurrency {
  String get code {
    switch (this) {
      case AppCurrency.inr:
        return 'INR';
      case AppCurrency.aed:
        return 'AED';
      case AppCurrency.usd:
        return 'USD';
      case AppCurrency.eur:
        return 'EUR';
      case AppCurrency.gbp:
        return 'GBP';
      case AppCurrency.sar:
        return 'SAR';
      case AppCurrency.qar:
        return 'QAR';
      case AppCurrency.kwd:
        return 'KWD';
      case AppCurrency.omr:
        return 'OMR';
    }
  }

  String get symbol {
    switch (this) {
      case AppCurrency.inr:
        return '₹';
      case AppCurrency.aed:
        return 'AED';
      case AppCurrency.usd:
        return '\$';
      case AppCurrency.eur:
        return '€';
      case AppCurrency.gbp:
        return '£';
      case AppCurrency.sar:
        return 'SAR';
      case AppCurrency.qar:
        return 'QAR';
      case AppCurrency.kwd:
        return 'QWD';
      case AppCurrency.omr:
        return 'OMR';
    }
  }

  String get locale {
    switch (this) {
      case AppCurrency.inr:
        return 'en_IN';
      case AppCurrency.aed:
        return 'en_AE';
      case AppCurrency.usd:
        return 'en_US';
      case AppCurrency.eur:
        return 'de_DE';
      case AppCurrency.gbp:
        return 'en_GB';
      case AppCurrency.sar:
        return 'en_SA';
      case AppCurrency.qar:
        return 'en_QA';
      case AppCurrency.kwd:
        return 'en_KW';
      case AppCurrency.omr:
        return 'en_OM';
    }
  }

  String get name {
    switch (this) {
      case AppCurrency.inr:
        return 'Indian Rupee';
      case AppCurrency.aed:
        return 'UAE Dirham';
      case AppCurrency.usd:
        return 'US Dollar';
      case AppCurrency.eur:
        return 'Euro';
      case AppCurrency.gbp:
        return 'British Pound';
      case AppCurrency.sar:
        return 'Saudi Riyal';
      case AppCurrency.qar:
        return 'Qatari Riyal';
      case AppCurrency.kwd:
        return 'Kuwaiti Dinar';
      case AppCurrency.omr:
        return 'Omani Rial';
    }
  }
}