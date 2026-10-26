import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/currency/currency_cubit.dart';
import '../../core/currency/currency_state.dart';
import '../../core/utils/currency_formatter.dart';

class CurrencyText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final TextAlign? textAlign;

  const CurrencyText(
      this.amount, {
        super.key,
        this.style,
        this.textAlign,
      });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CurrencyCubit, CurrencyState>(
      builder: (context, state) {
        return Text(
          CurrencyFormatter.format(
            amount,
            state.currency,
          ),
          textAlign: textAlign,
          style: style,
        );
      },
    );
  }
}