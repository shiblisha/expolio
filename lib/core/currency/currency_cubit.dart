import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../enums/app_currency.dart';
import 'currency_state.dart';

class CurrencyCubit extends Cubit<CurrencyState> {
  static const String _currencyKey = 'app_currency';

  CurrencyCubit()
      : super(
    const CurrencyState(
      currency: AppCurrency.inr,
    ),
  );

  Future<void> loadCurrency() async {
    final preferences = await SharedPreferences.getInstance();

    final savedCurrency = preferences.getString(_currencyKey);

    if (savedCurrency == null) {
      return;
    }

    final currency = AppCurrency.values.firstWhere(
          (item) => item.name == savedCurrency,
      orElse: () => AppCurrency.inr,
    );

    emit(
      state.copyWith(
        currency: currency,
      ),
    );
  }

  Future<void> setCurrency(AppCurrency currency) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _currencyKey,
      currency.name,
    );

    emit(
      state.copyWith(
        currency: currency,
      ),
    );
  }
}