import 'package:equatable/equatable.dart';

import '../enums/app_currency.dart';

class CurrencyState extends Equatable {
  final AppCurrency currency;

  const CurrencyState({
    this.currency = AppCurrency.inr,
  });

  CurrencyState copyWith({
    AppCurrency? currency,
  }) {
    return CurrencyState(
      currency: currency ?? this.currency,
    );
  }

  @override
  List<Object> get props => [currency];
}