import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/currency.dart';
import '../providers/currency_provider.dart';
import 'dart:async';

class CurrencyListItem extends StatefulWidget {
  final Currency currency;
  final bool isBaseCurrency;
  final Function(String, double) onValueChanged;
  final int index;
  final bool isEditing;
  final VoidCallback onEditStart;
  final VoidCallback onEditEnd;

  const CurrencyListItem({
    Key? key,
    required this.currency,
    required this.isBaseCurrency,
    required this.onValueChanged,
    required this.index,
    required this.isEditing,
    required this.onEditStart,
    required this.onEditEnd,
  }) : super(key: key);

  @override
  State<CurrencyListItem> createState() => _CurrencyListItemState();
}

class _CurrencyListItemState extends State<CurrencyListItem> {
  late TextEditingController _controller;
  Timer? _updateDebouncer;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.currency.value));
  }

  @override
  void didUpdateWidget(CurrencyListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Always update the controller text when the value changes
    if (oldWidget.currency.value != widget.currency.value) {
      _updateControllerText();
    }
  }
  
  void _updateControllerText() {
    final formattedValue = _formatValue(widget.currency.value);
    if (_controller.text != formattedValue) {
      _controller.text = formattedValue;
    }
  }

  String _formatValue(double value) {
    if (value == 0) return '0';
    
    // Format with 2 decimal places first
    String formatted = value.toStringAsFixed(2);
    
    // Remove trailing zeros after decimal point
    formatted = formatted.replaceAll(RegExp(r'\.?0*$'), '');
    
    // Split into whole and decimal parts
    final parts = formatted.split('.');
    final wholePart = parts[0];
    
    // Add commas to the whole part
    final withCommas = wholePart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},'
    );
    
    // Recombine with decimal part if it exists
    return parts.length > 1 ? '$withCommas.${parts[1]}' : withCommas;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.isBaseCurrency 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
          : Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Flag - Fixed width column
            SizedBox(
              width: 36,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  widget.currency.flagUrl,
                  width: 36,
                  height: 24,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.flag, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Currency code - Fixed width column
            SizedBox(
              width: 60,
              child: Text(
                widget.currency.code,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: widget.isBaseCurrency 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            // Currency name - Flexible width column
            Expanded(
              child: Text(
                widget.currency.name,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Value editor - Expanded width column for large numbers
            Expanded(
              flex: 2,
              child: TextField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: InputDecoration.collapsed(
                  hintText: '',
                  // Increase the content padding to make the field taller
                  border: InputBorder.none,
                ),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                // Make sure field takes full height of the parent container
                expands: false,
                maxLines: 1,
                minLines: 1,
                // Ensure the input field has sufficient height
                inputFormatters: [
                  LengthLimitingTextInputFormatter(15), // Limit input length
                ],
                onTap: () {
                  setState(() {
                    _isEditing = true;
                  });
                  widget.onEditStart();
                },
                onChanged: (value) {
                  // Clean the input value - remove any non-numeric characters except decimal point
                  value = value.replaceAll(RegExp(r'[^\d\.]'), '');
                  
                  // Ensure only one decimal point
                  final parts = value.split('.');
                  if (parts.length > 2) {
                    value = '${parts[0]}.${parts.sublist(1).join('')}';
                  }
                  
                  // Convert to double, defaulting to 0 if invalid
                  double newValue = double.tryParse(value) ?? 0;
                  
                  // Update the value in the provider
                  widget.onValueChanged(widget.currency.code, newValue);
                  
                  // Update the controller text immediately
                  _updateControllerText();
                },
                onEditingComplete: () {
                  setState(() {
                    _isEditing = false;
                  });
                  _updateControllerText();
                  widget.onEditEnd();
                },
                onSubmitted: (_) {
                  setState(() {
                    _isEditing = false;
                  });
                  _updateControllerText();
                  widget.onEditEnd();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _updateDebouncer?.cancel();
    _controller.dispose();
    super.dispose();
  }
} 