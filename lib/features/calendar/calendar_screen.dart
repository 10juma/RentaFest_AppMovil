import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../core/api_constants.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../core/ui_notifications.dart';
import '../orders/models/order_model.dart';
import '../orders/order_details_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  List<int> daysWithEvents = [];
  List<int> busyDays = [];
  List<OrderModel> monthOrders = [];
  bool _isLoading = true;

  Map<int, List<OrderModel>> eventsByDay = {};
  int? selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    selectedDay = DateTime.now().day;
    _loadCalendarData();
  }

  void refresh() {
    _focusedDay = DateTime.now();
    selectedDay = DateTime.now().day;
    _loadCalendarData();
  }

  Future<void> _loadCalendarData() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.get(
          '${ApiConstants.calendario}/${_focusedDay.year}/${_focusedDay.month}'
      );

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        final List lista = data['data'];

        final eventos = <int>[];
        final ocupados = <int>[];
        final Map<int, List<OrderModel>> agrupados = {};

        for (final item in lista) {
          final dia = item['Dia'];
          final ocupado = item['Ocupado'] == 1;

          eventos.add(dia);
          if (ocupado) ocupados.add(dia);

          final order = OrderModel.fromApi(item);

          if (!agrupados.containsKey(dia)) {
            agrupados[dia] = [];
          }

          agrupados[dia]!.add(order);
        }

        setState(() {
          daysWithEvents = eventos.toSet().toList();
          busyDays = ocupados.toSet().toList();
          eventsByDay = agrupados;

          final today = DateTime.now();

          // Si estamos en el mes actual, seleccionar hoy
          if (_focusedDay.year == today.year && _focusedDay.month == today.month) {
            selectedDay = today.day;
          } else {
            // Si no, mantener selección válida o usar 1
            selectedDay = selectedDay != null && selectedDay! <= DateUtils.getDaysInMonth(_focusedDay.year, _focusedDay.month)
                ? selectedDay
                : 1;
          }
          _isLoading = false;
        });
      } else {
        throw Exception();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppNotifications.showError(context, 'Error al cargar calendario');
      }
    }
  }

  void _nextMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
      selectedDay = 1; // 👈 importante
    });
    _loadCalendarData();
  }

  void _prevMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
      selectedDay = 1; // 👈 importante
    });
    _loadCalendarData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.calendar_month_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCalendarHeader(context),
          const SizedBox(height: 16),
          _buildCalendarGrid(context, daysWithEvents, busyDays),
          const SizedBox(height: 24),
          Text('Eventos de ${DateFormat('MMMM', 'es').format(_focusedDay)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)
          ),
          const SizedBox(height: 12),
          if ((eventsByDay[selectedDay] ?? []).isEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: const [
                  Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No hay eventos este día',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...(eventsByDay[selectedDay] ?? [])
                .map((order) => _buildCalendarEvent(context, order))
                .toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left_rounded)),
        Text(
          DateFormat('MMMM yyyy', 'es').format(_focusedDay).toUpperCase(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)
        ),
        IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right_rounded)),
      ],
    );
  }

  Widget _buildCalendarGrid(BuildContext context, List<int> events, List<int> busy) {
    final List<String> weekDays = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];
    final int year = _focusedDay.year;
    final int month = _focusedDay.month;
    final int firstDayOfMonth = DateTime(year, month, 1).weekday % 7;
    final int daysInMonth = DateUtils.getDaysInMonth(year, month);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays.map((d) => Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey))).toList(),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 42, // 6 semanas para cubrir cualquier mes
          itemBuilder: (context, index) {
            int dayNumber;
            bool isCurrentMonth = true;

            if (index < firstDayOfMonth) {
              final prevMonth = DateTime(year, month, 0);
              dayNumber = prevMonth.day - (firstDayOfMonth - index - 1);
              isCurrentMonth = false;
            } else if (index < firstDayOfMonth + daysInMonth) {
              dayNumber = index - firstDayOfMonth + 1;
            } else {
              dayNumber = index - (firstDayOfMonth + daysInMonth) + 1;
              isCurrentMonth = false;
            }

            final isToday = dayNumber == DateTime.now().day && isCurrentMonth && month == DateTime.now().month && year == DateTime.now().year;
            final hasEvent = events.contains(dayNumber) && isCurrentMonth;
            final isBusy = busy.contains(dayNumber) && isCurrentMonth;

            return _buildDayCell(context, dayNumber, isCurrentMonth, isToday, hasEvent, isBusy);
          },
        ),
      ],
    );
  }

  Widget _buildDayCell(BuildContext context, int day, bool isCurrentMonth, bool isToday, bool hasEvent, bool isBusy,) {
    final theme = Theme.of(context);
    final isSelected = selectedDay == day && isCurrentMonth;

    return GestureDetector(
      onTap: isCurrentMonth ? () {
        setState(() {
          selectedDay = day;
        });
      } : null,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent
              : isToday && !isSelected
              ? theme.colorScheme.primary
              : (isBusy
              ? AppColors.coral.withOpacity(0.1)
              : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : isToday
                    ? Colors.white
                    : (isCurrentMonth
                    ? (isBusy
                    ? AppColors.coral
                    : theme.textTheme.bodyLarge?.color)
                    : Colors.grey.withOpacity(0.4)),
              ),
            ),
            if (hasEvent)
              Positioned(
                bottom: 6,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : isToday
                        ? Colors.white
                        : AppColors.coral,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarEvent(BuildContext context, OrderModel order) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => OrderDetailsScreen(order: order)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: order.avatarColor,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(order.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.clientName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${order.hours} • ${order.address ?? ''} • \$${order.total.toInt()}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildBadge(order.statusLabel, order.statusColor),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}
