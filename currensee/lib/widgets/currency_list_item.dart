import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/currency.dart';
import 'currency_flag_placeholder.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.12),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Flag - Fixed width column
            SizedBox(
              width: 28,
              height: 18,
              child: widget.currency.flagUrl.isNotEmpty
                  ? Image.network(
                      widget.currency.flagUrl,
                      width: 28,
                      height: 18,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return CurrencyFlagPlaceholder(
                          size: 28,
                          currencyCode: widget.currency.code,
                        );
                      },
                    )
                  : CurrencyFlagPlaceholder(
                      size: 28,
                      currencyCode: widget.currency.code,
                    ),
            ),
            const SizedBox(width: 12),
            // Currency code - Fixed width column
            SizedBox(
              width: 40,
              child: Text(
                widget.currency.code,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: widget.isBaseCurrency 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            // Currency name - Flexible width column but with smaller flex
            Expanded(
              flex: 1,
              child: Text(
                widget.currency.name,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Value editor - Increased flex for wider display
            Expanded(
              flex: 3,
              child: Container(
                height: 34,
                alignment: Alignment.centerRight,
                child: TextField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  style: TextStyle(
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  expands: false,
                  maxLines: 1,
                  minLines: 1,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(20), // Increased character limit
                  ],
                  onTap: () {
                    setState(() {
                      _isEditing = true;
                    });
                    widget.onEditStart();
                  },
                  onChanged: (value) {
                    value = value.replaceAll(RegExp(r'[^\d\.]'), '');
                    
                    final parts = value.split('.');
                    if (parts.length > 2) {
                      value = '${parts[0]}.${parts.sublist(1).join('')}';
                    }
                    
                    double newValue = double.tryParse(value) ?? 0;
                    
                    widget.onValueChanged(widget.currency.code, newValue);
                    
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
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
} 