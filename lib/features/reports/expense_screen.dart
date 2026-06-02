import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_constants.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../core/ui_notifications.dart';
import '../../main.dart';
import 'models/expense_model.dart';

class ExpenseScreen extends StatefulWidget {
  final int? pedidoId;
  final int? noPedido;

  const ExpenseScreen({super.key, this.pedidoId, this.noPedido});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  bool get isPedidoMode => widget.pedidoId != null;

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  ExpenseCategory _selectedCategory = ExpenseCategory.gasolina;

  String _activeTimeFilter = 'Este mes';

  List<ExpenseModel> _expenses = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = RentaFestApp.of(context);
      if (appState.isPremium || isPedidoMode) {
        _loadExpenses();
      } else {
        setState(() => _loading = false);
      }
    });
  }

  Future<void> _loadExpenses() async {
    setState(() => _loading = true);

    try {
      final response = await ApiService.get(
        '${ApiConstants.gastos}?desde=${_getDesde()}&hasta=${_getHasta()}${widget.pedidoId != null ? '&pedidoId=${widget.pedidoId}' : ''}',
      );

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        _expenses = (data['data'] as List)
            .map((e) => ExpenseModel.fromApi(e))
            .toList();
      } else {
        _expenses = [];
        // En iOS no mostramos errores relacionados con el plan (cuenta free con acceso iOS).
        if (defaultTargetPlatform != TargetPlatform.iOS && mounted) {
          AppNotifications.showError(context, data['mensaje'] ?? 'Error cargando gastos');
        }
      }
    } catch (e) {
      _expenses = [];
      if (defaultTargetPlatform != TargetPlatform.iOS && mounted) {
        AppNotifications.showError(context, 'Error cargando gastos');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _getDesde() {
    final now = DateTime.now();

    if (_activeTimeFilter == 'Este mes') {
      return _formatDate(DateTime(now.year, now.month, 1));
    } else if (_activeTimeFilter == 'Mes Anterior') {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      return _formatDate(lastMonth);
    } else {
      final threeMonthsAgo = DateTime(now.year, now.month - 3);
      return _formatDate(threeMonthsAgo);
    }
  }

  String _getHasta() {
    return _formatDate(DateTime.now());
  }

  Future<void> _saveExpense() async {
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (_descriptionController.text.isEmpty || amount <= 0) {
      AppNotifications.showError(context, 'Datos inválidos');
      return;
    }

    setState(() => _saving = true);

    try {
      final response = await ApiService.post(
        ApiConstants.gastos,
        {
          "descripcion": _descriptionController.text,
          "monto": amount,
          "categoria": _selectedCategory.name,
          "fechaGasto": isPedidoMode ? null : _selectedDate.toIso8601String(),
          "pedidoId": widget.pedidoId
        },
      );

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        AppNotifications.showSuccess(context, 'Gasto registrado');

        _descriptionController.clear();
        _amountController.clear();
        setState(() => _selectedDate = DateTime.now());

        if (isPedidoMode) {
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          // GLOBAL → refrescar sin salir
          _descriptionController.clear();
          _amountController.clear();

          setState(() => _selectedDate = DateTime.now());

          await _loadExpenses();
        }
      }
    } catch (e) {
      AppNotifications.showError(context, 'Error al guardar');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.simpleCurrency(decimalDigits: 0);
    final filteredExpenses = isPedidoMode
        ? _expenses
        : _expenses.where((e) => e.periodo == _activeTimeFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isPedidoMode ? 'Gastos del Pedido #${widget.noPedido}' : 'Gastos y Egresos', style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          _buildQuickAddForm(context),
          const Divider(height: 1),
          // BARRA DE FILTROS DE TIEMPO
          if (!isPedidoMode)
            _buildTimeFilters(context),
          Expanded(
            child: _loading ? const Center(child: CircularProgressIndicator()) : _expenses.isEmpty ? _buildEmptyState() : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredExpenses.length,
              itemBuilder: (context, index) {
                final exp = filteredExpenses[index];
                return _buildExpenseTile(context, exp, currencyFormatter);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 50, color: Colors.grey),
          const SizedBox(height: 10),
          Text(isPedidoMode ? 'Este pedido no tiene gastos' : 'No hay gastos registrados', style: const TextStyle(color: Colors.grey),),
        ],
      ),
    );
  }

  Widget _buildTimeFilters(BuildContext context) {
    final filters = ['Este mes', 'Mes Anterior', 'Ultimos 3 meses'];
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _activeTimeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  _activeTimeFilter = filter;
                  _loading = true;
                });
                _loadExpenses();
              },
              showCheckmark: false,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.2)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickAddForm(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      color: theme.colorScheme.surface,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isPedidoMode ? 'GASTO DEL PEDIDO' : 'REGISTRAR NUEVO GASTO', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1)),
                // 👇 SOLO SI ES GENERAL
                if (!isPedidoMode)
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Text(
                              DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent
                              )
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: '¿En qué gastaste?',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '\$0.00',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ExpenseCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  final tempModel = ExpenseModel(id: 0, description: '', amount: 0, date: DateTime.now(), category: cat);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        children: [
                          Icon(tempModel.categoryIcon, size: 14, color: isSelected ? Colors.white : Colors.grey),
                          const SizedBox(width: 6),
                          Text(tempModel.categoryLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : Colors.grey)),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedCategory = cat),
                      showCheckmark: false,
                      selectedColor: AppColors.coral,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _saveExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,),) :
              const Text('Guardar Gasto', style: TextStyle(fontWeight: FontWeight.w900),),
            ),
            if (isPedidoMode)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long, size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('Estos gastos impactan la utilidad del pedido', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseTile(BuildContext context, ExpenseModel exp, NumberFormat formatter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(exp.categoryIcon, color: AppColors.coral, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${exp.description} (${exp.tipoGasto}) · ${DateFormat('dd MMM yyyy').format(exp.date)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600,),
                ),
                const SizedBox(height: 4),
                Text('${exp.categoryLabel}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
              ],
            ),
          ),
          Text('-${formatter.format(exp.amount)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.redAccent)),
        ],
      ),
    );
  }
}
