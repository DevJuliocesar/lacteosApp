/// Gasto extra al cierre de jornada (persistido vía RPC `close_daily_route`).
class DailyRouteExtraExpense {
  final String description;
  final double amount;

  const DailyRouteExtraExpense({
    required this.description,
    required this.amount,
  });

  Map<String, dynamic> toRpcJson() => {
        'description': description,
        'amount': amount,
      };
}
